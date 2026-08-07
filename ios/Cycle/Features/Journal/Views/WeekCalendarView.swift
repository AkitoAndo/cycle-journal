//
//  WeekCalendarView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI
import Pow

/// 週単位のカレンダービューコンポーネント
/// 横スワイプで週を切り替え、日付タップで選択可能
struct WeekCalendarView: View {
    @ObservedObject var vm: JournalViewModel
    @Namespace private var selectionNamespace

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
        let isToday = Calendar.current.isDateInToday(date)
        let hasRecord = vm.hasEntries(on: date)

        return VStack(spacing: DesignSystem.Spacing.sm) {
            // 曜日
            Text(["日", "月", "火", "水", "木", "金", "土"][Calendar.current.component(.weekday, from: date) - 1])
                .font(.system(size: DesignSystem.FontSize.caption - 1))
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            // 日付 + 記録ドット
            VStack(spacing: 2) {
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
                    .background {
                        if isSelected {
                            Circle()
                                .fill(DesignSystem.Colors.accent)
                                .matchedGeometryEffect(id: "daySelection", in: selectionNamespace)
                        } else if isToday {
                            // 今日（未選択時）はホームと同じくアクセントの枠線の丸
                            Circle()
                                .stroke(DesignSystem.Colors.accent, lineWidth: 1.5)
                        }
                    }
                    .animation(DesignSystem.Timing.easing, value: isSelected)
                    .changeEffect(.feedbackHapticSelection, value: isSelected, isEnabled: isSelected)

                // 記録のある日はドット（ホームと同じ表現）
                Circle()
                    .fill(hasRecord ? DesignSystem.Colors.accent.opacity(0.6) : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(DesignSystem.Timing.bouncySpring) {
                vm.selectedDate = date
            }
        }
    }
}
