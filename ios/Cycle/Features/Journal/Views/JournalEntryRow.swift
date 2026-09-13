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
    var quoteCount: Int = 0
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onQuote: (() -> Void)?
    var onShowQuoteChain: (() -> Void)?

    private var hasQuote: Bool { quoteCount > 0 }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Text(entry.text)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if hasQuote {
                        quoteCountBadge
                    }
                }

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
        .accessibilityIdentifier("journal_entry_\(entry.id.uuidString)")
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

            if let onQuote {
                Button(action: onQuote) {
                    Label("引用", systemImage: "arrowshape.turn.up.backward")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.brownLight)
                .accessibilityIdentifier("journal_quote_\(entry.id.uuidString)")
            }

            if hasQuote, let onShowQuoteChain {
                Button(action: onShowQuoteChain) {
                    Label("引用を確認", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.textSecondary)
                .accessibilityIdentifier("journal_quote_history_\(entry.id.uuidString)")
            }
        }
    }

    private var quoteCountBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "quote.opening")
            Text("\(quoteCount)")
        }
        .font(.system(size: DesignSystem.FontSize.caption - 1, weight: .medium, design: .rounded))
        .foregroundStyle(DesignSystem.Colors.accent)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.accent.opacity(0.10), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("引用\(quoteCount)件")
        .accessibilityHint("左スワイプのチェックマークで引用の履歴を表示")
        .accessibilityIdentifier("journal_quote_count_\(entry.id.uuidString)")
    }
}
