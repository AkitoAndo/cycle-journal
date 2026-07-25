//
//  TaskRow.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/01/25.
//

import SwiftUI
import Pow

/// タスク行のコンポーネント
/// チェックボックス、タイトル、スワイプアクションを含む
struct TaskRow: View {
    let task: TaskItem
    let isReorderMode: Bool
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onArchive: (() -> Void)?

    var body: some View {
        taskContent
            .customListRowStyle()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isReorderMode {
                    deleteButton
                    if task.isCompleted, let archiveAction = onArchive {
                        archiveButton(action: archiveAction)
                    }
                    editButton
                    previewButton
                }
            }
    }

    // MARK: - Task Content

    private var taskContent: some View {
        SurfaceCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                checkboxButton
                taskTitle
                Spacer()
            }
            .padding(.vertical, 2.5)
        }
    }

    private var checkboxButton: some View {
        Button(action: onToggleCompletion) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: DesignSystem.FontSize.title3))
                .foregroundStyle(
                    task.isCompleted
                        ? DesignSystem.Colors.accent
                        : DesignSystem.Colors.textTertiary
                )
        }
        .changeEffect(
            .spray(origin: .center) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .font(.system(size: 12))
            },
            value: task.isCompleted,
            isEnabled: task.isCompleted
        )
        .changeEffect(.feedback(hapticNotification: .success), value: task.isCompleted, isEnabled: task.isCompleted)
    }

    private var taskTitle: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(task.title)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(
                    task.isCompleted
                        ? DesignSystem.Colors.textSecondary
                        : DesignSystem.Colors.textPrimary
                )
            if !task.previewText.isEmpty {
                Text(task.previewText)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(
                        task.isCompleted
                            ? DesignSystem.Colors.textTertiary
                            : DesignSystem.Colors.textSecondary
                    )
                    .lineLimit(1)
            }
        }
    }


    // MARK: - Swipe Actions

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

    private func archiveButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("アーカイブ", systemImage: "archivebox")
                .labelStyle(.iconOnly)
        }
        .tint(.blue)
    }
}
