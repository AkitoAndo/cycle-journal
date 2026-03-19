//
//  TaskEmptyState.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// タスクが空の時に表示する状態
struct TaskEmptyState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("タスクがまだありません")
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("+ボタンから新しいタスクを追加できます")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
