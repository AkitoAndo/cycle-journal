//
//  DiaryPickerView.swift
//  CycleJournal
//

import SwiftUI

struct DiaryPickerView: View {
    @EnvironmentObject var journalViewModel: JournalViewModel
    @Environment(\.dismiss) var dismiss

    let onSelect: (JournalEntry) -> Void

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
                    List {
                        ForEach(journalViewModel.allEntries.prefix(20)) { entry in
                            Button(action: { onSelect(entry) }) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Text(entry.text)
                                        .font(DesignSystem.Fonts.body)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        .lineSpacing(4)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Text(entry.date.formatted(
                                            .dateTime
                                                .year()
                                                .month()
                                                .day()
                                                .weekday(.abbreviated)
                                                .hour(.twoDigits(amPM: .omitted))
                                                .minute(.twoDigits)
                                                .locale(Locale(identifier: "ja_JP"))
                                        ))
                                            .font(DesignSystem.Fonts.caption)
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
                                .modifier(DiaryPickerCardStyle())
                            }
                            .buttonStyle(.plain)
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
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("日記を選択")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
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

// MARK: - Card Style

private struct DiaryPickerCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted.interactive(), in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
                        .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: DesignSystem.Colors.brownDark.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }
}
