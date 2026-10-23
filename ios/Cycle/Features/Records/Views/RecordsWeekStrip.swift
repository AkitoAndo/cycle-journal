//
//  RecordsWeekStrip.swift
//  Cycle
//
//  「記録」タブの1週間の帯。横スワイプで週を切り替え、日付をタップして選ぶ。
//  見た目はホームの帯（HomeWeekStrip）と同じ iOS 17 の形。週は日曜始まり（WeekNavigation に合わせる）。
//

import SwiftUI

struct RecordsWeekStrip: View {
    @Binding var selectedDate: Date
    @Binding var weekOffset: Int
    /// 記録がある日か
    let hasRecord: (Date) -> Bool

    private var calendar: Calendar { .current }

    /// 選んだ日の丸の上の文字色（ライト/ダークで同じ見た目にするため固定色）
    private static let selectedForeground = Color(red: 0.99, green: 0.97, blue: 0.93)

    var body: some View {
        TabView(selection: $weekOffset) {
            ForEach(-52...52, id: \.self) { offset in
                weekView(WeekNavigation.days(offset: offset))
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 66)
        .onChange(of: weekOffset) { _, newOffset in
            moveSelection(toWeek: newOffset)
        }
    }

    /// スワイプで週が変わったら、同じ曜日の日を選ぶ
    private func moveSelection(toWeek offset: Int) {
        let week = WeekNavigation.days(offset: offset)
        guard !week.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else { return }
        let weekday = calendar.component(.weekday, from: selectedDate)
        if let sameWeekday = week.first(where: { calendar.component(.weekday, from: $0) == weekday }) {
            selectedDate = sameWeekday
        } else if let first = week.first {
            selectedDate = first
        }
    }

    private func weekView(_ days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let recorded = hasRecord(day)
        let isFuture = day > Date() && !isToday

        return Button {
            withAnimation(DesignSystem.Timing.spring) {
                selectedDate = day
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs + 2) {
                Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "ja_JP"))))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isToday ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isSelected || isToday ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(
                        isSelected ? Self.selectedForeground
                            : isToday ? DesignSystem.Colors.accent
                            : isFuture ? DesignSystem.Colors.textTertiary
                            : DesignSystem.Colors.textPrimary
                    )
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(
                            isSelected ? DesignSystem.Colors.accent
                                : recorded ? DesignSystem.Colors.leaf.opacity(0.22)
                                : Color.clear
                        )
                    )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("records_day_\(calendar.component(.day, from: day))")
    }
}
