//
//  WeekNavigation.swift
//  Cycle
//
//  ジャーナルとタスクリストで共有する「週カレンダー」の日付計算と、
//  WeekCalendarView を使う画面が満たすプロトコル。
//

import Foundation

/// 週カレンダー（WeekCalendarView）で日付を切り替える画面のモデル
@MainActor
protocol WeekCalendarNavigating: ObservableObject {
    /// 選択中の日付
    var selectedDate: Date { get set }
    /// 今週からの週オフセット（0が今週、-1が先週、1が来週）
    var currentWeekOffset: Int { get set }
    /// その日に記録があるか（カレンダーのドット表示に使う）
    func hasRecord(on date: Date) -> Bool
}

enum WeekNavigation {
    /// 指定したオフセットの週の日付配列（日曜始まり・7日分）
    static func days(offset: Int, today: Date = Date()) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1

        let targetDate = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)
        let sunday = calendar.date(from: components) ?? targetDate

        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: sunday)
        }
    }

    /// 指定日が含まれる週の、今週からのオフセット
    static func weekOffset(for date: Date, today: Date = Date()) -> Int {
        guard let targetSunday = days(offset: 0, today: date).first,
              let currentSunday = days(offset: 0, today: today).first else { return 0 }
        let dayDiff = Calendar.current.dateComponents([.day], from: currentSunday, to: targetSunday).day ?? 0
        return Int((Double(dayDiff) / 7).rounded())
    }
}
