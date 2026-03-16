//
//  TaskNewEntryView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import SwiftUI

struct TaskNewEntryView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inputTitle: String = ""
    @State private var inputDescription: String = ""
    @State private var inputIntent: String = ""
    @State private var inputAchievementVision: String = ""
    @State private var inputNotes: String = ""
    @State private var inputFact: String = ""
    @State private var inputInsight: String = ""
    @State private var inputNextAction: String = ""
    @State private var selectedSection: TaskSectionTabs.Section = .basic
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // セクションタブ
                TaskSectionTabs(
                    selectedSection: selectedSection,
                    onSelectSection: { section in
                        selectedSection = section
                    }
                )

                // コンテンツエリア
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
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("新しいタスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("タイトル")
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextField("", text: $inputTitle)
                .focused($isTitleFocused)
                .textFieldStyle(.plain)
                .font(.system(size: DesignSystem.FontSize.body))
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
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("詳細")
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextEditor(text: $inputDescription)
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
                .font(.system(size: DesignSystem.FontSize.body))
                .tint(DesignSystem.Colors.accent)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Section Contents

    private var basicSectionContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            titleSection
            descriptionSection
        }
    }

    private var detailSectionContent: some View {
        TaskExtendedFieldsSection(
            intent: $inputIntent,
            achievementVision: $inputAchievementVision,
            notes: $inputNotes
        )
    }

    private var postActionSectionContent: some View {
        TaskPostActionFieldsSection(
            fact: $inputFact,
            insight: $inputInsight,
            nextAction: $inputNextAction
        )
    }

    private func saveTask() {
        let trimmedTitle = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDescription = inputDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIntent = inputIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVision = inputAchievementVision.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = inputNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFact = inputFact.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInsight = inputInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNextAction = inputNextAction.trimmingCharacters(in: .whitespacesAndNewlines)

        vm.addTask(
            title: trimmedTitle,
            description: trimmedDescription,
            intent: trimmedIntent,
            achievementVision: trimmedVision,
            notes: trimmedNotes,
            fact: trimmedFact,
            insight: trimmedInsight,
            nextAction: trimmedNextAction
        )

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
