//
//  JournalHeader.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// ジャーナル画面のヘッダー
/// 年月の表示とメニューボタンを提供
struct JournalHeader: View {
    let selectedDate: Date
    let onShowSearch: () -> Void
    let onShowDatePicker: () -> Void
    let onShowTagManagement: () -> Void
    let onShowDeleted: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            monthYearTitle
            Spacer()
            menuButton
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Components

    private var monthYearTitle: some View {
        Text(selectedDate.formatted(.dateTime.year().month(.wide)))
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(DesignSystem.Colors.textPrimary)
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
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 26))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}
