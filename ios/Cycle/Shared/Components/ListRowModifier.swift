//
//  ListRowModifier.swift
//  Cycle
//
//  カスタムリスト行スタイル（共通パディング + セパレータ非表示 + 背景透明）
//  TaskRow, JournalEntryRow 等のリスト行で共通利用
//

import SwiftUI

/// カスタムリスト行スタイル
///
/// 使用例:
/// ```swift
/// TaskRow(...)
///     .modifier(CustomListRowStyle())
/// ```
struct CustomListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(
                top: DesignSystem.Spacing.xs,
                leading: DesignSystem.Spacing.lg,
                bottom: DesignSystem.Spacing.xs,
                trailing: DesignSystem.Spacing.lg
            ))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

extension View {
    func customListRowStyle() -> some View {
        modifier(CustomListRowStyle())
    }
}
