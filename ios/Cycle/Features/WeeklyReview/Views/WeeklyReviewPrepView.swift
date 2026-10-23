//
//  WeeklyReviewPrepView.swift
//  Cycle
//
//  週のふりかえり（U-03）の開始前画面。
//  今週の日記・完了したタスクを一覧で見せ、チェックしたものだけをコーチに渡す。
//  何も選ばなくても（材料が何もない週でも）始められる。
//

import SwiftUI

struct WeeklyReviewPrepView: View {
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var taskViewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    let week: WeeklyReviewWeek
    /// 「ふりかえりを始める」で、選ばれた材料（なければ nil）を渡す
    let onStart: (String?) -> Void

    /// チェックを外した日記・タスクの ID（初期値はすべてチェック）
    @State private var excludedJournalIds = Set<UUID>()
    @State private var excludedTaskIds = Set<UUID>()

    private var journals: [JournalEntry] {
        journalViewModel.entries
            .filter { $0.deletedAt == nil && week.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    private var completedTasks: [TaskItem] {
        var seen = Set<UUID>()
        return week.days()
            .flatMap { taskViewModel.homeTasks(on: $0) }
            .filter { $0.isCompleted && seen.insert($0.id).inserted }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    introSection
                    journalSection
                    taskSection
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                PrimaryButton("ふりかえりを始める", icon: "leaf") {
                    let material = week.material(
                        journals: journals.filter { !excludedJournalIds.contains($0.id) },
                        completedTasks: completedTasks.filter { !excludedTaskIds.contains($0.id) }
                    )
                    onStart(material)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .accessibilityIdentifier("weekly_review_start_button")
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("今週のふりかえり")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(week.rangeText)
                .font(DesignSystem.Fonts.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("コーチに渡すものを選んでね。チェックを外したものは送られません。何も選ばなくても始められます。")
                .font(DesignSystem.Fonts.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineSpacing(3)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .plainRow()
    }

    private var journalSection: some View {
        Section {
            if journals.isEmpty {
                emptyRow("今週の日記はまだありません")
            } else {
                ForEach(journals) { entry in
                    checkRow(
                        isOn: !excludedJournalIds.contains(entry.id),
                        toggle: { excludedJournalIds.formSymmetricDifference([entry.id]) }
                    ) {
                        Text(entry.text)
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Text(WeeklyReviewWeek.dayText(entry.date))
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        } header: {
            sectionHeader("日記", icon: "leaf", count: journals.count)
        }
    }

    private var taskSection: some View {
        Section {
            if completedTasks.isEmpty {
                emptyRow("今週完了したタスクはまだありません")
            } else {
                ForEach(completedTasks) { task in
                    checkRow(
                        isOn: !excludedTaskIds.contains(task.id),
                        toggle: { excludedTaskIds.formSymmetricDifference([task.id]) }
                    ) {
                        Text(task.title)
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !task.insight.isEmpty {
                            Text("気づき: \(task.insight)")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        } header: {
            sectionHeader("完了したタスク", icon: "checklist", count: completedTasks.count)
        }
    }

    // MARK: - Rows

    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(title)
                .font(DesignSystem.Fonts.label)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("\(count)")
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, 2)
                .background(Capsule().fill(DesignSystem.Colors.accent.opacity(0.10)))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.background)
        .listRowInsets(EdgeInsets())
    }

    private func checkRow<Content: View>(
        isOn: Bool,
        toggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? DesignSystem.Colors.accent : DesignSystem.Colors.greyDark)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    content()
                }
                .opacity(isOn ? 1 : 0.5)
                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .plainRow()
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .plainRow()
    }
}

private extension View {
    /// 背景・区切り線なしのリスト行
    func plainRow() -> some View {
        self
            .listRowInsets(
                EdgeInsets(
                    top: DesignSystem.Spacing.xs,
                    leading: DesignSystem.Spacing.lg,
                    bottom: DesignSystem.Spacing.xs,
                    trailing: DesignSystem.Spacing.lg
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
