//
//  QuotedJournalCard.swift
//  Cycle
//
//  引用元ジャーナルの表示カード。
//  引用付きエントリの行（上=引用元・下=本文の順で時系列に読める）と、
//  引用しての新規作成・編集フォームで共通利用。
//  引用元が完全削除されて見つからない場合はプレースホルダーを表示。
//

import SwiftUI

/// 引用元ジャーナルを表示するカード
///
/// 左のアクセントバー + 引用マーク + 引用元の日付で、
/// 「過去のジャーナル」であることがひと目で分かるようにする。
struct QuotedJournalCard: View {
    /// 引用元エントリ。完全削除済みで取得できない場合は nil
    let source: JournalEntry?
    /// 本文の表示行数上限（フォームなど全文寄りに見せたい場合は増やす）
    var lineLimit: Int = 3
    /// 直接の引用元より前に、さらに遡れる引用元の件数（引用が重なっている場合）
    var olderCount: Int = 0
    /// 履歴ボタンのタップで引用の履歴プレビューを開く（nil ならボタン非表示）
    var onShowQuoteChain: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // 引用のアクセントバー
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
        // 履歴ボタンを独立した要素として残すため、本文側だけをまとめて読み上げる
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
