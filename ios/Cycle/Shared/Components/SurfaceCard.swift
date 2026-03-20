//
//  SurfaceCard.swift
//  Cycle
//
//  カード型コンテナ（surface背景 + 角丸 + ボーダー + シャドウ）
//  TaskRow, JournalEntryRow, SessionRow 等で共通利用
//

import SwiftUI

/// カード型の汎用コンテナ
///
/// 使用例:
/// ```swift
/// SurfaceCard {
///     Text("カード内のコンテンツ")
/// }
/// ```
struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                    .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(
                color: DesignSystem.Colors.brownDark.opacity(0.08),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}
