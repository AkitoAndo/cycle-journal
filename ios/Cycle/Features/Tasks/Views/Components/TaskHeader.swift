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
    let onShowTemplates: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("タスクリスト")
                .font(DesignSystem.Fonts.screenTitle)
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

                Button(action: onShowTemplates) {
                    Label("テンプレート管理", systemImage: "square.on.square")
                }

                Button(action: onShowDeleted) {
                    Label("最近削除した項目", systemImage: "trash")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 21))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .modifier(GlassIconModifier())
            }
            .accessibilityLabel("メニュー")
            .accessibilityIdentifier("task_menu")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.md + DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
    }
}
