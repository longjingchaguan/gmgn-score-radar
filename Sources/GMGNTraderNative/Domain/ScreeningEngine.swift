import Foundation

struct FeatureExtractor {
    func build(from token: MarketToken, now: Date = Date()) -> TokenFeatures {
        let raw = token.symbol.isEmpty ? (token.name ?? "") : token.symbol
        let created = token.creationTimestamp > 0 ? token.creationTimestamp : token.openTimestamp
        let ageMinutes = created > 0 ? max(0, (now.timeIntervalSince1970 - created) / 60) : 0
        let buyRatio = (token.buys + token.sells) > 0 ? Double(token.buys) / Double(token.buys + token.sells) : 0.5
        let turnover = token.marketCap > 0 ? token.volume / token.marketCap : 0

        return TokenFeatures(
            address: token.address,
            symbolRaw: raw,
            symbolSafe: sanitize(raw),
            price: token.price,
            marketCap: token.marketCap,
            volume1h: token.volume,
            ageMinutes: ageMinutes,
            change1h: token.priceChange1h / 100,
            change5m: token.priceChange5m / 100,
            buys: token.buys,
            sells: token.sells,
            swaps: token.swaps,
            liquidity: token.liquidity,
            buyRatio: buyRatio,
            turnover: turnover,
            honeypot: token.isHoneypot,
            renouncedMint: token.renouncedMint,
            renouncedFreeze: token.renouncedFreezeAccount,
            burnRatio: token.burnRatio,
            buyTax: token.buyTax,
            sellTax: token.sellTax,
            rugRatio: token.rugRatio,
            bundler: token.bundlerRate,
            devHold: token.devTeamHoldRate,
            top10: token.top10HolderRate,
            smartDegen: token.smartDegenCount,
            renowned: token.renownedCount,
            sniperCount: token.sniperCount,
            smartMoneyConfluence: token.smartDegenCount + token.renownedCount
        )
    }

