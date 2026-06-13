//
//  SubscriptionService.swift
//  CycleJournal
//
//  Backend integration for subscription verification and silent-push token sync.
//

import Foundation

struct IAPDeviceTokenRequest: Encodable {
    let deviceToken: String
    let environment: String
}

struct IAPDeviceTokenResponse: Decodable {
    let status: String
}

struct IAPVerifyRequest: Encodable {
    let jwsRepresentation: String
    let ga4ClientId: String?
}

struct IAPVerifyResponse: Decodable {
    let status: String
    let isActive: Bool
    let subscriptionStatus: String
    let productId: String
    let expiresDateMs: Int64
}

enum APNsDeviceTokenRegistry {
    private static let key = "apnsDeviceToken"

    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: key)
    }

    static var currentToken: String? {
        UserDefaults.standard.string(forKey: key)
    }
}

final class SubscriptionService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// StoreKit2 で購入完了した jwsRepresentation をサーバーで検証し、
    /// originalTransactionId と uid を紐付ける。
    func verifyPurchase(
        jwsRepresentation: String,
        ga4ClientId: String? = nil
    ) async throws -> IAPVerifyResponse {
        let request = IAPVerifyRequest(
            jwsRepresentation: jwsRepresentation,
            ga4ClientId: ga4ClientId
        )
        return try await apiClient.post(
            path: "/iap/apple/verify",
            body: request,
            requiresAuth: true
        )
    }

    func registerAPNsDeviceToken(_ token: String) async throws {
        #if DEBUG
        // UI テスト時はサーバ登録しない。モック認証では 401 となり、
        // 401 リトライ経路がトークンリフレッシュ失敗 → サインアウトを
        // 引き起こしてテストがサインイン画面に落ちるため。
        if CommandLine.arguments.contains("--uitesting") { return }
        #endif

        let request = IAPDeviceTokenRequest(
            deviceToken: token,
            environment: Self.apnsEnvironment
        )
        let _: IAPDeviceTokenResponse = try await apiClient.post(
            path: "/iap/apple/device-token",
            body: request,
            requiresAuth: true
        )
    }

    func registerStoredAPNsDeviceTokenIfAvailable() async {
        guard let token = APNsDeviceTokenRegistry.currentToken else { return }
        try? await registerAPNsDeviceToken(token)
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        return "Sandbox"
        #else
        return "Production"
        #endif
    }
}
