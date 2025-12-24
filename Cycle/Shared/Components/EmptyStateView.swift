//
//  EmptyStateView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// 空状態を表示するための汎用コンポーネント
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .symbolEffect(.pulse.byLayer, options: .repeat(3))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: DesignSystem.FontSize.body))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