    private func sanitize(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: #"[\r\n\t<>{}\[\]`$]"#, with: " ", options: .regularExpression)
        return String(cleaned.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ScreeningEngine {
    var config = AppConfig()
    var extractor = FeatureExtractor()
    var verdictEngine = VerdictEngine()

    func screen(tokens: [MarketToken], positions: [Position] = [], riskState: RiskState = RiskState()) -> ScanResult {
        let candidates = Array(tokens.prefix(config.topNPrefilter))
        var decisions: [TradeDecision] = []
        var survivors: [TokenFeatures] = []

        for token in candidates where !token.address.isEmpty {
            let features = extractor.build(from: token)
            let gate = hardGate(features)
            if !gate.ok {
                decisions.append(reject(features, reason: gate.reason, gate: gate.index))
            } else {
                survivors.append(features)
            }
        }

        let scored = survivors
            .map { (scoreBreakdown($0).total, $0) }
            .sorted { $0.0 > $1.0 }

        for item in scored.dropFirst(config.llmMax) {
            decisions.append(reject(item.1, reason: "REJECT 排序：优先级低于本轮解释名额", gate: 3))
        }

        for (score, features) in scored.prefix(config.llmMax) {
            let verdict = verdictEngine.judge(features, config: config)
            if verdict.verdict != "pass" {
                decisions.append(reject(features, reason: "REJECT LLM：\(verdict.verdict)（\(verdict.crowdedness)）", gate: 4, verdict: verdict))
                continue
            }
            if verdict.conviction < config.minLLMConviction {
                decisions.append(reject(features, reason: "REJECT LLM：置信度 \(verdict.conviction) 偏低", gate: 4, verdict: verdict))
                continue
            }
            if score < config.minSystemScore {
                decisions.append(reject(features, reason: "REJECT 系统分：\(score) < \(config.minSystemScore)", gate: 4, verdict: verdict))
                continue
            }

            let size = positionSize()
            let gate = RiskManager(config: config).gate(
                sizeSol: size,
                positionCount: positions.count,
                exposureSol: positions.reduce(0) { $0 + $1.sizeSol },
                state: riskState
            )
            decisions.append(TradeDecision(
                features: features,
                action: "ACTION",
                reason: "通过全部闸门 · 待决策",
                sizeSol: size,
                gate: nil,
                verdict: verdict,
                priority: scoreBreakdown(features).total,
                scoreBreakdown: scoreBreakdown(features),
                riskWarn: !gate.ok
            ))
        }

        return ScanResult(decisions: decisions, generatedAt: Date())
    }

    private func hardGate(_ f: TokenFeatures) -> (ok: Bool, reason: String, index: Int?) {
        if f.honeypot { return (false, "REJECT 避雷：honeypot 命中", 1) }
        if config.requireRenouncedMint && !f.renouncedMint {
            return (false, "REJECT 避雷：未放弃增发权（可无限增发）", 1)
        }
        if f.buyTax > config.maxBuyTax || f.sellTax > config.maxSellTax {
            return (false, "REJECT 避雷：税过高 买\(percent(f.buyTax))/卖\(percent(f.sellTax))", 1)
        }
        if f.rugRatio > config.maxRugRatio {
            return (false, "REJECT 避雷：rug 比例 \(percent(f.rugRatio)) > \(percent(config.maxRugRatio))", 1)
        }
        if f.bundler > config.maxBundlerRatio {
            return (false, "REJECT 避雷：bundler \(percent(f.bundler)) > \(percent(config.maxBundlerRatio))", 1)
        }
        if f.devHold > config.maxDevHoldingPct {
            return (false, "REJECT 避雷：dev 持仓 \(percent(f.devHold)) > \(percent(config.maxDevHoldingPct))", 1)
        }
        if f.top10 > config.maxTop10Concentration {
            return (false, "REJECT 避雷：top10 \(percent(f.top10)) 集中", 1)
        }
        if f.smartMoneyConfluence < config.minSmartMoneyConfluence {
            return (false, "REJECT 共识：聪明钱+KOL \(f.smartMoneyConfluence) (degen \(f.smartDegen)/KOL \(f.renowned)) < \(config.minSmartMoneyConfluence)", 2)
        }
        return (true, "ok", nil)
    }

    private func scoreBreakdown(_ f: TokenFeatures) -> ScoreBreakdown {
        let w = config.rankWeights
        let mom5 = clamp((f.change5m + 0.05) / 0.30)
        let mom1h = clamp((f.change1h + 0.10) / 0.60)
        let buy = clamp((f.buyRatio - 0.40) / 0.30)
        let turn = clamp(f.turnover / 3.0)
        let consensus = clamp(log10(1 + Double(f.smartMoneyConfluence)) / 2.5)
        let safety = (f.renouncedMint && f.renouncedFreeze ? 0.5 : 0) + 0.5 * clamp((0.40 - f.top10) / 0.40)
        let rawScore = w.mom5m * mom5 + w.mom1h * mom1h + w.buyPressure * buy + w.turnover * turn + w.consensus * consensus + w.safety * safety
        let penalty = f.change1h <= config.momentumRejectChg1h ? 0.4 : 1.0
        let score = rawScore * penalty
        return ScoreBreakdown(
            total: max(0, min(99, Int(score.rounded()))),
            momentum5m: w.mom5m * mom5,
            momentum1h: w.mom1h * mom1h,
            buyPressure: w.buyPressure * buy,
            turnover: w.turnover * turn,
            consensus: w.consensus * consensus,
            safety: w.safety * safety,
            penalty: penalty
        )
    }

    private func priorityScore(_ f: TokenFeatures, conviction: Double, crowd: String) -> Int {
        scoreBreakdown(f).total
    }

    private func positionSize() -> Double {
        let riskSol = config.equitySol * config.riskPerTrade
        let size = min(riskSol / config.hardStopPct, config.maxPerTradeSol)
        return (size * 10_000).rounded() / 10_000
    }

    private func reject(_ features: TokenFeatures, reason: String, gate: Int?, verdict: LLMVerdict? = nil) -> TradeDecision {
        TradeDecision(features: features, action: "SKIP", reason: reason, sizeSol: 0, gate: gate, verdict: verdict, priority: nil, scoreBreakdown: scoreBreakdown(features), riskWarn: false)
    }

    private func clamp(_ value: Double, _ minValue: Double = 0, _ maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

struct VerdictEngine {
    func judge(_ f: TokenFeatures, config: AppConfig) -> LLMVerdict {
        var flags: [String] = []
        if f.sniperCount > 0 {
            flags.append("狙击钱包 \(f.sniperCount)")
        }
        if f.change1h <= config.momentumRejectChg1h && f.change5m <= config.momentumRejectChg5m {
            flags.insert("1h/5m 双跌，动能转弱", at: 0)
            return LLMVerdict(
                verdict: "reject",
                conviction: 0.3,
                crowdedness: "fading",
                redFlags: flags,
                thesis: "正在阴跌（5m \(f.change5m.formatted(.percent.precision(.fractionLength(0)))) / 1h \(f.change1h.formatted(.percent.precision(.fractionLength(0))))），趋势向下，不追。"
            )
        }
        if f.buyRatio < config.buyRatioReject {
            flags.insert("买占比仅 \(f.buyRatio.formatted(.percent.precision(.fractionLength(0))))，卖压主导", at: 0)
            return LLMVerdict(
                verdict: "reject",
                conviction: min(0.5, 0.2 + f.buyRatio),
                crowdedness: "distributing",
                redFlags: flags,
                thesis: "卖压主导（买占比 \(f.buyRatio.formatted(.percent.precision(.fractionLength(0))))），疑似拉高派发/接盘位，不追。"
            )
        }
        let crowd = f.change1h >= 3.0 ? "late" : ((f.change5m > 0 && f.change1h > 0) ? "early" : "crowded")
        if crowd == "late" {
            flags.append("1h 已涨 \(f.change1h.formatted(.percent.precision(.fractionLength(0))))，高位追涨需谨慎")
        }
        let momentum = clamp((f.change5m + 0.05) / 0.25)
        let buy = clamp((f.buyRatio - 0.45) / 0.20)
        var conviction = 0.35 + 0.40 * momentum + 0.20 * buy + (f.change1h > 0 ? 0.05 : 0)
        if crowd == "late" { conviction -= 0.05 }
        conviction = min(0.95, max(0.3, conviction))
        let verdict = (f.buyRatio >= config.buyRatioPass && f.change5m > -0.02) ? "pass" : "watch"
        let thesis = "5m \(f.change5m.formatted(.percent.precision(.fractionLength(0)))) / 1h \(f.change1h.formatted(.percent.precision(.fractionLength(0))))，买占比 \(f.buyRatio.formatted(.percent.precision(.fractionLength(0))))；\(crowd == "late" ? "高位但买盘仍占优，跟随金狗动能；" : "量价上行、买盘占优；")\(f.smartDegen) 聪明钱 + \(f.renowned) KOL 在场。"
        return LLMVerdict(verdict: verdict, conviction: (conviction * 100).rounded() / 100, crowdedness: crowd, redFlags: flags, thesis: thesis)
    }

    private func clamp(_ value: Double, _ minValue: Double = 0, _ maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }
}

struct RiskManager {
    var config: AppConfig

    func gate(sizeSol: Double, positionCount: Int, exposureSol: Double, state: RiskState) -> (ok: Bool, reason: String) {
        if state.halted {
            return (false, "BLOCK kill-switch 已触发")
        }
        if positionCount >= config.maxConcurrentPositions {
            return (false, "BLOCK 已达最大并发持仓 (\(config.maxConcurrentPositions))")
        }
        if exposureSol + sizeSol > config.maxTotalExposureSol {
            return (false, "BLOCK 超出总敞口上限")
        }
        return (true, "ok")
    }
}

struct PositionMonitor {
    func update(positions: [Position], tokens: [MarketToken], chain: Chain) -> [Position] {
        let rows = Dictionary(uniqueKeysWithValues: tokens.map { ($0.address, $0) })
        return positions.map { position in
            guard position.chain == chain else { return position }
            var next = position
            next.cycles += 1
            if let row = rows[position.address] {
                let current = safety(from: row)
                let assessment = assessEscape(current: current, entry: position.entry)
                next.severity = assessment.severity
                next.signals = assessment.signals
                next.currentPrice = row.price
                if position.entryPrice > 0 && row.price > 0 {
                    next.pnl = ((row.price - position.entryPrice) / position.entryPrice * 10_000).rounded() / 10_000
                }
            } else {
                next.signals = [PositionSignal(text: "本轮热榜未出现，等待下轮或后续补查", hot: false)]
                next.severity = max(next.severity, 0)
            }
            return next
        }
    }

    func safety(from token: MarketToken) -> SafetySnapshot {
        SafetySnapshot(
            honeypot: token.isHoneypot,
            renouncedMint: token.renouncedMint,
            renouncedFreeze: token.renouncedFreezeAccount,
            burnRatio: token.burnRatio,
            top10: token.top10HolderRate
        )
    }

    func assessEscape(current: SafetySnapshot, entry: SafetySnapshot) -> (severity: Int, signals: [PositionSignal]) {
        var severity = 0
        var signals: [PositionSignal] = []
        if current.honeypot && !entry.honeypot {
            severity += 60
            signals.append(PositionSignal(text: "honeypot 标记新触发 ← 逃生信号", hot: true))
        }
        if entry.renouncedMint && !current.renouncedMint {
            severity += 55
            signals.append(PositionSignal(text: "增发权疑似找回（可砸盘）← 逃生信号", hot: true))
        }
        if current.top10 > entry.top10 + 0.15 {
            severity += 22
            signals.append(PositionSignal(text: "top10 集中度升至 \(current.top10.formatted(.percent.precision(.fractionLength(0))))", hot: current.top10 > 0.5))
        }
        if signals.isEmpty {
            signals.append(PositionSignal(text: "持仓正常监控中", hot: false))
        }
        return (min(100, severity), signals)
    }
}
