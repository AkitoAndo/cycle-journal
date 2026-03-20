//
//  TaskExtendedFieldsSection.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/07.
//

import SwiftUI

/// タスク拡張フィールド入力セクション
/// 意図・完了イメージ・注意点を縦一覧で入力
struct TaskExtendedFieldsSection: View {
    @Binding var intent: String
    @Binding var achievementVision: String
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            fieldSection(
                title: "意図",
                text: $intent,
                placeholder: "このタスクの目的や意図を記述"
            )

            fieldSection(
                title: "完了イメージ",
                text: $achievementVision,
                placeholder: "完了時の理想的な状態を記述"
            )

            fieldSection(
                title: "注意点",
                text: $notes,
                placeholder: "注意すべき点やリスクを記述"
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func fieldSection(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
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
                    if text.wrappedValue.isEmpty {
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
