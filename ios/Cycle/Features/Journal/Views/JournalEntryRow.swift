//
//  JournalEntryRow.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// ジャーナルエントリの表示用行コンポーネント
/// カード形式で角丸の枠を持つデザイン
/// 引用付きエントリは引用元の本文を並べず、右上に引用の件数バッジだけを出す。
/// 引用の中身は左スワイプの「引用を確認」ボタン（チェックマーク）から時系列で参照する
struct JournalEntryRow: View {
    let entry: JournalEntry
    /// このエントリが引用している過去エントリの件数（0 なら引用なし）
    var quoteCount: Int = 0
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// このエントリを引用して新規作成（スワイプの「引用」ボタン）
    var onQuote: (() -> Void)? = nil
    /// スワイプの「引用を確認」ボタンで引用の履歴プレビューを開く
    var onShowQuoteChain: (() -> Void)? = nil

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
        .customListRowStyle()
        // 並びは右から順に 削除 → 編集 → 引用 → 引用を確認（宣言順が右端から）
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
            }

            // 引用の左。引用を持つエントリだけに出す。
            // 色はタスクのスワイプ「プレビュー」（同じチェックマーク）と揃える
            if hasQuote, let onShowQuoteChain {
                Button(action: onShowQuoteChain) {
                    Label("引用を確認", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.textSecondary)
            }
        }
    }

    /// 右上の引用件数バッジ。件数の表示のみで、中身はスワイプの確認ボタンから開く
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
    }
}
