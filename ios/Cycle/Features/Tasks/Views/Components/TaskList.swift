//
//  TaskList.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// 1日分のタスク一覧コンポーネント
/// 未完了と完了のセクションに分けて表示
struct TaskList: View {
    let incompleteTasks: [TaskItem]
    let completedTasks: [TaskItem]
    /// 旧アーカイブ機能で保管された完了タスク（チェックの付け外しはできない）
    var archivedCompletedTasks: [TaskItem] = []
    let isReorderMode: Bool
    let onMove: (IndexSet, Int) -> Void
    let onToggleCompletion: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onPreview: (TaskItem) -> Void
    /// 旧アーカイブのタスクを削除
    var onDeleteArchived: (TaskItem) -> Void = { _ in }

    private var allIDs: [UUID] {
        incompleteTasks.map(\.id) + completedTasks.map(\.id)
            + archivedCompletedTasks.map(\.id)
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
                    onPreview: { onPreview(task) }
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
                    onPreview: { onPreview(task) }
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

}
