//
//  SubscriptionService.swift
//  CycleJournal
//
//  Backend integration for subscription verification.
//

import Foundation

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

}
