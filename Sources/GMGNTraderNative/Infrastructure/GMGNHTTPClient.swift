import Foundation

enum GMGNHTTPError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case api(status: Int, code: Int?, error: String?, message: String?)
    case nonJSON(status: Int, body: String)
    case nonHTTPResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "需要填写 GMGN API Key。"
        case .invalidURL:
            return "GMGN OpenAPI 地址无效。"
        case let .api(status, code, error, message):
            return "GMGN API 请求失败：HTTP \(status) code=\(code.map(String.init) ?? "-") error=\(error ?? "-") message=\(message ?? "-")"
        case let .nonJSON(status, body):
            return "GMGN API 请求失败：HTTP \(status) \(body)"
        case .nonHTTPResponse:
            return "GMGN API 返回了非 HTTP 响应。"
        }
    }
}

struct GMGNHTTPClient {
    var host = URL(string: "https://openapi.gmgn.ai")!
    var apiKey: String
    var session: URLSession = .shared

    func trending(chain: Chain, options: TrendingOptions) async throws -> [MarketToken] {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "chain", value: chain.rawValue),
            URLQueryItem(name: "interval", value: options.interval),
            URLQueryItem(name: "limit", value: String(options.limit)),
            URLQueryItem(name: "order_by", value: options.orderBy),
            URLQueryItem(name: "direction", value: options.direction)
        ] + options.platforms.map { URLQueryItem(name: "platforms", value: $0) }
          + options.filters.map { URLQueryItem(name: "filters", value: $0) }
          + authQuery()

        let payload: TrendingPayload = try await request(
            method: "GET",
            path: "/v1/market/rank",
            query: query,
            body: Optional<Data>.none
        )
        return payload.rank
    }

    func trending(chain: Chain, interval: String = "1h", limit: Int = 100) async throws -> [MarketToken] {
        try await trending(
            chain: chain,
            options: TrendingOptions(
                interval: interval,
                limit: limit,
                orderBy: "volume",
                direction: "desc",
                platforms: [],
                filters: []
            )
        )
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Data?
    ) async throws -> T {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GMGNHTTPError.missingAPIKey
        }
        guard var components = URLComponents(url: host.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw GMGNHTTPError.invalidURL
        }
        components.queryItems = query
        guard let url = components.url else { throw GMGNHTTPError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-APIKEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GMGNHTTPError.nonHTTPResponse
        }
        let envelope: GMGNEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(GMGNEnvelope<T>.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GMGNHTTPError.nonJSON(status: http.statusCode, body: String(body.prefix(300)))
        }
        guard (200..<300).contains(http.statusCode), envelope.code == 0, let payload = envelope.data else {
            throw GMGNHTTPError.api(status: http.statusCode, code: envelope.code, error: envelope.error, message: envelope.message)
        }
        return payload
    }

    private func authQuery() -> [URLQueryItem] {
        [
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970))),
            URLQueryItem(name: "client_id", value: UUID().uuidString.lowercased())
        ]
    }
}

private struct GMGNEnvelope<T: Decodable>: Decodable {
    let code: Int
    let data: T?
    let error: String?
    let message: String?
}

private struct TrendingPayload: Decodable {
    let rank: [MarketToken]

    enum CodingKeys: String, CodingKey {
        case rank
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let direct = try? c.decode([MarketToken].self, forKey: .rank) {
            rank = direct
            return
        }
        let nested = try c.decode(NestedTrendingData.self, forKey: .data)
        rank = nested.rank
    }
}

private struct NestedTrendingData: Decodable {
    let rank: [MarketToken]
}
