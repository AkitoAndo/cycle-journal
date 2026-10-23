//
//  RecordRows.swift
//  Cycle
//
//  「記録」タブのリスト行（iOS 17 の inset grouped リストに並べる形）。
//  スワイプ操作は、これまでの日記一覧（JournalEntryRow）・タスク一覧（TaskRow）と同じ。
//

import SwiftUI

// MARK: - 日記の行

struct RecordJournalRow: View {
    let entry: JournalEntry
    var quoteCount: Int = 0
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onQuote: (() -> Void)?
    var onShowQuoteChain: (() -> Void)?

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(entry.text)
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineSpacing(3)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(entry.date.timeHM)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                        if quoteCount > 0 {
                            Label("\(quoteCount)", systemImage: "quote.opening")
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                }
                Spacer(minLength: 0)
                RecordChevron()
                    .padding(.top, 2)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal_entry_\(entry.id.uuidString)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            Button(action: onEdit) {
                Label("編集", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .tint(DesignSystem.Colors.accent)
            if let onQuote {
                Button(action: onQuote) {
                    Label("引用", systemImage: "quote.opening")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.brownLight)
            }
            if quoteCount > 0, let onShowQuoteChain {
                Button(action: onShowQuoteChain) {
                    Label("引用の履歴", systemImage: "link")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - 一歩（タスク）の行

struct RecordStepRow: View {
    let task: TaskItem
    var isReorderMode = false
    /// 旧アーカイブのタスクはチェックの付け外しができない
    var canToggle = true
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            checkbox
            Button(action: onPreview) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.body)
                            .foregroundStyle(task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                            .strikethrough(task.isCompleted, color: DesignSystem.Colors.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !task.previewText.isEmpty {
                            Text(task.previewText)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        if let scheduleLabel {
                            scheduleLabelView(scheduleLabel)
                        }
                    }
                    Spacer(minLength: 0)
                    if !isReorderMode {
                        RecordChevron()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("task_row_\(task.id.uuidString.lowercased())")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isReorderMode {
                Button(role: .destructive, action: onDelete) {
                    Label("削除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.accent)
                Button(action: onPreview) {
                    Label("プレビュー", systemImage: "eye")
                        .labelStyle(.iconOnly)
                }
                .tint(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var checkbox: some View {
        Button(action: onToggleCompletion) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(task.isCompleted ? DesignSystem.Colors.leaf : DesignSystem.Colors.greyDark)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!canToggle)
        .accessibilityLabel(task.isCompleted ? "未完了に戻す" : "完了にする")
        .accessibilityIdentifier("task_checkbox_\(task.id.uuidString.lowercased())")
    }

    /// 締切の表示（例: 「18:00まで」「期限切れ・18:00まで」）。終日で期限内なら表示しない
    private var scheduleLabel: String? {
        let isOverdue = task.isOverdue()
        let timeText = task.deadline.map {
            $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) + "まで"
        }
        switch (isOverdue, timeText) {
        case (true, let time?): return "期限切れ・\(time)"
        case (true, nil): return "期限切れ"
        case (false, let time?): return time
        case (false, nil): return nil
        }
    }

    private func scheduleLabelView(_ text: String) -> some View {
        let isOverdue = task.isOverdue()
        return Label(text, systemImage: isOverdue ? "exclamationmark.circle" : "clock")
            .font(.caption)
            .foregroundStyle(
                isOverdue
                    ? Color(.systemRed)
                    : (task.isCompleted ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textSecondary)
            )
            .accessibilityIdentifier("task_schedule_label_\(task.id.uuidString.lowercased())")
    }
}

// MARK: - 共通部品

/// 行末の「>」
struct RecordChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignSystem.Colors.textTertiary)
    }
}

/// 「記録」タブの見出し（ホームと同じ太字）
struct RecordSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .textCase(nil)
            .padding(.leading, -DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)
    }
}
