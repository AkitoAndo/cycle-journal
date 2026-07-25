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
    let onEdit: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void

    var body: some View {
        List {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                JournalEntryRow(
                    entry: entry,
                    onEdit: { onEdit(entry) },
                    onDelete: { onDelete(entry) }
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
