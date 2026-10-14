//
//  TaskScheduleFields.swift
//  Cycle
//
//  タスクの「日付」「終日」「締切時刻」の入力欄。新規作成と編集で共用する。
//

import SwiftUI

struct TaskScheduleFields: View {
    @Binding var date: Date
    @Binding var isAllDay: Bool
    @Binding var deadlineTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("日付")
                .font(DesignSystem.Fonts.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            VStack(spacing: 0) {
                row(icon: "calendar", title: "日付") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("task_schedule_date")
                }

                divider

                row(icon: "sun.max", title: "終日") {
                    Toggle("終日", isOn: $isAllDay.animation(DesignSystem.Timing.easing))
                        .labelsHidden()
                        .tint(DesignSystem.Colors.accent)
                        .accessibilityIdentifier("task_schedule_all_day")
                }

                if !isAllDay {
                    divider

                    row(icon: "clock", title: "締切") {
                        DatePicker("締切", selection: $deadlineTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityIdentifier("task_schedule_deadline")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .modifier(FormFieldBackground())
            .tint(DesignSystem.Colors.accent)
            .environment(\.locale, Locale(identifier: "ja_JP"))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func row<Control: View>(
        icon: String,
        title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.FontSize.body))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.ComponentSize.iconSize)
            Text(title)
                .font(DesignSystem.Fonts.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Spacer()
            control()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .frame(minHeight: DesignSystem.ComponentSize.inputHeight)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, DesignSystem.Spacing.lg + DesignSystem.ComponentSize.iconSize + DesignSystem.Spacing.md)
    }
}

extension TaskScheduleFields {
    /// 締切時刻の初期値（今の次の「ちょうど」の時刻。例: 14:20 → 15:00）
    static func defaultDeadlineTime(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? now
    }
}
