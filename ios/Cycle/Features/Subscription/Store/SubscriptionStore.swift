//
//  SubscriptionStore.swift
//  CycleJournal
//
//  Issue #37 A 系 (iOS StoreKit 2 統合)
//
//  - Transaction.currentEntitlements で起動時にエンタイトルメント復元
//  - Transaction.updates リスナーで自動更新 / Family Sharing / refund 反映
//  - 購入 → jwsRepresentation をバックエンドに渡して即時検証 (TODO 後続 PR)
//

import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var state: SubscriptionState = .unknown
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading: Bool = false
    @Published var error: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Product loading

    /// App Store からプロダクト情報を取得する。
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        let ids = SubscriptionProductID.allCases.map(\.rawValue)
        do {
            let fetched = try await Product.products(for: Set(ids))
            products = fetched.sorted { lhs, rhs in
                let li = SubscriptionProductID(rawValue: lhs.id)?.displayOrder ?? .max
                let ri = SubscriptionProductID(rawValue: rhs.id)?.displayOrder ?? .max
                return li < ri
            }
        } catch {
            self.error = "プロダクト情報の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Entitlement refresh

    /// 現在のエンタイトルメントを `state` に反映する。
    func refreshEntitlements() async {
        var latest: SubscriptionState = .notSubscribed
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if let expires = transaction.expirationDate, expires < Date() {
                continue
            }
            // iOS 17.0+ で offerType を見る (paymentMode 直接アクセスは 17.2+)
            let isTrial = transaction.offerType == .introductory
            let expiresAt = transaction.expirationDate ?? Date.distantFuture
            latest = isTrial
                ? .trial(productID: transaction.productID, expiresAt: expiresAt)
                : .active(productID: transaction.productID, expiresAt: expiresAt)
        }
        state = latest
    }

    // MARK: - Purchase

    /// プロダクトを購入。成功時にエンタイトルメント反映、jwsRepresentation を返す
    /// (バックエンド検証用; 呼び出し側で API 送信)。
    @discardableResult
    func purchase(_ product: Product) async throws -> String? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await refreshEntitlements()
                await transaction.finish()
                return verification.jwsRepresentation
            case .unverified:
                throw SubscriptionError.unverifiedTransaction
            }
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Transaction.updates listener

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await refreshEntitlements()
            await transaction.finish()
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "購入の検証に失敗しました。サポートまでお問い合わせください。"
        }
    }
}
