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
            ForEach(entries) { entry in
                JournalEntryRow(
                    entry: entry,
                    onEdit: { onEdit(entry) },
                    onDelete: { onDelete(entry) }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }
}
