import Foundation

enum Chain: String, CaseIterable, Identifiable, Codable {
    case sol
    case bsc
    case base
    case eth

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

struct AppConfig: Equatable, Codable {
    var topNPrefilter = 100
    var llmMax = 20
    var equitySol = 10.0
    var riskPerTrade = 0.01
    var hardStopPct = 0.35
    var maxPerTradeSol = 0.5
    var maxConcurrentPositions = 20
    var maxTotalExposureSol = 1.0
    var minSmartMoneyConfluence = 1
    var minLLMConviction = 0.6
    var requireRenouncedMint = true
    var maxBuyTax = 0.10
    var maxSellTax = 0.10
    var maxRugRatio = 0.60
    var maxBundlerRatio = 0.30
    var maxDevHoldingPct = 0.10
    var maxTop10Concentration = 0.40
    var momentumRejectChg1h = -0.12
    var momentumRejectChg5m = -0.06
    var buyRatioPass = 0.50
    var buyRatioReject = 0.42
    var minSystemScore = 70

    var rankWeights = RankWeights()
}

struct RankWeights: Equatable, Codable {
    var mom5m = 30.0
    var mom1h = 12.0
    var buyPressure = 18.0
    var turnover = 12.0
    var consensus = 12.0
    var safety = 10.0
}

struct MarketToken: Identifiable, Decodable {
    var id: String { address }
    let address: String
    let symbol: String
    let name: String?
    let price: Double
    let marketCap: Double
    let volume: Double
    let liquidity: Double
    let creationTimestamp: Double
    let openTimestamp: Double
    let priceChange1h: Double
    let priceChange5m: Double
    let buys: Int
    let sells: Int
    let swaps: Int
    let isHoneypot: Bool
    let renouncedMint: Bool
    let renouncedFreezeAccount: Bool
    let burnRatio: Double
    let buyTax: Double
    let sellTax: Double
    let rugRatio: Double
    let bundlerRate: Double
    let devTeamHoldRate: Double
    let top10HolderRate: Double
    let smartDegenCount: Int
    let renownedCount: Int
    let sniperCount: Int

    enum CodingKeys: String, CodingKey {
        case address
        case symbol
        case name
        case price
        case marketCap = "market_cap"
        case volume
        case liquidity
        case creationTimestamp = "creation_timestamp"
        case openTimestamp = "open_timestamp"
        case priceChange1h = "price_change_percent1h"
        case priceChange5m = "price_change_percent5m"
        case buys
        case sells
        case swaps
        case isHoneypot = "is_honeypot"
        case renouncedMint = "renounced_mint"
        case renouncedFreezeAccount = "renounced_freeze_account"
        case burnRatio = "burn_ratio"
        case buyTax = "buy_tax"
        case sellTax = "sell_tax"
        case rugRatio = "rug_ratio"
        case bundlerRate = "bundler_rate"
        case devTeamHoldRate = "dev_team_hold_rate"
        case top10HolderRate = "top_10_holder_rate"
        case smartDegenCount = "smart_degen_count"
        case renownedCount = "renowned_count"
        case sniperCount = "sniper_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        address = c.string(.address)
        symbol = c.string(.symbol)
        name = c.optionalString(.name)
        price = c.double(.price)
        marketCap = c.double(.marketCap)
        volume = c.double(.volume)
        liquidity = c.double(.liquidity)
        creationTimestamp = c.double(.creationTimestamp)
        openTimestamp = c.double(.openTimestamp)
        priceChange1h = c.double(.priceChange1h)
        priceChange5m = c.double(.priceChange5m)
        buys = c.int(.buys)
        sells = c.int(.sells)
        swaps = c.int(.swaps)
        isHoneypot = c.bool(.isHoneypot)
        renouncedMint = c.bool(.renouncedMint)
        renouncedFreezeAccount = c.bool(.renouncedFreezeAccount)
        burnRatio = c.double(.burnRatio)
        buyTax = c.double(.buyTax)
        sellTax = c.double(.sellTax)
        rugRatio = c.double(.rugRatio)
        bundlerRate = c.double(.bundlerRate)
        devTeamHoldRate = c.double(.devTeamHoldRate)
        top10HolderRate = c.double(.top10HolderRate)
        smartDegenCount = c.int(.smartDegenCount)
        renownedCount = c.int(.renownedCount)
        sniperCount = c.int(.sniperCount)
    }
}

struct TokenFeatures: Identifiable {
    var id: String { address }
    let address: String
    let symbolRaw: String
    let symbolSafe: String
    let price: Double
    let marketCap: Double
    let volume1h: Double
    let ageMinutes: Double
    let change1h: Double
    let change5m: Double
    let buys: Int
    let sells: Int
    let swaps: Int
    let liquidity: Double
    let buyRatio: Double
    let turnover: Double
    let honeypot: Bool
    let renouncedMint: Bool
    let renouncedFreeze: Bool
    let burnRatio: Double
    let buyTax: Double
    let sellTax: Double
    let rugRatio: Double
    let bundler: Double
    let devHold: Double
    let top10: Double
    let smartDegen: Int
    let renowned: Int
    let sniperCount: Int
    let smartMoneyConfluence: Int
}

struct LLMVerdict: Codable, Equatable {
    let verdict: String
    let conviction: Double
    let crowdedness: String
    let redFlags: [String]
    let thesis: String
}

struct TradeDecision: Identifiable {
    let id = UUID()
    let features: TokenFeatures
    let action: String
    let reason: String
    let sizeSol: Double
    let gate: Int?
    let verdict: LLMVerdict?
    let priority: Int?
    let scoreBreakdown: ScoreBreakdown?
    let riskWarn: Bool
}

struct ScanResult {
    let decisions: [TradeDecision]
    let generatedAt: Date
}

struct ScoreBreakdown: Codable, Equatable {
    var total: Int
    var momentum5m: Double
    var momentum1h: Double
    var buyPressure: Double
    var turnover: Double
    var consensus: Double
    var safety: Double
    var penalty: Double
}

struct ScoreDriver: Identifiable {
    var id: String { name }
    let name: String
    let points: Int
}

extension TradeDecision {
    var scoreTotal: Int {
        scoreBreakdown?.total ?? priority ?? 0
    }

