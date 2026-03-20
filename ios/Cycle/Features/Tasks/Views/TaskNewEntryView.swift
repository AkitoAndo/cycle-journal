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
            .modifier(GlassNavBarModifier())
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
        FormTextField(label: "タイトル", text: $inputTitle)
            .focused($isTitleFocused)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var descriptionSection: some View {
        FormTextEditor(label: "詳細", text: $inputDescription)
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
