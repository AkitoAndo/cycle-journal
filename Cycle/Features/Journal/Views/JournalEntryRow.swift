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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // エントリ本文
            Text(entry.text)
                .font(.system(size: DesignSystem.FontSize.body))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineSpacing(4)

            // メタ情報（時刻とタグ）
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(entry.date.timeHM)
                    .font(.system(size: DesignSystem.FontSize.caption))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                if !entry.tags.isEmpty {
                    ForEach(entry.tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(
            color: DesignSystem.Colors.brownDark.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        .listRowInsets(
            EdgeInsets(
                top: DesignSystem.Spacing.xs,
                leading: DesignSystem.Spacing.lg,
                bottom: DesignSystem.Spacing.xs,
                trailing: DesignSystem.Spacing.lg
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
