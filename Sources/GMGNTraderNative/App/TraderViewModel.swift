import Foundation
import AppKit

@MainActor
final class TraderViewModel: ObservableObject {
    @Published var settings = TraderSettings()
    @Published var apiKey = ""
    @Published var hasKey = false
    @Published var decisions: [TradeDecision] = []
    @Published var selectedDecision: TradeDecision?
    @Published var logs: [TradeLogEntry] = []
    @Published var showOnlyAction = false
    @Published var isScanning = false
    @Published var statusText = "就绪"
    @Published var errorMessage: String?
    @Published var lastScanAt: Date?
    @Published var lastLatencyMs: Int?
    @Published var lastTokenCount = 0

    var selectedChain: Chain {
        get { settings.chain }
        set {
            settings.chain = newValue
            saveSettings()
        }
    }

    var visibleDecisions: [TradeDecision] {
        let base = showOnlyAction ? decisions.filter { $0.action == "ACTION" } : decisions
        return base.sorted {
            ($0.priority ?? -1, $0.features.change5m) > ($1.priority ?? -1, $1.features.change5m)
        }
    }

    var strongCount: Int {
        decisions(in: .strong).count
    }

    var watchCount: Int {
        decisions(in: .watch).count
    }

    var rejectedCount: Int {
        decisions(in: .rejected).count
    }

    var menuBarTitle: String {
        strongCount > 0 ? "◎ \(strongCount)" : "◎"
    }

    func decisions(in selectedBucket: DecisionBucket) -> [TradeDecision] {
        decisions.filter { bucket(for: $0) == selectedBucket }
            .sorted { ($0.priority ?? -1, $0.features.change5m) > ($1.priority ?? -1, $1.features.change5m) }
    }

    func bucket(for decision: TradeDecision) -> DecisionBucket {
        if decision.action == "ACTION" {
            return .strong
        }
        if decision.verdict?.verdict == "watch" {
            return .watch
        }
        return .rejected
    }

    private let keychain = KeychainStore.shared
    private let legacyEnv = LegacyEnvReader()
    private let storage = AppStorage()
    private let notifications = NotificationService.shared
    private var engine = ScreeningEngine()
    private var autoScanTask: Task<Void, Never>?
    private var didBootstrap = false

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        notifications.configure()
        notifications.requestAuthorization()
        settings = storage.load(TraderSettings.self, from: storage.settingsURL, default: TraderSettings())
        logs = storage.recentLogs()

        if let key = keychain.read(CredentialAccount.apiKey), !key.isEmpty {
            apiKey = key
            hasKey = true
            statusText = "已从钥匙串读取 API Key"
            startAutoScan()
            return
        }
        if let key = legacyEnv.readAPIKey(), !key.isEmpty {
            apiKey = key
            hasKey = true
            statusText = "已从 ~/.config/gmgn/.env 读取 API Key"
            startAutoScan()
        }
    }

    func saveAPIKey() {
        do {
            try keychain.write(apiKey, account: CredentialAccount.apiKey)
            hasKey = !apiKey.isEmpty
            statusText = "API Key 已保存到钥匙串"
            errorMessage = nil
            if hasKey {
                startAutoScan()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAPIKey() {
        do {
            try keychain.delete(CredentialAccount.apiKey)
            apiKey = ""
            hasKey = false
            statusText = "API Key 已移除"
            stopAutoScan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSettings() {
        do {
            try storage.save(settings, to: storage.settingsURL)
            if hasKey {
                startAutoScan()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetRadarSettings() {
        settings.interval = "1h"
        settings.limit = 100
        settings.orderBy = "volume"
        settings.direction = "desc"
        settings.autoScanSeconds = 30
        settings.config = AppConfig()
        saveSettings()
    }

    func runScan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        do {
            statusText = "正在请求 GMGN OpenAPI..."
            let started = Date()
            let client = GMGNHTTPClient(apiKey: apiKey)
            let options = TrendingOptions(
                interval: settings.interval,
                limit: settings.limit,
                orderBy: settings.orderBy,
                direction: settings.direction,
                platforms: settings.platformsForSelectedChain,
                filters: settings.filtersForSelectedChain
            )
            let tokens = try await client.trending(chain: settings.chain, options: options)
            lastLatencyMs = Int(Date().timeIntervalSince(started) * 1000)
            lastTokenCount = tokens.count

            engine.config = settings.config
            let result = engine.screen(tokens: tokens)
            decisions = result.decisions
            selectedDecision = visibleDecisions.first
            lastScanAt = result.generatedAt
            statusText = "扫描完成：\(result.decisions.count) 条决策"
            errorMessage = nil
            notifyStrongCandidates(in: result.decisions)
            persistLogs(for: result.decisions)
        } catch {
            errorMessage = error.localizedDescription
            statusText = "扫描失败"
        }
    }

    private func persistLogs(for decisions: [TradeDecision]) {
        let entries = decisions.prefix(100).map { decision in
            TradeLogEntry(
                action: decision.action == "ACTION" ? "SCREEN" : "FILTER",
                symbol: decision.features.symbolSafe,
                address: decision.features.address,
                reason: decision.reason,
                chain: settings.chain,
                sizeSol: decision.sizeSol,
                pnl: nil
            )
        }

        Task.detached(priority: .utility) {
            let storage = AppStorage()
            do {
                for entry in entries {
                    try storage.appendLog(entry)
                }
                let recent = storage.recentLogs()
                await MainActor.run {
                    self.logs = recent
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func gmgnURL(for decision: TradeDecision) -> URL? {
        URL(string: "https://gmgn.ai/\(settings.chain.rawValue)/token/\(decision.features.address)")
    }

    func openGMGN(_ decision: TradeDecision) {
        guard let url = gmgnURL(for: decision) else { return }
        NSWorkspace.shared.open(url)
    }

    private func notifyStrongCandidates(in decisions: [TradeDecision]) {
        for decision in decisions where bucket(for: decision) == .strong {
            guard let url = gmgnURL(for: decision) else { continue }
            notifications.notifyCandidateIfNeeded(decision, chain: settings.chain, url: url)
        }
    }

    private func startAutoScan() {
        stopAutoScan()
        autoScanTask = Task { [weak self] in
            guard let self else { return }
            await self.runScan()
            while !Task.isCancelled {
                let seconds = max(self.settings.autoScanSeconds, 10)
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                if Task.isCancelled { break }
                await self.runScan()
            }
        }
    }

    private func stopAutoScan() {
        autoScanTask?.cancel()
        autoScanTask = nil
    }
}
