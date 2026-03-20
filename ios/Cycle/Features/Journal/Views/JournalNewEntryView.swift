//
//  JournalNewEntryView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// 新しいジャーナルエントリの作成画面
struct JournalNewEntryView: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coachStore: CoachStore

    @State private var inputText: String = ""
    @State private var selectedTags: [String] = []
    @State private var showCoachPrompt = false
    @State private var savedText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            JournalEntryForm(
                vm: vm,
                text: $inputText,
                selectedTags: $selectedTags,
                isTextFocused: $isTextFieldFocused
            )
            .navigationTitle("新しいエントリ")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert("コーチと話す？", isPresented: $showCoachPrompt) {
                Button("話してみる") {
                    Task {
                        await coachStore.startSessionWithDiary(savedText)
                    }
                    dismiss()
                    // コーチタブに切り替え＆チャット画面を開く
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .navigateToCoachChat, object: nil)
                    }
                }
                Button("あとで", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("書いた日記をもとに、コーチと振り返ってみませんか？")
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private func saveEntry() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        vm.addEntry(text: trimmedText, tags: selectedTags)

        // 保存後のフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        savedText = trimmedText
        showCoachPrompt = true
    }
}
