//
//  ErrorBannerView.swift
//  CycleJournal
//

import SwiftUI

struct ErrorBannerView: View {
    let message: String
    var isRetryable: Bool = false
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(.orange)

            Text(message)
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(2)

            Spacer()

            if isRetryable, let onRetry {
                Button("リトライ") {
                    onRetry()
                }
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.accent)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
