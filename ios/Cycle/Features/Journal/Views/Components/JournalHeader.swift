//
//  JournalHeader.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// ジャーナル画面のヘッダー
/// 年月の表示・継続日数・「今日へ戻る」とメニューボタンを提供
struct JournalHeader: View {
    let selectedDate: Date
    /// 連続記録日数（2日以上でバッジ表示）
    var streakDays: Int = 0
    /// 「今日へ戻る」タップ時の動作。今日以外を表示中のみボタンが出る
    var onToday: (() -> Void)? = nil
    let onShowSearch: () -> Void
    let onShowDatePicker: () -> Void
    let onShowTagManagement: () -> Void
    let onShowDeleted: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            monthYearTitle

            if streakDays >= 2 {
                streakBadge
            }

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

    private var monthYearTitle: some View {
        Text(selectedDate.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ja_JP"))))
            .font(DesignSystem.Fonts.screenTitle)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    /// 継続日数バッジ
    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
            Text("\(streakDays)日")
                .font(.system(size: DesignSystem.FontSize.caption, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(DesignSystem.Colors.accent)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.accent.opacity(0.10))
        .clipShape(Capsule())
        .accessibilityLabel("\(streakDays)日連続で記録中")
    }

    /// 今日へ戻るボタン
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
        .accessibilityIdentifier("journal_today_button")
    }

    private var menuButton: some View {
        Menu {
            Button(action: onShowSearch) {
                Label("検索", systemImage: "magnifyingglass")
            }

            Button(action: onShowDatePicker) {
                Label("日付選択", systemImage: "calendar")
            }

            Button(action: onShowTagManagement) {
                Label("タグ管理", systemImage: "tag")
            }

            Button(action: onShowDeleted) {
                Label("最近削除した項目", systemImage: "trash")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 26))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .modifier(GlassIconModifier())
        }
        .accessibilityLabel("メニュー")
        .accessibilityIdentifier("journal_menu")
    }
}
