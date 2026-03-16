//
//  TagChip.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// タグを表示するための小さなチップコンポーネント
struct TagChip: View {
    let text: String
    var isInteractive: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if isInteractive, let onTap = onTap {
                Button(action: onTap) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        Text(text)
            .font(.system(size: DesignSystem.FontSize.caption - 1))
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.Colors.grey)
            .clipShape(Capsule())
    }
}
