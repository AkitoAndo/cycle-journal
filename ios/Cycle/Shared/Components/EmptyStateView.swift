//
//  EmptyStateView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// 空状態を表示するための汎用コンポーネント
///
/// `actionTitle` を渡すと、最初の一歩を促す CTA ボタンを表示する。
struct EmptyStateView: View {
    let icon: String
    let title: String
    let titleColor: Color
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        titleColor: Color = DesignSystem.Colors.textPrimary,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.titleColor = titleColor
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: icon)
                .font(DesignSystem.Fonts.largeIcon)
                .foregroundStyle(DesignSystem.Colors.accent.opacity(0.55))
                .frame(width: 96, height: 96)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.08))
                )
                .offset(y: isFloating ? -5 : 5)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                        isFloating = true
                    }
                }
                .staggeredAppear(index: 0)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Fonts.headlineRegular)
                    .foregroundStyle(titleColor)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .staggeredAppear(index: 1)

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, fullWidth: false, action: action)
                .staggeredAppear(index: 2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
