//
//  TaskTemplateEditView.swift
//  Cycle
//
//  テンプレートの新規作成・編集フォーム（タスクの入力欄と同じ構成）。
//  タイトル・詳細・意図・完了イメージ・注意点を入力できる。
//  事後情報はタスクごとに変わる値のためテンプレート対象外。
//

import SwiftUI

struct TaskTemplateEditView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    /// 編集対象（nil なら新規作成）
    private let editingTemplate: TaskTemplate?

    @State private var inputTitle: String
    @State private var inputDescription: String
    @State private var inputIntent: String
    @State private var inputAchievementVision: String
    @State private var inputNotes: String
    @FocusState private var isTitleFocused: Bool

    init(vm: TaskViewModel, template: TaskTemplate? = nil) {
        self.vm = vm
        self.editingTemplate = template
        _inputTitle = State(initialValue: template?.title ?? "")
        _inputDescription = State(initialValue: template?.description ?? "")
        _inputIntent = State(initialValue: template?.intent ?? "")
        _inputAchievementVision = State(initialValue: template?.achievementVision ?? "")
        _inputNotes = State(initialValue: template?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    FormTextField(label: "タイトル", text: $inputTitle)
                        .focused($isTitleFocused)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                    FormTextEditor(label: "詳細", text: $inputDescription)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                    TaskExtendedFieldsSection(
                        intent: $inputIntent,
                        achievementVision: $inputAchievementVision,
                        notes: $inputNotes
                    )
                }
                .padding(.top, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(editingTemplate == nil ? "新しいテンプレート" : "テンプレートを編集")
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
                        saveTemplate()
                    }
                    .disabled(inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if editingTemplate == nil {
                    isTitleFocused = true
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private func saveTemplate() {
        var template = editingTemplate ?? TaskTemplate(title: "")
        template.title = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        template.description = inputDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        template.intent = inputIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        template.achievementVision = inputAchievementVision.trimmingCharacters(in: .whitespacesAndNewlines)
        template.notes = inputNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        if editingTemplate == nil {
            vm.addTemplate(template)
        } else {
            vm.updateTemplate(template)
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
