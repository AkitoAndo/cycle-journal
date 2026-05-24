//
//  TrialNotificationPlanTests.swift
//  CycleTests
//
//  Issue #37 C-2: トライアル中の Day1/3/6/7 通知計画(純粋関数)の単体テスト
//

import Foundation
import Testing

@testable import Cycle

struct TrialNotificationPlanTests {
    // 固定 purchaseDate (UTC 2026-01-01 00:00:00)
    private static let purchaseDate = Date(timeIntervalSince1970: 1_767_225_600)
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return c
    }()

    @Test func generatesFourNotifications() {
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        #expect(plan.count == 4)
    }

    @Test func includesDay1Day3Day6Day7() {
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        let days = plan.map(\.day).sorted()
        #expect(days == [1, 3, 6, 7])
    }

    @Test func identifiersAreUniqueAndFollowConvention() {
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        let ids = plan.map(\.identifier)
        #expect(Set(ids).count == ids.count) // unique
        for n in plan {
            #expect(n.identifier == "trial.day\(n.day)")
        }
    }

    @Test func day6BodyIncludesCancellationGuidance() {
        // EU DSA / Digital Fairness Act 対応: 解約導線を併記
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        let day6 = plan.first { $0.day == 6 }
        #expect(day6 != nil)
        #expect(day6!.body.contains("解約") || day6!.body.contains("サブスクリプション"))
    }

    @Test func day3BodyVariesByGoal() {
        let withSelfAwareness = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: .selfAwareness,
            calendar: Self.calendar
        ).first { $0.day == 3 }!

        let withStressManagement = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: .stressManagement,
            calendar: Self.calendar
        ).first { $0.day == 3 }!

        // Goal 別に Day3 文面が変わる (#37 C-2 決定)
        #expect(withSelfAwareness.body != withStressManagement.body)
    }

    @Test func day7ScheduledBeforeAutoCharge() {
        // Day7 通知は課金 2 時間前 (sunk cost 想起) なので
        // purchaseDate + 7 日 より少し早い時刻
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        let day7 = plan.first { $0.day == 7 }!
        let trialEnd = Self.purchaseDate.addingTimeInterval(7 * 86400)
        #expect(day7.scheduledAt < trialEnd)
    }

    @Test func day1ScheduledMorningOrSixHoursAfterPurchase() {
        // Day1 は購入 6h 後 or 翌朝 8:30 (どちらか早い方の妥当範囲)
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        let day1 = plan.first { $0.day == 1 }!
        let elapsed = day1.scheduledAt.timeIntervalSince(Self.purchaseDate)
        // 6h <= elapsed <= 36h の範囲に収まる
        #expect(elapsed >= 6 * 3600)
        #expect(elapsed <= 36 * 3600)
    }

    @Test func futureSchedulesOnly() {
        // すべての通知が purchaseDate より後
        let plan = TrialNotificationPlan.generate(
            purchaseDate: Self.purchaseDate,
            goal: nil,
            calendar: Self.calendar
        )
        for n in plan {
            #expect(n.scheduledAt > Self.purchaseDate)
        }
    }
}
