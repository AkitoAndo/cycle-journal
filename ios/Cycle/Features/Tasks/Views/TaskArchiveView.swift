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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("アーカイブ")
                .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var content: some View {
        if vm.archives.isEmpty {
            emptyState
        } else {
            archiveList
        }
    }

    private var emptyState: some View {
        EmptyStateView(icon: "archivebox", title: "アーカイブはまだありません", subtitle: "完了したタスクをアーカイブするとここに表示されます")
            .background(DesignSystem.Colors.background)
    }

    private var archiveList: some View {
        List {
            ForEach(vm.archives) { archive in
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
                    Text(archive.date.formatted(.dateTime.year().month().day().weekday(.wide)))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
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
            .listRowInsets(rowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteButton
                editButton
                previewButton
            }
    }

    private var taskContent: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            taskTitle
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
        .overlay(borderOverlay)
        .shadow(
            color: DesignSystem.Colors.brownDark.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    private var taskTitle: some View {
        Text(task.title)
            .font(DesignSystem.Fonts.body)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous)
            .stroke(DesignSystem.Colors.grey.opacity(0.6), lineWidth: 0.5)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: DesignSystem.Spacing.xs,
            leading: DesignSystem.Spacing.lg,
            bottom: DesignSystem.Spacing.xs,
            trailing: DesignSystem.Spacing.lg
        )
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
