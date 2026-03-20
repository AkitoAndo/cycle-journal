//
//  TaskPreviewView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/07.
//

import SwiftUI

/// タスクプレビュービュー
/// タスクの全情報を読み取り専用で表示
struct TaskPreviewView: View {
    let task: TaskItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    titleSection

                    if !task.description.isEmpty {
                        descriptionSection
                    }

                    if !task.intent.isEmpty {
                        fieldSection(title: "意図", content: task.intent)
                    }

                    if !task.achievementVision.isEmpty {
                        fieldSection(title: "完了イメージ", content: task.achievementVision)
                    }

                    if !task.notes.isEmpty {
                        fieldSection(title: "注意点", content: task.notes)
                    }

                    if !task.fact.isEmpty {
                        fieldSection(title: "事実", content: task.fact)
                    }

                    if !task.insight.isEmpty {
                        fieldSection(title: "気づき", content: task.insight)
                    }

                    if !task.nextAction.isEmpty {
                        fieldSection(title: "次の一手", content: task.nextAction)
                    }
                }
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("タスクプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("タイトル")
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            SurfaceCard {
                Text(task.title)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var descriptionSection: some View {
        fieldSection(title: "詳細", content: task.description)
    }

    private func fieldSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            SurfaceCard {
                Text(content)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}
