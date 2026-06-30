import Foundation

struct AppStorage {
    let root: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        root = base.appendingPathComponent("GMGN Trader", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var settingsURL: URL { root.appendingPathComponent("settings.json") }
    var positionsURL: URL { root.appendingPathComponent("positions.json") }
    var riskURL: URL { root.appendingPathComponent("risk_state.json") }
    var logURL: URL { root.appendingPathComponent("trade_decisions.jsonl") }

    func load<T: Decodable>(_ type: T.Type, from url: URL, default fallback: T) -> T {
        guard let data = try? Data(contentsOf: url) else {
            return fallback
        }
        return (try? JSONDecoder.appDecoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder.appEncoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    func appendLog(_ entry: TradeLogEntry) throws {
        let data = try JSONEncoder.appEncoder.encode(entry)
        var line = data
        line.append(0x0A)
        if FileManager.default.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: logURL, options: [.atomic])
        }
    }

    func recentLogs(limit: Int = 200) -> [TradeLogEntry] {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else {
            return []
        }
        return text
            .split(separator: "\n")
            .suffix(limit)
            .compactMap { line in
                guard let data = String(line).data(using: .utf8) else { return nil }
                return try? JSONDecoder.appDecoder.decode(TradeLogEntry.self, from: data)
            }
    }
}

extension JSONEncoder {
    static var appEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
