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
    let onSkip: (() -> Void)?
    let isExpanded: Bool
    let onToggleExpansion: () -> Void

    init(
        task: TaskItem,
        isReorderMode: Bool,
        onToggleCompletion: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onArchive: (() -> Void)?,
        onSkip: (() -> Void)? = nil,
        isExpanded: Bool = false,
        onToggleExpansion: @escaping () -> Void = {}
    ) {
        self.task = task
        self.isReorderMode = isReorderMode
        self.onToggleCompletion = onToggleCompletion
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPreview = onPreview
        self.onArchive = onArchive
        self.onSkip = onSkip
        self.isExpanded = isExpanded
        self.onToggleExpansion = onToggleExpansion
    }

    var body: some View {
        taskContent
            .customListRowStyle()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isReorderMode {
                    deleteButton
                    if task.isCompleted, let archiveAction = onArchive {
                        archiveButton(action: archiveAction)
                    }
                    if !task.isCompleted, let skipAction = onSkip {
                        skipButton(action: skipAction)
                    }
                    editButton
                    previewButton
                }
            }
    }

    // MARK: - Task Content

    private var taskContent: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    checkboxButton
                    taskTitle
                    Spacer()
                    if hasReflectionContent && !isReorderMode {
                        expansionButton
                    }
                }
                .padding(.vertical, 2.5)

                if isExpanded && hasReflectionContent {
                    Divider()
                    reflectionDetails
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var hasReflectionContent: Bool {
        !task.intent.isEmpty || !task.fact.isEmpty || !task.insight.isEmpty || !task.nextAction.isEmpty
    }

    private var stableAccessibilityID: String {
        task.id.uuidString.lowercased()
    }

    private var expansionButton: some View {
        Button(action: onToggleExpansion) {
            Image(systemName: "chevron.down")
                .font(.system(size: DesignSystem.FontSize.caption, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "詳細を閉じる" : "詳細を開く")
        .accessibilityIdentifier("task_expand_\(stableAccessibilityID)")
    }

    private var reflectionDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            reflectionField(title: "事前の意図", value: task.intent)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("事後の振り返り")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)

                reflectionField(title: "事実", value: task.fact)
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    reflectionField(title: "気づき", value: task.insight)
                    reflectionField(title: "次の一手", value: task.nextAction)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task_details_\(stableAccessibilityID)")
    }

    private func reflectionField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            Text(value.isEmpty ? "未入力" : value)
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(
                    value.isEmpty
                        ? DesignSystem.Colors.textTertiary
                        : DesignSystem.Colors.textPrimary
                )
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.background.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(task.isCompleted ? "未完了に戻す" : "完了にする")
        .accessibilityIdentifier("task_completion_\(stableAccessibilityID)")
        .buttonStyle(.plain)
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

    private func skipButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("見送る", systemImage: "archivebox")
                .labelStyle(.iconOnly)
        }
        .tint(DesignSystem.Colors.accent)
        .accessibilityIdentifier("task_skip_\(stableAccessibilityID)")
    }
}
