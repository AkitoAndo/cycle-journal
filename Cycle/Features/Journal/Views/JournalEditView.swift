//
//  JournalEditView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// ジャーナルエントリの編集画面
struct JournalEditView: View {
    @ObservedObject var vm: JournalViewModel
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    @State private var editText: String
    @State private var editTags: [String]
    @FocusState private var isTextFieldFocused: Bool

    init(vm: JournalViewModel, entry: JournalEntry) {
        self.vm = vm
        self.entry = entry
        _editText = State(initialValue: entry.text)
        _editTags = State(initialValue: entry.tags)
    }

    var body: some View {
        NavigationStack {
            JournalEntryForm(
                vm: vm,
                text: $editText,
                selectedTags: $editTags,
                isTextFocused: $isTextFieldFocused,
                textEditorMinHeight: 150
            )
            .navigationTitle("エントリを編集")
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
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        let trimmedText = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        vm.updateEntry(entry, newText: trimmedText, newTags: editTags)

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
