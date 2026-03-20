//
//  JournalEntryRow.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// ジャーナルエントリの表示用行コンポーネント
/// カード形式で角丸の枠を持つデザイン
struct JournalEntryRow: View {
    let entry: JournalEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text(entry.text)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineSpacing(4)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(entry.date.timeHM)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if !entry.tags.isEmpty {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                    }
                }
            }
        }
        .customListRowStyle()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }

            Button(action: onEdit) {
                Label("編集", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .tint(DesignSystem.Colors.accent)
        }
    }
}
