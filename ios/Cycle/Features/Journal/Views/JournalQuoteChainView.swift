//
//  JournalQuoteChainView.swift
//  Cycle
//
//  引用の履歴プレビュー。
//  引用が重なったエントリの全ての引用元を、最も古いものから順に
//  タイムライン形式（縦の接続線 + 日付）で表示する。
//  一覧・編集画面の引用カード内の履歴ボタンから開く。
//

import SwiftUI

/// 引用チェーン全体を時系列で確認するプレビュー画面
struct JournalQuoteChainView: View {
    @ObservedObject var vm: JournalViewModel
    /// 起点となるエントリ（このエントリから引用元を遡る）
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    /// 最も古い引用元 → このエントリ自身の順
    private var chain: [JournalEntry] { vm.quoteChain(for: entry) }

    /// 完全削除でこれより前をたどれなくなったか
    private var isTruncated: Bool { chain.first?.quotedEntryId != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isTruncated {
                        truncatedNotice
                    }

                    ForEach(Array(chain.enumerated()), id: \.element.id) { index, item in
                        chainItem(item, isLast: index == chain.count - 1)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("引用の履歴")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    /// これより前の引用元が完全削除されている場合の表示
    private var truncatedNotice: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "quote.opening")
                .font(DesignSystem.Fonts.caption2)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            Text("これより前の引用元は削除されました")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.leading, DesignSystem.Spacing.xl + DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    /// タイムラインの1項目（左=接続線付きの点、右=エントリカード）
    private func chainItem(_ item: JournalEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // タイムラインの点と接続線
            VStack(spacing: 0) {
                Circle()
                    .fill(isLast ? DesignSystem.Colors.accent : DesignSystem.Colors.brownLight)
                    .frame(width: 9, height: 9)
                    .padding(.top, DesignSystem.Spacing.lg + 4)
                if !isLast {
                    Rectangle()
                        .fill(DesignSystem.Colors.brownLight.opacity(0.45))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: DesignSystem.Spacing.xl)

            SurfaceCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("\(item.date.ymdString) \(item.date.timeHM)")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        if isLast {
                            Text("このエントリ")
                                .font(DesignSystem.Fonts.caption2)
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent.opacity(0.12))
                                )
                        }
                    }

                    Text(item.text)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)

                    if !item.tags.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(item.tags, id: \.self) { tag in
                                TagChip(text: tag)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : DesignSystem.Spacing.lg)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.date.ymdString) \(item.date.timeHM)\(isLast ? "、このエントリ" : "")、\(item.text)"
        )
    }
}
