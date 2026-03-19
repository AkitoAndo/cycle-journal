//
//  TaskList.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI

/// タスク一覧コンポーネント
/// 未完了と完了のセクションに分けて表示
struct TaskList: View {
    let incompleteTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let isReorderMode: Bool
    let onMove: (IndexSet, Int) -> Void
    let onToggleCompletion: (TaskItem) -> Void
    let onEdit: (TaskItem) -> Void
    let onDelete: (TaskItem) -> Void
    let onPreview: (TaskItem) -> Void
    let onArchive: (TaskItem) -> Void

    var body: some View {
        List {
            // 未完了タスクセクション
            if !incompleteTasks.isEmpty {
                incompleteSection
            }

            // 完了タスクセクション
            if !completedTasks.isEmpty {
                completedSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Sections

    private var incompleteSection: some View {
        Section {
            ForEach(incompleteTasks) { task in
                TaskRow(
                    task: task,
                    isReorderMode: isReorderMode,
                    onToggleCompletion: { onToggleCompletion(task) },
                    onEdit: { onEdit(task) },
                    onDelete: { onDelete(task) },
                    onPreview: { onPreview(task) },
                    onArchive: nil
                )
                .deleteDisabled(true)
                .moveDisabled(!isReorderMode)
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
                    onArchive: { onArchive(task) }
                )
                .padding(.top, index == 0 && !incompleteTasks.isEmpty ? DesignSystem.Spacing.sm : 0)
            }
        }
    }
}
