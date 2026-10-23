//
//  HomeWeekStrip.swift
//  Cycle
//
//  ホームの1週間の帯（月のカレンダーの置き換え）。曜日と日付を出し、
//  記録した日は葉の色の丸、今日は茶色の丸で示す。
//

import SwiftUI

struct HomeWeekStrip: View {
    /// 週の7日間（初日から順）
    let days: [Date]
    /// 記録がある日か
    let hasRecord: (Date) -> Bool

    private var calendar: Calendar { .current }

    /// 今日の丸の上の文字色（ライト/ダークで同じ見た目にするため固定色）
    private static let todayForeground = Color(red: 0.99, green: 0.97, blue: 0.93)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: DesignSystem.Spacing.xs + 2) {
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "ja_JP"))))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(calendar.isDateInToday(day) ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    dayCircle(for: day)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今週の記録: \(days.filter(hasRecord).count)日")
    }

    private func dayCircle(for day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let recorded = hasRecord(day)
        let isFuture = day > Date() && !isToday
        return Text("\(calendar.component(.day, from: day))")
            .font(.subheadline.weight(isToday ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(
                isToday ? Self.todayForeground
                    : isFuture ? DesignSystem.Colors.textTertiary
                    : DesignSystem.Colors.textPrimary
            )
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(
                    isToday ? DesignSystem.Colors.accent
                        : recorded ? DesignSystem.Colors.leaf.opacity(0.22)
                        : Color.clear
                )
            )
            .overlay(alignment: .bottomTrailing) {
                // 今日も記録した日は、茶色の丸に小さな葉を添える
                if isToday && recorded {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.leaf)
                        .padding(3)
                        .background(Circle().fill(DesignSystem.Colors.surface))
                        .offset(x: 4, y: 4)
                }
            }
    }
}
