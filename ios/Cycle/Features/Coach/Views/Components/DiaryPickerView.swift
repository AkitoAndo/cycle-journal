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
            List {
                ForEach(journalViewModel.allEntries.prefix(20)) { entry in
                    Button(action: { onSelect(entry) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: entry.date))
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(.secondary)

                            Text(entry.text)
                                .font(DesignSystem.Fonts.body)
                                .lineLimit(2)
                                .foregroundColor(.primary)

                            if !entry.tags.isEmpty {
                                HStack {
                                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                        TagChip(text: tag)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("日記を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}
