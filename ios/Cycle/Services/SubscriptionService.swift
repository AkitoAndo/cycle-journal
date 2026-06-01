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

    func registerAPNsDeviceToken(_ token: String) async throws {
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
