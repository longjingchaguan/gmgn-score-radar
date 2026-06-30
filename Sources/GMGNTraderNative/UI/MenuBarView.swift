import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: TraderViewModel
    @Environment(\.dismiss) private var dismiss
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            strongList

            Divider()

            HStack {
                Button {
                    Task { await model.runScan() }
                } label: {
                    Label(model.isScanning ? "扫描中" : "重新扫描", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning || model.apiKey.isEmpty)

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }

            HStack {
                Text(footerLine)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 420)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("GMGN 选币评分")
                    .font(.headline)
                Spacer()
                Text(model.selectedChain.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(statusLine)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var statusLine: String {
        if model.apiKey.isEmpty {
            return "未设置 API Key"
        }
        if model.isScanning {
            return "正在扫描 GMGN 趋势代币..."
        }
        if let date = model.lastScanAt {
            return "\(date.formatted(date: .omitted, time: .shortened)) 扫描 · \(model.strongCount) 个 70+ 候选"
        }
        return "常驻后台，每 \(max(model.settings.autoScanSeconds, 10)) 秒自动扫描"
    }

    private var strongList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("70+ 新币")
                .font(.subheadline)
                .fontWeight(.semibold)
            let rows = Array(model.decisions(in: .strong).prefix(5))
            if rows.isEmpty {
                Text(model.apiKey.isEmpty ? "保存 API Key 后自动开始扫描。" : "没有达到 70 分的候选；有新币会通知你。")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(rows) { decision in
                    CompactTokenRow(decision: decision)
                }
            }
        }
    }

    private var footerLine: String {
        var parts = ["通知线 70"]
        if let ms = model.lastLatencyMs {
            parts.append("\(ms) ms")
        }
        if model.lastTokenCount > 0 {
            parts.append("抓取 \(model.lastTokenCount)")
        }
        return parts.joined(separator: " · ")
    }
}

private struct SummaryTile: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

private struct CompactTokenRow: View {
    @EnvironmentObject private var model: TraderViewModel
    let decision: TradeDecision

    var body: some View {
        Button {
            model.openGMGN(decision)
        } label: {
            HStack(spacing: 10) {
                ScoreBadge(score: decision.scoreTotal)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(decision.features.symbolSafe)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(percent(decision.features.buyRatio))
                            .foregroundStyle(decision.features.buyRatio >= 0.5 ? .green : .orange)
                            .monospacedDigit()
                    }
                    Text(decision.humanPushHeadline)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(decision.humanSignalTags.joined(separator: " / "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .help(decision.detailedScoreSummary)
    }
}
