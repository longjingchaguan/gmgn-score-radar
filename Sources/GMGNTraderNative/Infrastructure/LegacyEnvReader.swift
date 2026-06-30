import Foundation

struct LegacyEnvReader {
    func readAPIKey() -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gmgn/.env")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("#"), trimmed.contains("=") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.first == "GMGN_API_KEY" else { continue }
            return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        }
        return nil
    }
}
