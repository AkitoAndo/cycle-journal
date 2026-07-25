//
//  TaskArchiveView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/28.
//

import SwiftUI

/// タスクアーカイブのメインビュー
/// 日付ごとに完了したタスクを表示
struct TaskArchiveView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewingTask: TaskItem?
    @State private var editingTask: TaskItem?
    @State private var searchText = ""

    /// 検索語で絞り込んだアーカイブ（該当タスクを含む日のみ残す）
    private var filteredArchives: [TaskArchive] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.archives }
        return vm.archives.compactMap { archive in
            let matched = archive.completedTasks.filter { $0.matches(query) }
            guard !matched.isEmpty else { return nil }
            var copy = archive
            copy.completedTasks = matched
            return copy
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ジャーナル検索と同じ形式のワード検索バー
                searchBar
                content
            }
                // 背景はコンテナ側に一色で敷く（List に敷くとわずかに暗く描画されるため）
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.background)
                .navigationTitle("アーカイブ")
                .navigationBarTitleDisplayMode(.inline)
                .modifier(GlassNavBarModifier())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
                .sheet(item: $previewingTask) { task in
                    TaskPreviewView(task: task)
                }
                .sheet(item: $editingTask) { task in
                    TaskEditView(vm: vm, task: task)
                }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    // ジャーナル検索と同じ見た目のワード検索バー
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            TextField("ワードで検索", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .tint(DesignSystem.Colors.accent)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .modifier(ArchiveSearchBarStyle())
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        if vm.archives.isEmpty {
            emptyState
        } else if filteredArchives.isEmpty {
            noResultState
        } else {
            archiveList
        }
    }

    private var emptyState: some View {
        EmptyStateView(icon: "archivebox", title: "アーカイブはまだありません")
    }

    private var noResultState: some View {
        EmptyStateView(icon: "magnifyingglass", title: "「\(searchText)」に一致するタスクはありません")
    }

    private var archiveList: some View {
        List {
            ForEach(filteredArchives) { archive in
                Section {
                    ForEach(archive.completedTasks) { task in
                        TaskArchiveRow(
                            task: task,
                            onEdit: {
                                editingTask = task
                            },
                            onDelete: {
                                vm.deleteArchivedTask(task)
                            },
                            onPreview: {
                                previewingTask = task
                            }
                        )
                    }
                } header: {
                    Text(archive.date.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        // 見出し上の余白を詰める
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.xs,
                            trailing: DesignSystem.Spacing.lg
                        ))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Search Bar Style（ジャーナル検索と同じ）

private struct ArchiveSearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted, in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md))
        }
    }
}

// MARK: - Archive Row

struct TaskArchiveRow: View {
    let task: TaskItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void

    var body: some View {
        taskContent
            .customListRowStyle()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteButton
                editButton
                previewButton
            }
    }

    private var taskContent: some View {
        SurfaceCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                taskTitle
                Spacer()
            }
        }
    }

    private var taskTitle: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(task.title)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            if !task.previewText.isEmpty {
                Text(task.previewText)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("削除", systemImage: "trash")
                .labelStyle(.iconOnly)
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Label("編集", systemImage: "pencil")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.accent)
    }

    private var previewButton: some View {
        Button(action: onPreview) {
            Label("プレビュー", systemImage: "checkmark")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.textSecondary)
    }
}
