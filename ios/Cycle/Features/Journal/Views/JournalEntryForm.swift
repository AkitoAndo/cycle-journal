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
    /// 引用付きエントリの場合 true（引用元カードを表示）
    let hasQuote: Bool
    /// 引用元エントリ（完全削除済みで取得できない場合は nil のままプレースホルダー表示）
    let quotedSource: JournalEntry?
    /// 直接の引用元より前にさらに遡れる引用元の件数（引用カードのヒント表示用）
    let quoteOlderCount: Int
    /// 引用カードの履歴ボタンで引用の履歴プレビューを開く（nil ならボタン非表示）
    let onShowQuoteChain: (() -> Void)?

    init(
        vm: JournalViewModel,
        text: Binding<String>,
        selectedTags: Binding<[String]>,
        isTextFocused: FocusState<Bool>.Binding,
        textEditorMinHeight: CGFloat = 200,
        hasQuote: Bool = false,
        quotedSource: JournalEntry? = nil,
        quoteOlderCount: Int = 0,
        onShowQuoteChain: (() -> Void)? = nil
    ) {
        self.vm = vm
        self._text = text
        self._selectedTags = selectedTags
        self._isTextFocused = isTextFocused
        self.textEditorMinHeight = textEditorMinHeight
        self.hasQuote = hasQuote
        self.quotedSource = quotedSource
        self.quoteOlderCount = quoteOlderCount
        self.onShowQuoteChain = onShowQuoteChain
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // 引用元セクション（引用して書くときのみ）
                if hasQuote {
                    QuotedJournalCard(
                        source: quotedSource,
                        lineLimit: 6,
                        olderCount: quoteOlderCount,
                        onShowQuoteChain: onShowQuoteChain
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

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
        FormTextEditor(label: "日記", text: $text, placeholder: "", height: 200)
            .focused($isTextFocused)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}
