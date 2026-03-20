//
//  AuthService.swift
//  CycleJournal
//

import Foundation

// MARK: - Auth Request/Response Models

struct AuthVerifyRequest: Encodable {
    let identityToken: String
}

struct GoogleVerifyRequest: Encodable {
    let idToken: String
}

struct AuthVerifyResponse: Decodable {
    let userId: String
    let appleUserId: String?
    let googleUserId: String?
    let email: String?
    let isNewUser: Bool
    let createdAt: Date
}

// MARK: - Auth Service

class AuthService {
    private let apiClient = APIClient.shared

    /// Apple Identity Tokenを検証
    func verifyToken(_ identityToken: String) async throws -> AuthVerifyResponse {
        let request = AuthVerifyRequest(identityToken: identityToken)

        let response: APIResponse<AuthVerifyResponse> = try await apiClient.post(
            path: "/auth/verify",
            body: request,
            requiresAuth: false
        )

        return response.data
    }

    /// Google ID Tokenを検証
    func verifyGoogleToken(_ idToken: String) async throws -> AuthVerifyResponse {
        let request = GoogleVerifyRequest(idToken: idToken)

        let response: APIResponse<AuthVerifyResponse> = try await apiClient.post(
            path: "/auth/google",
            body: request,
            requiresAuth: false
        )

        return response.data
    }
}
