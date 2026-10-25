//
//  WeeklyReviewWeekTests.swift
//  CycleTests
//
//  週のふりかえり（U-03）の週の範囲と、コーチに渡す材料の組み立て
//

import Testing
import Foundation
@testable import Cycle

struct WeeklyReviewWeekTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func weekRunsMondayToSundayWhenReviewDayIsSunday() {
        // 2026-10-23 は金曜
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        #expect(calendar.isDate(week.start, inSameDayAs: date(10, 19)))
        #expect(calendar.isDate(week.reviewDay, inSameDayAs: date(10, 25)))
        #expect(week.days(calendar: calendar).count == 7)
    }

    @Test func reviewDayBelongsToItsOwnWeek() {
        // 日曜（ふりかえり日）当日はその週の最終日。翌月曜からは次の週
        let sunday = WeeklyReviewWeek(containing: date(10, 25, hour: 21), calendar: calendar)
        #expect(calendar.isDate(sunday.start, inSameDayAs: date(10, 19)))
        #expect(sunday.isReviewDay(date(10, 25, hour: 21), calendar: calendar))

        let monday = WeeklyReviewWeek(containing: date(10, 26), calendar: calendar)
        #expect(calendar.isDate(monday.start, inSameDayAs: date(10, 26)))
        #expect(!monday.isReviewDay(date(10, 26), calendar: calendar))
    }

    @Test func containsOnlyDaysInTheWeek() {
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        #expect(week.contains(date(10, 19, hour: 0), calendar: calendar))
        #expect(week.contains(date(10, 25, hour: 23), calendar: calendar))
        #expect(!week.contains(date(10, 18, hour: 23), calendar: calendar))
        #expect(!week.contains(date(10, 26, hour: 0), calendar: calendar))
    }

    @Test func otherReviewWeekdayShiftsTheWeek() {
        // ふりかえり日を土曜（7）にすると、日〜土の週になる
        let week = WeeklyReviewWeek(containing: date(10, 23), reviewWeekday: 7, calendar: calendar)
        #expect(calendar.isDate(week.start, inSameDayAs: date(10, 18)))
        #expect(calendar.isDate(week.reviewDay, inSameDayAs: date(10, 24)))
    }

    @Test func nextWeekStartIsTheDayAfterReviewDay() {
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        #expect(calendar.isDate(week.nextWeekStart(calendar: calendar), inSameDayAs: date(10, 26)))
    }

    @Test func materialIsNilWhenNothingSelected() {
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        #expect(week.material(journals: [], completedTasks: []) == nil)
    }

    @Test func materialListsJournalsInDateOrderAndTasksWithInsight() throws {
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        let later = JournalEntry(date: date(10, 22), text: "後の日記")
        let earlier = JournalEntry(date: date(10, 20), text: "前の日記")
        var withInsight = TaskItem(title: "週報を書く")
        withInsight.insight = "  早めに書くと楽 "
        let withoutInsight = TaskItem(title: "ジムに行く")

        let material = week.material(journals: [later, earlier], completedTasks: [withInsight, withoutInsight])

        let text = try #require(material)
        #expect(text.contains("【日記】"))
        #expect(text.contains("【完了したタスク】"))
        #expect(text.range(of: "前の日記")!.lowerBound < text.range(of: "後の日記")!.lowerBound)
        #expect(text.contains("・週報を書く（気づき: 早めに書くと楽）"))
        #expect(text.contains("・ジムに行く\n") || text.hasSuffix("・ジムに行く"))
    }

    @Test func materialOmitsEmptySection() {
        let week = WeeklyReviewWeek(containing: date(10, 23), calendar: calendar)
        let material = week.material(journals: [JournalEntry(date: date(10, 21), text: "日記だけ")], completedTasks: [])
        #expect(material?.contains("【完了したタスク】") == false)
    }
}