    var scoreDrivers: [ScoreDriver] {
        guard let breakdown = scoreBreakdown else { return [] }
        return [
            ScoreDriver(name: "5m 动能", points: Int(breakdown.momentum5m.rounded())),
            ScoreDriver(name: "1h 趋势", points: Int(breakdown.momentum1h.rounded())),
            ScoreDriver(name: "买盘", points: Int(breakdown.buyPressure.rounded())),
            ScoreDriver(name: "换手", points: Int(breakdown.turnover.rounded())),
            ScoreDriver(name: "聪明钱", points: Int(breakdown.consensus.rounded())),
            ScoreDriver(name: "安全", points: Int(breakdown.safety.rounded()))
        ]
        .filter { $0.points > 0 }
        .sorted { $0.points > $1.points }
    }

    var topScoreDrivers: [ScoreDriver] {
        Array(scoreDrivers.prefix(3))
    }

    var scoreDriverSummary: String {
        let drivers = topScoreDrivers.map { "\($0.name) +\($0.points)" }.joined(separator: "、")
        guard !drivers.isEmpty else { return "加分项不足" }
        return "加分：\(drivers)"
    }

    var humanPushHeadline: String {
        let f = features
        if f.change5m >= 0.10 && f.buyRatio >= 0.58 {
            return "短线放量，买盘压过卖盘"
        }
        if f.change5m >= 0.05 && f.smartMoneyConfluence >= 2 {
            return "刚开始动，聪明钱在场"
        }
        if f.buyRatio >= 0.60 {
            return "买盘明显占优"
        }
        if f.smartMoneyConfluence >= 3 {
            return "聪明钱共识较强"
        }
        if f.turnover >= 1.0 {
            return "换手活跃，资金正在进出"
        }
        return "通过安全和动能规则"
    }

    var humanSignalTags: [String] {
        var tags: [String] = []
        let f = features
        if f.change5m >= 0.10 {
            tags.append("短线拉升")
        } else if f.change5m >= 0.03 {
            tags.append("刚启动")
        }
        if f.buyRatio >= 0.58 {
            tags.append("买盘强")
        } else if f.buyRatio >= 0.50 {
            tags.append("买盘占优")
        }
        if f.smartMoneyConfluence >= 3 {
            tags.append("聪明钱共识")
        } else if f.smartMoneyConfluence > 0 {
            tags.append("聪明钱在场")
        }
        if f.turnover >= 1.0 {
            tags.append("换手活跃")
        }
        if f.renouncedMint && f.renouncedFreeze {
            tags.append("权限安全")
        }
        return Array(tags.prefix(3))
    }

