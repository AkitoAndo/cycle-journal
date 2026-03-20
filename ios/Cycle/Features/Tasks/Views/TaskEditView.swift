//
//  TaskEditView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import SwiftUI

struct TaskEditView: View {
    @ObservedObject var vm: TaskViewModel
    let task: TaskItem
    @Environment(\.dismiss) private var dismiss

    @State private var editTitle: String
    @State private var editDescription: String
    @State private var editIntent: String
    @State private var editAchievementVision: String
    @State private var editNotes: String
    @State private var editFact: String
    @State private var editInsight: String
    @State private var editNextAction: String
    @State private var selectedSection: TaskSectionTabs.Section = .basic

    init(vm: TaskViewModel, task: TaskItem) {
        self.vm = vm
        self.task = task
        _editTitle = State(initialValue: task.title)
        _editDescription = State(initialValue: task.description)
        _editIntent = State(initialValue: task.intent)
        _editAchievementVision = State(initialValue: task.achievementVision)
        _editNotes = State(initialValue: task.notes)
        _editFact = State(initialValue: task.fact)
        _editInsight = State(initialValue: task.insight)
        _editNextAction = State(initialValue: task.nextAction)
    }

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
            .navigationTitle("タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private var titleSection: some View {
        FormTextField(label: "タイトル", text: $editTitle)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var descriptionSection: some View {
        FormTextEditor(label: "詳細", text: $editDescription)
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
            intent: $editIntent,
            achievementVision: $editAchievementVision,
            notes: $editNotes
        )
    }

    private var postActionSectionContent: some View {
        TaskPostActionFieldsSection(
            fact: $editFact,
            insight: $editInsight,
            nextAction: $editNextAction
        )
    }

    private func saveChanges() {
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDescription = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIntent = editIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVision = editAchievementVision.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFact = editFact.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInsight = editInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNextAction = editNextAction.trimmingCharacters(in: .whitespacesAndNewlines)

        vm.updateTask(
            task,
            newTitle: trimmedTitle,
            newDescription: trimmedDescription,
            newIntent: trimmedIntent,
            newAchievementVision: trimmedVision,
            newNotes: trimmedNotes,
            newFact: trimmedFact,
            newInsight: trimmedInsight,
            newNextAction: trimmedNextAction
        )

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
