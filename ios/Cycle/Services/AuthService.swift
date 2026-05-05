//
//  AuthService.swift
//  CycleJournal
//

import Foundation

// MARK: - Auth Request/Response Models

struct AuthVerifyRequest: Encodable {
    let identityToken: String
    /// `ASAuthorizationAppleIDCredential.authorizationCode` を utf8 文字列化したもの。
    /// サーバ側で Apple refresh token に交換し、アカウント削除時の revoke に使う。
    let authorizationCode: String?
}

struct GoogleVerifyRequest: Encodable {
    let idToken: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct AuthVerifyResponse: Decodable {
    let userId: String
    let appleUserId: String?
    let googleUserId: String?
    let email: String?
    let isNewUser: Bool
    let createdAt: Date
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct LogoutResponse: Decodable {
    let ok: Bool
}

// MARK: - Auth Service

class AuthService {
    private let apiClient = APIClient.shared

    /// Apple Identity Tokenを検証
    func verifyToken(
        _ identityToken: String,
        authorizationCode: String? = nil
    ) async throws -> AuthVerifyResponse {
        let request = AuthVerifyRequest(
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )

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

    /// Refresh tokenで新しいアクセストークンを取得
    func refresh(refreshToken: String) async throws -> RefreshTokenResponse {
        let request = RefreshTokenRequest(refreshToken: refreshToken)

        let response: APIResponse<RefreshTokenResponse> = try await apiClient.post(
            path: "/auth/refresh",
            body: request,
            requiresAuth: false
        )

        return response.data
    }

    /// サーバー側でrefresh tokenを無効化
    func logout(refreshToken: String) async throws {
        let request = RefreshTokenRequest(refreshToken: refreshToken)

        let _: APIResponse<LogoutResponse> = try await apiClient.post(
            path: "/auth/logout",
            body: request,
            requiresAuth: false
        )
    }

    /// 認証済みユーザー自身のアカウントを完全削除する。
    /// サーバ側で Apple revoke + Firestore データ全削除を行う。
    func deleteAccount() async throws {
        try await apiClient.delete(path: "/users/me", requiresAuth: true)
    }
}
