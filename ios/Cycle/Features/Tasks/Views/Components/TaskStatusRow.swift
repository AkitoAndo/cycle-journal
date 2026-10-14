//
//  TaskStatusRow.swift
//  Cycle
//
//  状態バッジ（未完了・完了）付きのタスク行。
//  日付別一覧の「旧アーカイブの完了タスク」と、検索結果で使う。
//  （旧 TaskArchiveView 内の TaskArchiveRow を切り出したもの）
//

import SwiftUI

struct TaskStatusRow: View {
    enum Status {
        case incomplete
        case completed

        var label: String {
            switch self {
            case .incomplete: "未完了"
            case .completed: "完了"
            }
        }

        var color: Color {
            switch self {
            case .completed: DesignSystem.Colors.accent
            case .incomplete: DesignSystem.Colors.textSecondary
            }
        }
    }

    let task: TaskItem
    let status: Status
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onPreview: (() -> Void)? = nil

    var body: some View {
        taskContent
            .customListRowStyle()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let onDelete {
                    deleteButton(action: onDelete)
                }
                if let onEdit {
                    editButton(action: onEdit)
                }
                if let onPreview {
                    previewButton(action: onPreview)
                }
            }
    }

    private var taskContent: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                taskTitle
                Spacer()
                statusBadge
            }
        }
        .accessibilityIdentifier("task_status_row_\(task.id.uuidString.lowercased())")
    }

    private var statusBadge: some View {
        Text(status.label)
            .font(DesignSystem.Fonts.caption2.weight(.semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityIdentifier("task_status_\(task.id.uuidString.lowercased())")
    }

    private var taskTitle: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(task.title)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(
                    status == .incomplete ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary
                )
            if !task.previewText.isEmpty {
                Text(task.previewText)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Swipe Actions

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("削除", systemImage: "trash")
                .labelStyle(.iconOnly)
        }
    }

    private func editButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("編集", systemImage: "pencil")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.accent)
    }

    private func previewButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("プレビュー", systemImage: "checkmark")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.textSecondary)
    }

}
