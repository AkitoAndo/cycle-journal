//
//  PaywallView.swift
//  CycleJournal
//
//  Issue #37 A-1 / C-1 決定: Apple Introductory Offer (yearly 7日無料) を提示する
//  Timeline 型 Paywall。
//
//  - Day 0「今すぐ全機能」
//  - Day 5「リマインド」
//  - Day 7「自動課金」
//
//  Review Guideline 2026 強化下の必須要件:
//  - 価格・課金周期 16pt 以上
//  - "first 7 days free, then ¥14,400/year" を価格直下
//  - Restore Purchases / Terms / Privacy リンク
//  - Toggle UI は使わない
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @StateObject private var store = SubscriptionStore()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String = SubscriptionProductID.yearly.rawValue
    @State private var isPurchasing = false

    /// 規約・プライバシーポリシー URL (App Store Connect と同一の URL を入れること)
    let termsURL = URL(string: "https://cycle-journal.example.com/terms")!
    let privacyURL = URL(string: "https://cycle-journal.example.com/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                trialTimeline
                planList
                primaryCTA
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(DesignSystem.Colors.background)
        .task {
            await store.loadProducts()
            await store.refreshEntitlements()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "tree.fill")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text("Cycle Premium")
                .font(.system(size: 28, weight: .bold))
            Text("自分と向き合う時間を、もっと深く。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            timelineRow(
                icon: "checkmark.circle.fill",
                color: DesignSystem.Colors.accent,
                title: "今すぐ",
                subtitle: "Premium 機能をすべて開放"
            )
            timelineRow(
                icon: "bell.fill",
                color: .orange,
                title: "Day 5",
                subtitle: "トライアル終了 2 日前にお知らせ"
            )
            timelineRow(
                icon: "creditcard.fill",
                color: .blue,
                title: "Day 7",
                subtitle: "¥14,400 自動課金 (いつでも解約可)"
            )
        }
        .padding(20)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timelineRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var planList: some View {
        if store.isLoading {
            ProgressView().padding(.vertical, 24)
        } else if store.products.isEmpty {
            Text("プロダクト情報を取得できませんでした")
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let id = SubscriptionProductID(rawValue: product.id)
        let isSelected = product.id == selectedProductID
        let isYearly = id == .yearly

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "年額プラン" : "月額プラン")
                            .font(.system(size: 18, weight: .semibold))
                        if isYearly {
                            Text("おすすめ")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.accent.opacity(0.15))
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice + (isYearly ? "/年" : "/月"))
                        .font(.system(size: 16, weight: .semibold))
                    if isYearly {
                        Text("最初の 7 日間無料、その後 \(product.displayPrice)/年")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.accent : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryCTA: some View {
        Button {
            Task { await beginPurchase() }
        } label: {
            HStack {
                if isPurchasing { ProgressView().tint(.white).padding(.trailing, 8) }
                Text(selectedProductID == SubscriptionProductID.yearly.rawValue ? "7日間無料で始める" : "購入する")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignSystem.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        }
        .disabled(isPurchasing || store.products.isEmpty)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button("購入を復元") {
                Task {
                    await store.refreshEntitlements()
                }
            }
            .font(.footnote)

            HStack(spacing: 16) {
                Link("利用規約", destination: termsURL).font(.footnote)
                Link("プライバシーポリシー", destination: privacyURL).font(.footnote)
            }
            .foregroundStyle(.secondary)

            Text("サブスクリプションは自動更新されます。解約は設定アプリ → Apple ID → サブスクリプションから行えます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Purchase

    private func beginPurchase() async {
        guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if let _ = try await store.purchase(product) {
                // 購入成功 → エンタイトルメント反映済、ここで Paywall を閉じる
                dismiss()
            }
        } catch {
            store.error = error.localizedDescription
        }
    }
}

#Preview {
    PaywallView()
}
