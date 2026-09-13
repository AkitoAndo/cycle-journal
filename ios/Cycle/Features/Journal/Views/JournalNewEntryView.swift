//
//  JournalNewEntryView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// 新しいジャーナルエントリの作成画面
/// 過去のジャーナルを引用して書く場合は quotedEntry を渡す（引用元カードを表示）
struct JournalNewEntryView: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    /// 引用元エントリ（スワイプの「引用」から開いた場合に設定）
    var quotedEntry: JournalEntry? = nil

    @State private var inputText: String = ""
    @State private var selectedTags: [String] = []
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            JournalEntryForm(
                vm: vm,
                text: $inputText,
                selectedTags: $selectedTags,
                isTextFocused: $isTextFieldFocused,
                hasQuote: quotedEntry != nil,
                quotedSource: quotedEntry
            )
            .navigationTitle(quotedEntry == nil ? "新しいエントリ" : "引用して書く")
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
                        saveEntry()
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private func saveEntry() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        vm.addEntry(text: trimmedText, tags: selectedTags, quotedEntryId: quotedEntry?.id)

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        dismiss()
    }
}
