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
    @State private var selectedSection: TaskSectionTabs.Section = .basic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // セクションタブ（編集画面と同じ構成）
                TaskSectionTabs(
                    selectedSection: selectedSection,
                    onSelectSection: { section in
                        selectedSection = section
                    }
                )

                ScrollView {
                    Group {
                        if selectedSection == .basic {
                            basicSectionContent
                        } else if selectedSection == .detail {
                            detailSectionContent
                        } else {
                            postActionSectionContent
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
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

    // MARK: - Section Contents

    // 未入力の項目もラベルとカードを表示する（カード内は「未記入」表示）
    private var basicSectionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            titleSection
            descriptionSection
        }
    }

    private var detailSectionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            fieldSection(title: "意図", content: task.intent)
            fieldSection(title: "完了イメージ", content: task.achievementVision)
            fieldSection(title: "注意点", content: task.notes)
        }
    }

    private var postActionSectionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            fieldSection(title: "事実", content: task.fact)
            fieldSection(title: "気づき", content: task.insight)
            fieldSection(title: "次の一手", content: task.nextAction)
        }
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
                // 未入力でもカードの高さ（1行分）を保つため空白文字を表示
                Text(content.isEmpty ? " " : content)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}
