//
//  TaskHeader.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// タスク画面のヘッダー
/// タイトルとメニューボタンを表示
struct TaskHeader: View {
    let isReorderMode: Bool
    let onToggleReorderMode: () -> Void
    let onShowArchive: () -> Void
    let onShowDeleted: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Today's Focus")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            Menu {
                Button(action: onToggleReorderMode) {
                    Label(
                        isReorderMode ? "並び替え完了" : "並び替え",
                        systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down"
                    )
                }

                Button(action: onShowArchive) {
                    Label("アーカイブ", systemImage: "archivebox")
                }

                Button(action: onShowDeleted) {
                    Label("最近削除した項目", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
    }
}
