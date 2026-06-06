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

    /// プロダクトを購入。成功時にエンタイトルメント反映 + サーバー側 verify を実行。
    ///
    /// サーバー verify は originalTransactionId を uid に紐付け、ASSN V2 webhook が
    /// 更新・解約イベントで uid を解決できるようにするために必須。失敗してもクライアント
    /// 側のエンタイトルメントは StoreKit の `Transaction.currentEntitlements` を信頼
    /// するため、UX は止めない（ログに残してリトライは後続実装）。
    @discardableResult
    func purchase(_ product: Product) async throws -> String? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                let jws = verification.jwsRepresentation
                await sendVerifyToBackend(jws: jws)
                await refreshEntitlements()
                await applyTrialNotificationSideEffects(for: transaction)
                await transaction.finish()
                return jws
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

    private func sendVerifyToBackend(jws: String) async {
        do {
            _ = try await SubscriptionService().verifyPurchase(
                jwsRepresentation: jws
            )
        } catch {
            // verify 失敗はエンタイトルメント反映を止めない（StoreKit が一次情報）。
            // 後続: pending jws を UserDefaults に積んで起動時リトライする等。
            print("[SubscriptionStore] verifyPurchase failed: \(error)")
        }
    }

    // MARK: - Transaction.updates listener

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await refreshEntitlements()
            await applyTrialNotificationSideEffects(for: transaction)
            await transaction.finish()
        }
    }

    // MARK: - Trial notification side effects

    private func applyTrialNotificationSideEffects(for transaction: Transaction) async {
        let scheduler = TrialNotificationScheduler.shared

        if transaction.revocationDate != nil {
            scheduler.cancelAllTrialNotifications()
            return
        }

        if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            scheduler.cancelAllTrialNotifications()
            return
        }

        guard transaction.offerType == .introductory else {
            scheduler.cancelAllTrialNotifications()
            return
        }

        await scheduler.scheduleTrialNotifications(
            purchaseDate: transaction.purchaseDate,
            goal: Self.storedOnboardingGoal()
        )
    }

    private static func storedOnboardingGoal() -> OnboardingGoal? {
        guard let rawValue = UserDefaults.standard.string(forKey: "userGoal") else {
            return nil
        }
        return OnboardingGoal(rawValue: rawValue)
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
