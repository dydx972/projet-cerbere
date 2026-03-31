import Foundation

class APIService {
    static let shared = APIService()
    let baseURL = "http://192.168.1.120/api"
    private let session: URLSession

    private init() {
        session = URLSession.shared
    }

    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func put(_ endpoint: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func delete(_ endpoint: String) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 10
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: String?
}
