//
//  APIClient.swift
//  CycleJournal
//

import Foundation

// MARK: - API Configuration

enum APIEnvironment {
    case development
    case production

    var baseURL: String {
        switch self {
        case .development:
            return "https://cycle-api-dev-1031235624127.asia-northeast1.run.app"
        case .production:
            return "https://cycle-api-prod-1031235624127.asia-northeast1.run.app"
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case validationError(String)
    case timeout
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .httpError(let statusCode, let message):
            return message ?? "HTTPエラー: \(statusCode)"
        case .decodingError:
            return "データの解析に失敗しました"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .unauthorized:
            return "認証が必要です"
        case .validationError(let message):
            return message
        case .timeout:
            return "通信がタイムアウトしました。電波状況をご確認ください。"
        case .offline:
            return "インターネットに接続されていません"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .offline:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500
        default:
            return false
        }
    }

    var requiresReauth: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}

// MARK: - API Response Types

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

struct APIErrorResponse: Decodable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Decodable {
    let code: String
    let message: String
    let details: [APIErrorFieldDetail]?
}

struct APIErrorFieldDetail: Decodable {
    let field: String
    let message: String
}

// MARK: - Token Refresh Coordinator

/// 並行する401リクエストに対して refresh を1回だけ実行し、全員に新トークンを配布するactor.
actor TokenRefreshCoordinator {
    private var inFlight: Task<String, Error>?

    func refresh(using refresher: @Sendable @escaping () async throws -> String) async throws -> String {
        if let existing = inFlight {
            return try await existing.value
        }
        let task = Task { try await refresher() }
        inFlight = task
        do {
            let result = try await task.value
            inFlight = nil
            return result
        } catch {
            inFlight = nil
            throw error
        }
    }
}

// MARK: - Date Decoding

/// サーバは datetime を小数秒付き ISO8601（例: `2026-06-12T13:31:22.342544+00:00`）で
/// 返すことがあるが、`JSONDecoder.DateDecodingStrategy.iso8601` は小数秒を解析できない。
/// 小数秒あり/なし両方を受け付けるカスタム戦略を使う。
enum APIDateDecoding {
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let strategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = iso8601Fractional.date(from: string) ?? iso8601.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "ISO8601 として解析できない日時: \(string)"
        )
    }
}

// MARK: - API Client

class APIClient {
    static let shared = APIClient()

    typealias TokenRefresher = @Sendable () async throws -> String

    private let environment: APIEnvironment
    private let session: URLSession
    private var authToken: String?
    private var tokenRefresher: TokenRefresher?
    private let refreshCoordinator = TokenRefreshCoordinator()

    private init(environment: APIEnvironment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()) {
        self.environment = environment

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Auth Token Management

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func getAuthToken() -> String? {
        return authToken
    }

    /// AuthStoreがinit時に設定。401時のaccess tokenリフレッシュに使う。
    func setTokenRefresher(_ refresher: TokenRefresher?) {
        self.tokenRefresher = refresher
    }

    // MARK: - Transient Error Retry

    /// 一時的な通信エラー（QUIC/HTTP3 の接続断 -1017, -1005 等）かどうか
    private static func isTransient(_ error: URLError) -> Bool {
        error.code == .cannotParseResponse || error.code == .networkConnectionLost
    }

    /// リトライしても安全なリクエストかどうか。
    /// GET は冪等なので常に可。POST は二重実行の副作用がない認証系のみ可。
    private static func isSafeToRetry(_ request: URLRequest) -> Bool {
        if request.httpMethod == "GET" { return true }
        return request.url?.path.hasPrefix("/auth/") == true
    }

    /// 一時的なネットワークエラーを短い待機を挟んで1回だけリトライする
    private func sendWithTransientRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where Self.isTransient(error) && Self.isSafeToRetry(request) {
            try await Task.sleep(nanoseconds: 600_000_000)
            return try await session.data(for: request)
        }
    }

    // MARK: - 401 Retry

    /// 401時に refresh → 1回だけリトライ。
    /// requiresAuth=falseまたはrefresherが未設定のときはリトライしない。
    private func sendWithRetry(
        _ request: URLRequest,
        requiresAuth: Bool
    ) async throws -> (Data, URLResponse) {
        let (data, response) = try await sendWithTransientRetry(request)

        guard requiresAuth,
              let http = response as? HTTPURLResponse,
              http.statusCode == 401,
              let refresher = tokenRefresher else {
            return (data, response)
        }

        let newToken: String
        do {
            newToken = try await refreshCoordinator.refresh(using: refresher)
        } catch {
            return (data, response)
        }

        var retryRequest = request
        retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
        return try await session.data(for: retryRequest)
    }

    // MARK: - Request Building

    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var components = URLComponents(string: environment.baseURL + path)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func buildRequest(
        url: URL,
        method: String,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        return request
    }

    // MARK: - Response Handling

    private func handleResponse<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = APIDateDecoding.strategy
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        case 401:
            throw APIError.unauthorized

        case 400, 422:
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.validationError(errorResponse.error.message)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)

        default:
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse.error.message)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    // MARK: - Public Request Methods

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try buildURL(path: path, queryItems: queryItems)
        let request = buildRequest(url: url, method: "GET", requiresAuth: requiresAuth)

        do {
            let (data, response) = try await sendWithRetry(request, requiresAuth: requiresAuth)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// SSE 用に POST URLRequest を組み立てる。リトライ・レスポンス処理は呼び出し側に委譲。
    func makeStreamingPostRequest<U: Encodable>(
        path: String,
        body: U,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        let url = try buildURL(path: path)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(body)
        var request = buildRequest(
            url: url,
            method: "POST",
            body: bodyData,
            requiresAuth: requiresAuth
        )
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return request
    }

    func post<T: Decodable, U: Encodable>(
        path: String,
        body: U,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try buildURL(path: path)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(body)

        let request = buildRequest(url: url, method: "POST", body: bodyData, requiresAuth: requiresAuth)

        do {
            let (data, response) = try await sendWithRetry(request, requiresAuth: requiresAuth)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.networkError(error)
        }
    }

    func put<T: Decodable, U: Encodable>(
        path: String,
        body: U,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try buildURL(path: path)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(body)

        let request = buildRequest(url: url, method: "PUT", body: bodyData, requiresAuth: requiresAuth)

        do {
            let (data, response) = try await sendWithRetry(request, requiresAuth: requiresAuth)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.networkError(error)
        }
    }

    func delete(
        path: String,
        requiresAuth: Bool = true
    ) async throws {
        let url = try buildURL(path: path)
        let request = buildRequest(url: url, method: "DELETE", requiresAuth: requiresAuth)

        do {
            let (_, response) = try await sendWithRetry(request, requiresAuth: requiresAuth)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            if !(200...299).contains(httpResponse.statusCode) {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        } catch {
            throw APIError.networkError(error)
        }
    }
}
