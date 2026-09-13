//
//  JournalEntriesList.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// ジャーナルエントリ一覧
/// 選択された日のエントリを表示
struct JournalEntriesList: View {
    let entries: [JournalEntry]
    /// このエントリが引用している過去エントリの件数（右上のバッジ表示用。0 なら引用なし）
    var quoteCount: (JournalEntry) -> Int = { _ in 0 }
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void
    /// スワイプ「引用」でこのエントリを引用して新規作成
    var onQuote: ((JournalEntry) -> Void)? = nil
    /// 右スワイプの確認ボタンで引用の履歴プレビューを開く
    var onShowQuoteChain: ((JournalEntry) -> Void)? = nil

    var body: some View {
        List {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                JournalEntryRow(
                    entry: entry,
                    quoteCount: quoteCount(entry),
                    onEdit: { onEdit(entry) },
                    onDelete: { onDelete(entry) },
                    onQuote: onQuote.map { handler in { handler(entry) } },
                    onShowQuoteChain: onShowQuoteChain.map { handler in { handler(entry) } }
                )
                .staggeredAppear(index: index, group: "journal_list")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, DesignSystem.Spacing.md, for: .scrollContent)
        .animation(DesignSystem.Timing.spring, value: entries.map(\.id))
    }
}
