//
//  TaskPostActionEntryView.swift
//  Cycle
//
//  タスクをチェック（完了）した時に事後情報（事実・気づき・次の一手）を
//  記入するフォーム。マイページの「完了時に事後情報を記入」がオンのとき、
//  チェックと同時にシートで表示される。
//  スキップしてもタスクの完了状態はそのまま（後から編集画面で記入できる）。
//

import SwiftUI

struct TaskPostActionEntryView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    /// 記入対象のタスク（チェック時点のスナップショット）
    private let task: TaskItem

    @State private var inputFact: String
    @State private var inputInsight: String
    @State private var inputNextAction: String

    init(vm: TaskViewModel, task: TaskItem) {
        self.vm = vm
        self.task = task
        _inputFact = State(initialValue: task.fact)
        _inputInsight = State(initialValue: task.insight)
        _inputNextAction = State(initialValue: task.nextAction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    completedTaskTitle

                    TaskPostActionFieldsSection(
                        fact: $inputFact,
                        insight: $inputInsight,
                        nextAction: $inputNextAction
                    )
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("事後情報")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        savePostAction()
                    }
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    /// どのタスクの記入かが分かるように、完了したタスク名を上部に表示
    private var completedTaskTitle: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignSystem.FontSize.title3))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(task.title)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func savePostAction() {
        vm.updateTask(
            task,
            newTitle: task.title,
            newDescription: task.description,
            newIntent: task.intent,
            newAchievementVision: task.achievementVision,
            newNotes: task.notes,
            newFact: inputFact.trimmingCharacters(in: .whitespacesAndNewlines),
            newInsight: inputInsight.trimmingCharacters(in: .whitespacesAndNewlines),
            newNextAction: inputNextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
