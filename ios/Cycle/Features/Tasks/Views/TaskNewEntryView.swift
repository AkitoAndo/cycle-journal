//
//  TaskNewEntryView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//
//  新規タスクの入力フォーム（テンプレート追加と同じ項目構成）。
//  タイトル・詳細・意図・完了イメージ・注意点を1画面で入力する。
//  事後情報（事実・気づき・次の一手）は実行後に編集画面から記入する。
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
    @State private var showTemplatePicker = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    titleSection
                    descriptionSection

                    TaskExtendedFieldsSection(
                        intent: $inputIntent,
                        achievementVision: $inputAchievementVision,
                        notes: $inputNotes
                    )
                }
                .padding(.top, DesignSystem.Spacing.xl)
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

    /// タイトル入力（ラベル行の右端に「テンプレートを使用する」ボタンを配置）
    /// FormTextField は他画面でも使う共通コンポーネントのため、この画面のみ
    /// 同じ見た目のカスタムレイアウトで組む。
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .center) {
                Text("タイトル")
                    .font(DesignSystem.Fonts.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Spacer()

                Button {
                    showTemplatePicker = true
                } label: {
                    Label("テンプレートを使用する", systemImage: "square.on.square")
                        .font(DesignSystem.Fonts.subheadline)
                }
                .tint(DesignSystem.Colors.accent)
            }

            TextField("", text: $inputTitle)
                .textFieldStyle(.plain)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(DesignSystem.Spacing.lg)
                .modifier(FormFieldBackground())
                .tint(DesignSystem.Colors.accent)
                .focused($isTitleFocused)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .sheet(isPresented: $showTemplatePicker) {
            TaskTemplatePickerView(
                vm: vm,
                canRegister: !inputTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onApply: applyTemplate,
                onRegister: registerTemplate
            )
        }
    }

    private var descriptionSection: some View {
        FormTextEditor(label: "詳細", text: $inputDescription)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Template

    /// 現在の入力内容（テンプレート登録用のドラフト）
    private var currentDraft: TaskTemplate {
        TaskTemplate(
            title: inputTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: inputDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            intent: inputIntent.trimmingCharacters(in: .whitespacesAndNewlines),
            achievementVision: inputAchievementVision.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: inputNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// テンプレートの内容をフォームに反映する
    private func applyTemplate(_ template: TaskTemplate) {
        inputTitle = template.title
        inputDescription = template.description
        inputIntent = template.intent
        inputAchievementVision = template.achievementVision
        inputNotes = template.notes
    }

    /// 現在のフォーム内容をテンプレートとして登録する
    private func registerTemplate() {
        vm.addTemplate(currentDraft)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveTask() {
        let trimmedTitle = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        vm.addTask(
            title: trimmedTitle,
            description: inputDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            intent: inputIntent.trimmingCharacters(in: .whitespacesAndNewlines),
            achievementVision: inputAchievementVision.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: inputNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
