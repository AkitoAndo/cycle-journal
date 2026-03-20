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
        FormTextEditor(label: title, text: text, placeholder: placeholder)
    }
}
