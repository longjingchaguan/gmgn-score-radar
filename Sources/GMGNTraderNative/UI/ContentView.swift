import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: TraderViewModel
    @State private var selectedBucket: DecisionBucket = .strong

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedBucket) {
                Section("结果") {
                    ForEach(DecisionBucket.allCases) { bucket in
                        BucketRow(bucket: bucket, count: model.decisions(in: bucket).count)
                            .tag(bucket)
                    }
                }

                Section("导航") {
                    NavigationLink {
                        LogsView()
                    } label: {
                        Label("日志", systemImage: "doc.text.magnifyingglass")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            ScannerView(bucket: selectedBucket)
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("链", selection: $model.selectedChain) {
                    ForEach(Chain.allCases) { chain in
                        Text(chain.label).tag(chain)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Button {
                    Task { await model.runScan() }
                } label: {
                    Label(model.isScanning ? "扫描中" : "运行扫描", systemImage: "play.fill")
                }
                .disabled(model.isScanning || model.apiKey.isEmpty)
            }
        }
    }
}

private struct BucketRow: View {
    let bucket: DecisionBucket
    let count: Int

    var body: some View {
        Label {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.title)
                    Text(bucket.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(color)
        }
    }

    private var iconName: String {
        switch bucket {
        case .strong: return "checkmark.seal.fill"
        case .watch: return "eye.fill"
        case .rejected: return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch bucket {
        case .strong: return .green
        case .watch: return .orange
        case .rejected: return .secondary
        }
    }
}

private struct ScannerView: View {
    @EnvironmentObject private var model: TraderViewModel
    let bucket: DecisionBucket

    var body: some View {
        VStack(spacing: 0) {
            StatusStrip()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            HSplitView {
                TokenScoreList(bucket: bucket)
                    .frame(minWidth: 520)
                ScoreInspector(decision: model.selectedDecision)
                    .frame(minWidth: 430, idealWidth: 500)
            }
        }
        .navigationTitle("GMGN 选币评分")
    }
}

private struct StatusStrip: View {
    @EnvironmentObject private var model: TraderViewModel

    var body: some View {
        HStack(spacing: 14) {
            Label("原生直连", systemImage: "network")
                .foregroundStyle(.green)
            Label(model.hasKey ? "Key 已就绪" : "未设置 Key", systemImage: "key.fill")
                .foregroundStyle(model.hasKey ? .green : .orange)
            Text(model.statusText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if model.lastTokenCount > 0 {
                Text("\(model.lastTokenCount) 行")
                    .foregroundStyle(.secondary)
            }
            if let ms = model.lastLatencyMs {
                Text("\(ms) 毫秒")
                    .foregroundStyle(.secondary)
            }
            if let date = model.lastScanAt {
                Text(date, style: .time)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}

private struct TokenScoreList: View {
    @EnvironmentObject private var model: TraderViewModel
    let bucket: DecisionBucket

    var body: some View {
        let rows = model.decisions(in: bucket)
        List(selection: Binding(
            get: { model.selectedDecision?.id },
            set: { id in model.selectedDecision = rows.first { $0.id == id } }
        )) {
            ForEach(rows) { decision in
                TokenScoreRow(decision: decision, bucket: model.bucket(for: decision))
                    .tag(decision.id)
                    .contextMenu {
                        Button("在 GMGN 打开") {
                            model.openGMGN(decision)
                        }
                    }
            }
        }
        .overlay {
            if model.decisions.isEmpty {
                ContentUnavailableView(
                    "暂无扫描结果",
                    systemImage: "scope",
                    description: Text(model.apiKey.isEmpty ? "请先在设置里添加 GMGN API Key。" : "点击运行扫描，获取实时趋势代币。")
                )
            } else if rows.isEmpty {
                ContentUnavailableView("这一组为空", systemImage: "tray")
            }
        }
    }
}

private struct TokenScoreRow: View {
    @EnvironmentObject private var model: TraderViewModel
    let decision: TradeDecision
    let bucket: DecisionBucket

    var body: some View {
        Button {
            model.openGMGN(decision)
        } label: {
            HStack(spacing: 12) {
            ScoreBadge(score: decision.scoreBreakdown?.total ?? decision.priority)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(decision.features.symbolSafe.isEmpty ? "-" : decision.features.symbolSafe)
                        .font(.headline)
                    Text(shortAddress(decision.features.address))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(bucket.title)
                        .font(.caption)
                        .foregroundStyle(bucketColor(bucket))
                }

                Text(shortReason(decision.reason))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    MetricPill(title: "5m", value: percent(decision.features.change5m), color: deltaColor(decision.features.change5m))
                    MetricPill(title: "1h", value: percent(decision.features.change1h), color: deltaColor(decision.features.change1h))
                    MetricPill(title: "买盘", value: percent(decision.features.buyRatio), color: decision.features.buyRatio >= 0.5 ? .green : .orange)
                    MetricPill(title: "共识", value: "\(decision.features.smartMoneyConfluence)", color: .blue)
                }
            }
        }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .help("在 GMGN 打开")
    }
}

private struct ScoreInspector: View {
    @EnvironmentObject private var model: TraderViewModel
    let decision: TradeDecision?

    var body: some View {
        Form {
            if let decision {
                Section("结论") {
                    HStack(alignment: .center) {
                        ScoreBadge(score: decision.scoreBreakdown?.total ?? decision.priority, large: true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(decision.features.symbolSafe)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(actionLabel(decision.action))
                                .foregroundStyle(decision.action == "ACTION" ? .green : .secondary)
                            Text(decision.reason)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("合约地址") {
                        Text(decision.features.address)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    Button {
                        model.openGMGN(decision)
                    } label: {
                        Label("在 GMGN 打开", systemImage: "safari")
                    }
                }

                if let breakdown = decision.scoreBreakdown {
                    Section("评分拆解") {
                        ScoreBar(title: "5m 动能", value: breakdown.momentum5m, max: 30)
                        ScoreBar(title: "1h 动能", value: breakdown.momentum1h, max: 12)
                        ScoreBar(title: "买盘压力", value: breakdown.buyPressure, max: 18)
                        ScoreBar(title: "换手", value: breakdown.turnover, max: 12)
                        ScoreBar(title: "聪明钱/KOL", value: breakdown.consensus, max: 12)
                        ScoreBar(title: "安全筹码", value: breakdown.safety, max: 10)
                        if breakdown.penalty < 1 {
                            LabeledContent("阴跌惩罚", value: "x\(breakdown.penalty.formatted(.number.precision(.fractionLength(1))))")
                        }
                    }
                }

                Section("解释") {
                    if let verdict = decision.verdict {
                        LabeledContent("判断", value: verdictLabel(verdict.verdict))
                        LabeledContent("置信度", value: percent(verdict.conviction))
                        Text(verdict.thesis)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(gateName(decision.gate))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("关键字段") {
                    LabeledContent("5m", value: percent(decision.features.change5m))
                    LabeledContent("1h", value: percent(decision.features.change1h))
                    LabeledContent("买盘占比", value: percent(decision.features.buyRatio))
                    LabeledContent("Bundler", value: percent(decision.features.bundler))
                    LabeledContent("开发者持仓", value: percent(decision.features.devHold))
                    LabeledContent("Top10", value: percent(decision.features.top10))
                    LabeledContent("Smart/KOL", value: "\(decision.features.smartMoneyConfluence)")
                    LabeledContent("流动性", value: usd(decision.features.liquidity))
                    LabeledContent("市值", value: usd(decision.features.marketCap))
                }
            } else {
                ContentUnavailableView("选择一个代币", systemImage: "sidebar.right")
            }
        }
        .formStyle(.grouped)
    }
}

struct ScoreBadge: View {
    let score: Int?
    var large = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
            Text(score.map(String.init) ?? "-")
                .font(large ? .title.bold() : .headline.bold())
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(width: large ? 76 : 50, height: large ? 76 : 50)
    }

    private var color: Color {
        guard let score else { return .secondary }
        if score >= 70 { return .green }
        if score >= 45 { return .orange }
        return .secondary
    }
}

private struct ScoreBar: View {
    let title: String
    let value: Double
    let max: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, specifier: "%.1f") / \(max, specifier: "%.0f")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: Swift.min(Swift.max(value / max, 0), 1))
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

private struct LogsView: View {
    @EnvironmentObject private var model: TraderViewModel

    var body: some View {
        Table(model.logs.reversed()) {
            TableColumn("时间") { entry in
                Text(entry.timestamp, style: .time)
            }
            .width(80)
            TableColumn("动作") { entry in
                Text(logActionLabel(entry.action))
            }
            .width(120)
            TableColumn("符号") { entry in
                Text(entry.symbol)
            }
            .width(140)
            TableColumn("原因") { entry in
                Text(entry.reason)
                    .lineLimit(1)
            }
        }
        .overlay {
            if model.logs.isEmpty {
                ContentUnavailableView("暂无日志", systemImage: "doc.text")
            }
        }
        .navigationTitle("日志")
    }
}

struct SettingsWindow: View {
    var body: some View {
        SettingsView()
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: TraderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusHeader
            Divider()
            accountSection
            Divider()
            radarSection
            Divider()
            notificationSection
            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 18)
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .navigationTitle("设置")
        .onChange(of: model.settings) { _, _ in
            model.saveSettings()
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("后台雷达")
                    .font(.headline)
                Text(statusCopy)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.hasKey ? "已连接" : "未连接")
                .font(.caption)
                .foregroundStyle(model.hasKey ? .green : .secondary)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionTitle("账户")
            HStack(spacing: 8) {
                SecureField("GMGN API Key", text: $model.apiKey)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.saveAPIKey()
                } label: {
                    Label("保存", systemImage: "key")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .help("保存到钥匙串")

                Button(role: .destructive) {
                    model.clearAPIKey()
                } label: {
                    Label("移除", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .help("移除 API Key")
            }
        }
    }

    private var radarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("雷达")
            Picker("链", selection: $model.settings.chain) {
                ForEach(Chain.allCases) { chain in
                    Text(chain.label).tag(chain)
                }
            }
            .pickerStyle(.segmented)

            SettingsStepperRow(
                title: "扫描间隔",
                value: "\(model.settings.autoScanSeconds) 秒"
            ) {
                Stepper("", value: $model.settings.autoScanSeconds, in: 10...300, step: 10)
                    .labelsHidden()
            }

            SettingsStepperRow(
                title: "每轮抓取",
                value: "\(model.settings.limit) 个"
            ) {
                Stepper("", value: $model.settings.limit, in: 20...100, step: 10)
                    .labelsHidden()
            }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionTitle("通知")
            SettingsStepperRow(
                title: "系统分门槛",
                value: "\(model.settings.config.minSystemScore)+"
            ) {
                Stepper("", value: $model.settings.config.minSystemScore, in: 70...95)
                    .labelsHidden()
            }
            Text("只通知达到门槛的新币；点击通知直接打开 GMGN。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                model.resetRadarSettings()
            } label: {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.small)

            Spacer()

            Text("不做交易，只做筛选")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusCopy: String {
        if model.apiKey.isEmpty {
            return "保存 API Key 后开始扫描"
        }
        if model.isScanning {
            return "正在扫描，\(model.settings.config.minSystemScore)+ 会通知"
        }
        return "每 \(model.settings.autoScanSeconds) 秒扫描，\(model.settings.config.minSystemScore)+ 才通知"
    }
}

private struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
    }
}

private struct SettingsStepperRow<Control: View>: View {
    let title: String
    let value: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            control()
                .frame(width: 48)
        }
    }
}

private func shortAddress(_ address: String) -> String {
    guard address.count > 12 else { return address }
    return "\(address.prefix(6))...\(address.suffix(6))"
}

private func shortReason(_ reason: String) -> String {
    reason.replacingOccurrences(of: "REJECT ", with: "")
}

func percent(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0...1)))
}

