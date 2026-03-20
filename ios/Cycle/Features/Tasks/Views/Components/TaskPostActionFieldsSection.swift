//
//  TaskPostActionFieldsSection.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/03/01.
//

import SwiftUI

/// タスク事後フィールド入力セクション
/// 事実・気づき・次の一手を縦一覧で入力
struct TaskPostActionFieldsSection: View {
    @Binding var fact: String
    @Binding var insight: String
    @Binding var nextAction: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            fieldSection(
                title: "事実",
                text: $fact,
                placeholder: "実際に何をどこまでやった？"
            )

            fieldSection(
                title: "気づき",
                text: $insight,
                placeholder: "うまくいった要因／詰まった要因は？"
            )

            fieldSection(
                title: "次の一手",
                text: $nextAction,
                placeholder: "次回は何を1つだけ変える？"
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
