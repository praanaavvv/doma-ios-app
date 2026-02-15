//
//  APIClient.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 25/12/25.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badStatus(let code, let msg): return "HTTP \(code): \(msg)"
        case .decoding(let msg): return "Decoding error: \(msg)"
        case .transport(let msg): return "Network error: \(msg)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    /// Change this for device testing: http://<YOUR_MAC_IP>:8080
    var baseURL: URL = {
        if let str = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: str), !str.isEmpty {
            return url
        }
        #if targetEnvironment(simulator)
        // Simulator can use localhost directly
        return URL(string: "http://localhost:8080")!
        #else
        // On device, set API_BASE_URL in Info.plist to your machine's IP: http://<YOUR_MAC_IP>:8080
        return URL(string: "http://localhost:8080")!
        #endif
    }()

    private init() {}

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: Encodable? = nil
    ) async throws -> T {

        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let items = query.compactMap { (k, v) -> URLQueryItem? in
            guard let v, !v.isEmpty else { return nil }
            return URLQueryItem(name: k, value: v)
        }
        if !items.isEmpty { components.queryItems = items }

        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        #if DEBUG
        print("[API] \(method) \(url.absoluteString)")
        #endif

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.transport("No HTTP response")
            }

            guard (200...299).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.badStatus(http.statusCode, msg)
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
