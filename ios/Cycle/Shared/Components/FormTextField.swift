//
//  FormTextField.swift
//  Cycle
//
//  ラベル付きテキスト入力フィールド（1行）
//  タスク・日記のタイトル入力等で共通利用
//

import SwiftUI

/// ラベル付きの1行テキストフィールド
///
/// 使用例:
/// ```swift
/// FormTextField(label: "タイトル", text: $title)
/// ```
struct FormTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(label)
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                        .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
                )
                .tint(DesignSystem.Colors.accent)
        }
    }
}
