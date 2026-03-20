//
//  SectionLabel.swift
//  Cycle
//
//  セクション見出しラベル
//  「最近の会話」「未完了」等のセクションヘッダーで共通利用
//

import SwiftUI

/// セクション見出しラベル
///
/// 使用例:
/// ```swift
/// SectionLabel("最近の会話")
/// SectionLabel("未完了", icon: "circle")
/// ```
struct SectionLabel: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(DesignSystem.Fonts.caption)
            }
            Text(title)
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}
