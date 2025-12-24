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

    init(vm: TaskViewModel, task: TaskItem) {
        self.vm = vm
        self.task = task
        _editTitle = State(initialValue: task.title)
        _editDescription = State(initialValue: task.description)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // タイトル編集セクション
                    titleSection

                    // 詳細編集セクション
                    descriptionSection
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
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
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("タイトル")
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextField("", text: $editTitle)
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
            Text("詳細（任意）")
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextEditor(text: $editDescription)
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

    private func saveChanges() {
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDescription = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        vm.updateTask(task, newTitle: trimmedTitle, newDescription: trimmedDescription)

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
