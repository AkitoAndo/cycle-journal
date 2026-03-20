//
//  FormTextField.swift
//  Cycle
//
//  ラベル付きテキスト入力フィールド（1行）
//  iOS 26+: Liquid Glass 背景
//  iOS 17-25: surface背景 + ボーダー
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
                .modifier(FormFieldBackground())
                .tint(DesignSystem.Colors.accent)
        }
    }
}

/// フォームフィールドの背景スタイル（TextField / TextEditor 共通）
struct FormFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                        .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
                )
        }
    }
}
