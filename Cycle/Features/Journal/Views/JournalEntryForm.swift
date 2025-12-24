//
//  JournalEntryForm.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// ジャーナルエントリの作成・編集用フォーム
/// NewEntryViewとEditViewで共通利用
struct JournalEntryForm: View {
    @ObservedObject var vm: JournalViewModel
    @Binding var text: String
    @Binding var selectedTags: [String]
    @FocusState.Binding var isTextFocused: Bool

    let textEditorMinHeight: CGFloat

    init(
        vm: JournalViewModel,
        text: Binding<String>,
        selectedTags: Binding<[String]>,
        isTextFocused: FocusState<Bool>.Binding,
        textEditorMinHeight: CGFloat = 200
    ) {
        self.vm = vm
        self._text = text
        self._selectedTags = selectedTags
        self._isTextFocused = isTextFocused
        self.textEditorMinHeight = textEditorMinHeight
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // 内容入力セクション
                contentSection

                // タグ選択セクション
                TagSelector(
                    availableTags: vm.allTags,
                    selectedTags: $selectedTags
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.top, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.background)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("内容")
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            TextEditor(text: $text)
                .focused($isTextFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: textEditorMinHeight)
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
}
