//
//  TaskDeletedView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/03/01.
//

import SwiftUI

/// 最近削除したタスクのビュー
struct TaskDeletedView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewingTask: TaskItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("最近削除した項目")
                .navigationBarTitleDisplayMode(.inline)
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
                        .disabled(vm.deletedTasks.isEmpty)
                    }
                }
                .sheet(item: $previewingTask) { task in
                    TaskPreviewView(task: task)
                }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    @ViewBuilder
    private var content: some View {
        if vm.deletedTasks.isEmpty {
            emptyState
        } else {
            deletedList
        }
    }

    private func deleteAll() {
        for task in vm.deletedTasks {
            vm.permanentlyDeleteTask(task)
        }
    }

    private var emptyState: some View {
        EmptyStateView(icon: "trash", title: "削除した項目はありません")
            .background(DesignSystem.Colors.background)
    }

    private var deletedList: some View {
        List {
            ForEach(vm.deletedTasks) { task in
                TaskDeletedRow(
                    task: task,
                    onRestore: {
                        vm.restoreTask(task)
                    },
                    onPermanentlyDelete: {
                        vm.permanentlyDeleteTask(task)
                    },
                    onPreview: {
                        previewingTask = task
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

struct TaskDeletedRow: View {
    let task: TaskItem
    let onRestore: () -> Void
    let onPermanentlyDelete: () -> Void
    let onPreview: () -> Void

    var body: some View {
        taskContent
            .listRowInsets(rowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                permanentlyDeleteButton
                restoreButton
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
        .tint(.blue)
    }

    private var previewButton: some View {
        Button(action: onPreview) {
            Label("プレビュー", systemImage: "checkmark")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.textSecondary)
    }
}
