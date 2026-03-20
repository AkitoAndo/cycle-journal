//
//  JournalDeletedView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/03/01.
//

import SwiftUI

/// 最近削除したジャーナルのビュー
struct JournalDeletedView: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("最近削除した項目")
                .navigationBarTitleDisplayMode(.inline)
                .modifier(GlassNavBarModifier())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("全て削除") {
                            deleteAll()
                        }
                        .disabled(vm.deletedEntries.isEmpty)
                    }
                }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    @ViewBuilder
    private var content: some View {
        if vm.deletedEntries.isEmpty {
            emptyState
        } else {
            deletedList
        }
    }

    private func deleteAll() {
        for entry in vm.deletedEntries {
            vm.permanentlyDeleteEntry(entry)
        }
    }

    private var emptyState: some View {
        EmptyStateView(icon: "trash", title: "削除した日記はありません")
            .background(DesignSystem.Colors.background)
    }

    private var deletedList: some View {
        List {
            ForEach(vm.deletedEntries) { entry in
                JournalDeletedRow(
                    entry: entry,
                    onRestore: {
                        vm.restoreEntry(entry)
                    },
                    onPermanentlyDelete: {
                        vm.permanentlyDeleteEntry(entry)
                    }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Deleted Row

struct JournalDeletedRow: View {
    let entry: JournalEntry
    let onRestore: () -> Void
    let onPermanentlyDelete: () -> Void

    var body: some View {
        entryContent
            .customListRowStyle()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                permanentlyDeleteButton
                restoreButton
            }
    }

    private var entryContent: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text(entry.text)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineSpacing(4)
                    .lineLimit(3)

                dateText
            }
        }
    }

    private var dateText: some View {
        Text(entry.date.formatted(.dateTime.year().month().day().hour().minute()))
            .font(DesignSystem.Fonts.caption)
            .foregroundStyle(DesignSystem.Colors.textSecondary)
    }

    private var permanentlyDeleteButton: some View {
        Button(role: .destructive, action: onPermanentlyDelete) {
            Label("完全に削除", systemImage: "trash.fill")
                .labelStyle(.iconOnly)
        }
    }

    private var restoreButton: some View {
        Button(action: onRestore) {
            Label("復元", systemImage: "arrow.uturn.backward")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.accent)
    }
}
