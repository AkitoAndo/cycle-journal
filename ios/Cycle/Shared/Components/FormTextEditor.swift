//
//  FormTextEditor.swift
//  Cycle
//
//  ラベル付き複数行テキストエディタ
//  タスク詳細・日記本文・振り返り入力等で共通利用
//

import SwiftUI

/// ラベル付きの複数行テキストエディタ
///
/// 使用例:
/// ```swift
/// FormTextEditor(label: "詳細", text: $description, placeholder: "タスクの詳細を入力")
/// FormTextEditor(label: "本文", text: $content, minHeight: 200)
/// ```
struct FormTextEditor: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(label)
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md)
                        .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
                )
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .font(DesignSystem.Fonts.body)
                .tint(DesignSystem.Colors.accent)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .font(DesignSystem.Fonts.body)
                            .padding(EdgeInsets(top: 20, leading: 17, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
