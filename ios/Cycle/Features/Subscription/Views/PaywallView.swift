//
//  PaywallView.swift
//  CycleJournal
//
//  Issue #54 決定: フェーズ1は月額¥1,800の3日無料トライアルのみ。
//  年額¥14,400はフェーズ2で追加（App Store Connect で「配信から削除」中）。
//
//  Timeline 型 Paywall:
//  - Day 0「今すぐ全機能」
//  - Day 2「リマインド」
//  - Day 3「自動課金開始」
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @StateObject private var store = SubscriptionStore()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String = SubscriptionProductID.monthly.rawValue
    @State private var isPurchasing = false

    /// 規約・プライバシーポリシー URL (App Store Connect と同一の URL を入れること)
    let termsURL = URL(string: "https://akitoando.github.io/cycle-journal/legal/TERMS_OF_SERVICE.html")!
    let privacyURL = URL(string: "https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html")!

    /// フェーズ1で Paywall に表示するプロダクト。yearly は除外。
    private var visibleProducts: [Product] {
        store.products.filter { SubscriptionProductID(rawValue: $0.id) == .monthly }
    }

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
                title: "Day 2",
                subtitle: "トライアル終了 1 日前にお知らせ"
            )
            timelineRow(
                icon: "creditcard.fill",
                color: .blue,
                title: "Day 3",
                subtitle: "¥1,800 自動課金 (いつでも解約可)"
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
        } else if visibleProducts.isEmpty {
            Text("プロダクト情報を取得できませんでした")
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(visibleProducts, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = product.id == selectedProductID

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("月額プラン")
                        .font(.system(size: 18, weight: .semibold))
                    Text(product.displayPrice + "/月")
                        .font(.system(size: 16, weight: .semibold))
                    Text("最初の 3 日間無料、その後 \(product.displayPrice)/月")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Text("3日間無料で始める")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DesignSystem.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        }
        .disabled(isPurchasing || visibleProducts.isEmpty)
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
        guard let product = visibleProducts.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if let _ = try await store.purchase(product) {
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
