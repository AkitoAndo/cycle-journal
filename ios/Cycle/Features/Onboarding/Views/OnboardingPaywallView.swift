//
//  OnboardingPaywallView.swift
//  CycleJournal
//
//  Issue #37 C-1: 課金再開時に Paywall を戻すためのオンボーディング終端ラッパー.
//

import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject private var flow: OnboardingFlow

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            IconCircle(icon: "checkmark.seal.fill", size: 96, color: DesignSystem.Colors.accent)

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("準備できました")
                    .font(DesignSystem.Fonts.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("MVP期間中は無料で利用できます")
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()

            PrimaryButton("はじめる", icon: "arrow.right") {
                flow.advance()
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.background.ignoresSafeArea())
    }
}
