//
//  WeekCalendarView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// 週単位のカレンダービューコンポーネント
/// 横スワイプで週を切り替え、日付タップで選択可能
struct WeekCalendarView: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        TabView(selection: $vm.currentWeekOffset) {
            ForEach(-52...52, id: \.self) { weekOffset in
                weekView(for: weekOffset)
                    .tag(weekOffset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: DesignSystem.ComponentSize.weekStripHeight)
        .onChange(of: vm.currentWeekOffset) {
            vm.updateSelectedDateForCurrentWeek()
        }
    }

    /// 1週間分の日付を表示
    private func weekView(for weekOffset: Int) -> some View {
        let week = vm.getWeekDays(offset: weekOffset)

        return HStack(spacing: 0) {
            ForEach(week, id: \.self) { date in
                dayCell(for: date)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.mlg)
    }

    /// 個別の日付セル
    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
        let hasEntries = vm.hasEntries(on: date)

        return VStack(spacing: DesignSystem.Spacing.sm) {
            // 曜日
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: DesignSystem.FontSize.caption - 1))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .textCase(.uppercase)

            // 日付
            Text(date, format: .dateTime.day())
                .font(.system(
                    size: DesignSystem.FontSize.headline,
                    weight: isSelected ? .semibold : .regular
                ))
                .foregroundStyle(
                    isSelected ? DesignSystem.Colors.background : DesignSystem.Colors.textPrimary
                )
                .frame(
                    width: DesignSystem.ComponentSize.dateCircle,
                    height: DesignSystem.ComponentSize.dateCircle
                )
                .background(
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                )
                .animation(DesignSystem.Timing.easing, value: isSelected)

            // エントリ存在インジケーター
            Circle()
                .fill(hasEntries ? DesignSystem.Colors.accent : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DesignSystem.Timing.easing) {
                vm.selectedDate = date
            }
        }
    }
}
