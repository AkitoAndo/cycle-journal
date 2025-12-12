//
//  AuthService.swift
//  CycleJournal
//

import Foundation

// MARK: - Auth Request/Response Models

struct AuthVerifyRequest: Encodable {
    let identityToken: String
}

struct AuthVerifyResponse: Decodable {
    let userId: String
    let appleUserId: String
    let email: String?
    let isNewUser: Bool
    let verified: Bool
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
}
