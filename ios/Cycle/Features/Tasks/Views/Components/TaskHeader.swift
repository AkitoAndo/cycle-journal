//
//  TaskHeader.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// タスク画面のヘッダー
/// ジャーナルと同じく年月の表示・「今日へ戻る」とメニューボタンを提供
struct TaskHeader: View {
    let selectedDate: Date
    /// 「今日へ戻る」タップ時の動作。今日以外を表示中のみボタンが出る
    var onToday: (() -> Void)? = nil
    let isReorderMode: Bool
    let onToggleReorderMode: () -> Void
    let onShowSearch: () -> Void
    let onShowDatePicker: () -> Void
    let onShowTemplates: () -> Void
    let onShowDeleted: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            Text(selectedDate.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ja_JP"))))
                .font(DesignSystem.Fonts.screenTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()

            if !Calendar.current.isDateInToday(selectedDate), let onToday = onToday {
                todayButton(onToday)
            }

            menuButton
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
        .animation(DesignSystem.Timing.spring, value: Calendar.current.isDateInToday(selectedDate))
    }

    // MARK: - Components

    /// 今日へ戻るボタン（ジャーナルと同じ見た目）
    private func todayButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("今日")
                .font(DesignSystem.Fonts.label)
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(DesignSystem.Colors.accent.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityIdentifier("task_today_button")
    }

    private var menuButton: some View {
        Menu {
            Button(action: onShowSearch) {
                Label("検索", systemImage: "magnifyingglass")
            }

            Button(action: onShowDatePicker) {
                Label("日付選択", systemImage: "calendar")
            }

            Button(action: onToggleReorderMode) {
                Label(
                    isReorderMode ? "並び替え完了" : "並び替え",
                    systemImage: isReorderMode ? "checkmark" : "arrow.up.arrow.down"
                )
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
}
