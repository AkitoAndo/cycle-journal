//
//  DiaryPickerView.swift
//  CycleJournal
//

import SwiftUI

struct DiaryPickerView: View {
    @EnvironmentObject var journalViewModel: JournalViewModel
    @Environment(\.dismiss) var dismiss

    let onSelect: (JournalEntry) -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E) HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Group {
                if journalViewModel.allEntries.isEmpty {
                    EmptyStateView(
                        icon: "book",
                        title: "日記がありません",
                        subtitle: "日記を書くと、ここから選んでコーチに話せます"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(journalViewModel.allEntries.prefix(20)) { entry in
                                Button(action: { onSelect(entry) }) {
                                    SurfaceCard {
                                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                            Text(dateFormatter.string(from: entry.date))
                                                .font(DesignSystem.Fonts.caption)
                                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                                            Text(entry.text)
                                                .font(DesignSystem.Fonts.body)
                                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            if !entry.tags.isEmpty {
                                                HStack(spacing: DesignSystem.Spacing.xs) {
                                                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                                        TagChip(text: tag)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("日記を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }
}