private func deltaColor(_ value: Double) -> Color {
    if value > 0 { return .green }
    if value < 0 { return .red }
    return .secondary
}

private func usd(_ value: Double) -> String {
    value.formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
}

private func actionLabel(_ action: String) -> String {
    switch action {
    case "ACTION":
        return "强候选"
    case "SKIP":
        return "未通过"
    default:
        return action
    }
}

private func verdictLabel(_ verdict: String) -> String {
    switch verdict {
    case "pass":
        return "通过"
    case "watch":
        return "观察"
    case "reject":
        return "拒绝"
    default:
        return verdict
    }
}

private func gateName(_ gate: Int?) -> String {
    switch gate {
    case 1:
        return "避雷闸门未通过"
    case 2:
        return "共识闸门未通过"
    case 3:
        return "排序名额未通过"
    case 4:
        return "解释层未通过"
    default:
        return "未进入候选"
    }
}

private func bucketColor(_ bucket: DecisionBucket) -> Color {
    switch bucket {
    case .strong:
        return .green
    case .watch:
        return .orange
    case .rejected:
        return .secondary
    }
}

private func logActionLabel(_ action: String) -> String {
    switch action {
    case "SCREEN":
        return "筛选通过"
    case "FILTER":
        return "过滤"
    default:
        return action
    }
}
