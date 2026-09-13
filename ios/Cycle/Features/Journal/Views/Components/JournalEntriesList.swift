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
    var quoteCount: (JournalEntry) -> Int = { _ in 0 }
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void
    var onQuote: ((JournalEntry) -> Void)?
    var onShowQuoteChain: ((JournalEntry) -> Void)?

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
