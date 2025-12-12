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
            return "https://gus928fsid.execute-api.us-east-1.amazonaws.com/dev"
        case .production:
            return "https://api.cyclejournal.app" // TODO: 本番URL
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
        }
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

// MARK: - API Client

class APIClient {
    static let shared = APIClient()

    private let environment: APIEnvironment
    private let session: URLSession
    private var authToken: String?

    private init(environment: APIEnvironment = .development) {
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
                decoder.dateDecodingStrategy = .iso8601
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
            let (data, response) = try await session.data(for: request)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
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
            let (data, response) = try await session.data(for: request)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
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
            let (data, response) = try await session.data(for: request)
            return try handleResponse(data: data, response: response)
        } catch let error as APIError {
            throw error
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
            let (_, response) = try await session.data(for: request)

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
        } catch {
            throw APIError.networkError(error)
        }
    }
}
