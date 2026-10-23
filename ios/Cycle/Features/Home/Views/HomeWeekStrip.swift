//
//  HomeWeekStrip.swift
//  Cycle
//
//  ホームの1週間の帯。記録した日に葉、今日に丸を出す（月のカレンダーの置き換え）。
//

import SwiftUI

struct HomeWeekStrip: View {
    /// 週の7日間（初日から順）
    let days: [Date]
    /// 記録がある日か
    let hasRecord: (Date) -> Bool

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "ja_JP"))))
                        .font(DesignSystem.Fonts.caption2)
                        .foregroundStyle(calendar.isDateInToday(day) ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                    marker(for: day)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今週の記録: \(days.filter(hasRecord).count)日")
    }

    @ViewBuilder
    private func marker(for day: Date) -> some View {
        let recorded = hasRecord(day)
        ZStack {
            if calendar.isDateInToday(day) {
                Circle().stroke(DesignSystem.Colors.accent, lineWidth: 1.5)
            }
            if recorded {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.leaf)
            } else {
                Circle()
                    .fill(DesignSystem.Colors.grey)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 28, height: 28)
    }
}
