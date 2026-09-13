//
//  QuotedJournalCard.swift
//  Cycle
//

import SwiftUI

/// 引用元ジャーナルを表示するカード
struct QuotedJournalCard: View {
    let source: JournalEntry?
    var lineLimit: Int = 3
    var olderCount: Int = 0
    var onShowQuoteChain: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(DesignSystem.Colors.brownLight)
                .frame(width: 3)

            if let source {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "quote.opening")
                            .font(DesignSystem.Fonts.caption2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("\(source.date.ymdString) \(source.date.timeHM)")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Spacer(minLength: 0)
                    }

                    Text(source.text)
                        .font(DesignSystem.Fonts.subheadline)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(lineLimit)

                    if olderCount > 0 {
                        Text("さらに過去の引用が\(olderCount)件")
                            .font(DesignSystem.Fonts.caption2)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            } else {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "quote.opening")
                        .font(DesignSystem.Fonts.caption2)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    Text("引用元のジャーナルは削除されました")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Spacing.sm, style: .continuous)
                .fill(DesignSystem.Colors.grey.opacity(0.35))
        )
        .overlay(alignment: .topTrailing) {
            if let onShowQuoteChain {
                Button(action: onShowQuoteChain) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .padding(DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("引用の履歴を表示")
            }
        }
    }

    private var accessibilityText: String {
        guard let source else { return "引用元のジャーナルは削除されました" }
        var text = "\(source.date.ymdString) \(source.date.timeHM) のジャーナルを引用: \(source.text)"
        if olderCount > 0 {
            text += "、さらに過去の引用が\(olderCount)件"
        }
        return text
    }
}
