//
//  TaskList.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// 1日分のタスク一覧コンポーネント
/// 未完了・完了・見送りのセクションに分けて表示
struct TaskList: View {
    let incompleteTasks: [TaskItem]
    let completedTasks: [TaskItem]
    /// 旧アーカイブ機能で保管された完了タスク（チェックの付け外しはできない）
    var archivedCompletedTasks: [TaskItem] = []
    /// その日に見送ったタスク
    var skippedItems: [SkippedTaskArchiveItem] = []
    let isReorderMode: Bool
    let onMove: (IndexSet, Int) -> Void
    let onToggleCompletion: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onPreview: (TaskItem) -> Void
    let onSkip: (TaskItem) -> Void
    /// 旧アーカイブ・見送りのタスクを削除
    var onDeleteArchived: (TaskItem) -> Void = { _ in }
    /// 見送ったタスクを未完了に戻す
    var onResume: (SkippedTaskArchiveItem) -> Void = { _ in }

    private var allIDs: [UUID] {
        incompleteTasks.map(\.id) + completedTasks.map(\.id)
            + archivedCompletedTasks.map(\.id) + skippedItems.map(\.id)
    }

    var body: some View {
        List {
            // 未完了タスクセクション
            if !incompleteTasks.isEmpty {
                incompleteSection
            }

            // 完了タスクセクション
            if !completedTasks.isEmpty || !archivedCompletedTasks.isEmpty {
                completedSection
            }

            // 見送ったタスクセクション
            if !skippedItems.isEmpty {
                skippedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, DesignSystem.Spacing.md, for: .scrollContent)
        // 末尾の行が右下の＋ボタン（56pt + 下余白24pt）に隠れないよう余白を空ける
        .contentMargins(.bottom, 56 + DesignSystem.Spacing.xxl * 2, for: .scrollContent)
        .animation(DesignSystem.Timing.spring, value: allIDs)
    }

    // MARK: - Sections

    private var incompleteSection: some View {
        Section {
            ForEach(Array(incompleteTasks.enumerated()), id: \.element.id) { index, task in
                TaskRow(
                    task: task,
                    isReorderMode: isReorderMode,
                    onToggleCompletion: { onToggleCompletion(task) },
                    onEdit: { onEdit(task) },
                    onDelete: { onDelete(task) },
                    onPreview: { onPreview(task) },
                    onSkip: { onSkip(task) }
                )
                .deleteDisabled(true)
                .moveDisabled(!isReorderMode)
                .staggeredAppear(index: index, group: "task_list")
            }
            .onMove { source, destination in
                if isReorderMode {
                    onMove(source, destination)
                }
            }
        }
    }

    private var completedSection: some View {
        Section {
            ForEach(Array(completedTasks.enumerated()), id: \.element.id) { index, task in
                TaskRow(
                    task: task,
                    isReorderMode: isReorderMode,
                    onToggleCompletion: { onToggleCompletion(task) },
                    onEdit: { onEdit(task) },
                    onDelete: { onDelete(task) },
                    onPreview: { onPreview(task) },
                    onSkip: nil
                )
                .padding(.top, index == 0 && !incompleteTasks.isEmpty ? DesignSystem.Spacing.sm : 0)
            }

            ForEach(archivedCompletedTasks) { task in
                TaskStatusRow(
                    task: task,
                    status: .completed,
                    onEdit: { onEdit(task) },
                    onDelete: { onDeleteArchived(task) },
                    onPreview: { onPreview(task) }
                )
            }
        }
    }

    private var skippedSection: some View {
        Section {
            ForEach(skippedItems) { item in
                TaskStatusRow(
                    task: item.task,
                    status: .skipped,
                    reason: item.reason,
                    onEdit: { onEdit(item.task) },
                    onDelete: { onDeleteArchived(item.task) },
                    onPreview: { onPreview(item.task) },
                    onResume: { onResume(item) }
                )
            }
        } header: {
            Text("見送ったタスク")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .listRowInsets(EdgeInsets(
                    top: DesignSystem.Spacing.md,
                    leading: DesignSystem.Spacing.lg,
                    bottom: DesignSystem.Spacing.xs,
                    trailing: DesignSystem.Spacing.lg
                ))
        }
    }
}