    var humanPushSummary: String {
        let tags = humanSignalTags.joined(separator: " / ")
        guard !tags.isEmpty else { return humanPushHeadline }
        return "\(humanPushHeadline)：\(tags)"
    }

    var pushReasonSummary: String {
        let f = features
        return "买盘 \(Self.percent(f.buyRatio))，5m \(Self.signedPercent(f.change5m))，聪明钱/KOL \(f.smartMoneyConfluence)"
    }

    var notificationBody: String {
        "\(humanPushSummary)。\(pushReasonSummary)"
    }

    var detailedScoreSummary: String {
        "\(scoreDriverSummary)。\(pushReasonSummary)"
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func signedPercent(_ value: Double) -> String {
        let text = value.formatted(.percent.precision(.fractionLength(0)))
        return value > 0 ? "+\(text)" : text
    }
}

enum DecisionBucket: String, CaseIterable, Identifiable {
    case strong
    case watch
    case rejected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strong:
            return "强候选"
        case .watch:
            return "观察"
        case .rejected:
            return "已淘汰"
        }
    }

    var subtitle: String {
        switch self {
        case .strong:
            return "通过全部规则，值得优先看"
        case .watch:
            return "信号尚可，但没有达到强候选"
        case .rejected:
            return "被硬规则、排序或解释层淘汰"
        }
    }
}

struct TraderSettings: Equatable, Codable {
    var chain: Chain = .sol
    var interval = "1h"
    var limit = 100
    var orderBy = "volume"
    var direction = "desc"
    var autoScanSeconds = 30
    var platformsByChain: [Chain: [String]] = [
        .sol: [],
        .bsc: [],
        .base: [],
        .eth: []
    ]
    var filtersByChain: [Chain: [String]] = [:]
    var config = AppConfig()

    var platformsForSelectedChain: [String] {
        platformsByChain[chain] ?? []
    }

    var filtersForSelectedChain: [String] {
        filtersByChain[chain] ?? []
    }
}

struct SafetySnapshot: Codable, Equatable {
    var honeypot: Bool
    var renouncedMint: Bool
    var renouncedFreeze: Bool
    var burnRatio: Double
    var top10: Double
}

struct Position: Identifiable, Codable, Equatable {
    var id: String { address }
    var symbol: String
    var address: String
    var chain: Chain
    var sizeSol: Double
    var entryPrice: Double
    var currentPrice: Double
    var pnl: Double
    var cycles: Int
    var entry: SafetySnapshot
    var severity: Int
    var signals: [PositionSignal]
    var status: PositionStatus
    var openedAt: Date
}

struct PositionSignal: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
    var hot: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case hot
    }
}

enum PositionStatus: String, Codable, Equatable {
    case shadow
    case pending
    case live
}

struct RiskState: Codable, Equatable {
    var realizedLossToday = 0.0
    var consecutiveLosses = 0
    var halted = false
}

struct TradeLogEntry: Codable, Identifiable {
    var id = UUID()
    var timestamp = Date()
    var action: String
    var symbol: String
    var address: String?
    var reason: String
    var chain: Chain?
    var sizeSol: Double?
    var pnl: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case action
        case symbol
        case address
        case reason
        case chain
        case sizeSol
        case pnl
    }
}

struct TrendingOptions: Equatable {
    var interval: String
    var limit: Int
    var orderBy: String
    var direction: String
    var platforms: [String]
    var filters: [String]
}

extension KeyedDecodingContainer {
    func string(_ key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        return ""
    }

    func optionalString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        return nil
    }

    func double(_ key: Key) -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? decode(String.self, forKey: key) { return Double(value) ?? 0 }
        return 0
    }

    func int(_ key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? decode(String.self, forKey: key) { return Int(Double(value) ?? 0) }
        return 0
    }

    func bool(_ key: Key) -> Bool {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        if let value = try? decode(Double.self, forKey: key) { return value != 0 }
        if let value = try? decode(String.self, forKey: key) {
            return ["1", "true", "yes", "y"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        return false
    }
}
