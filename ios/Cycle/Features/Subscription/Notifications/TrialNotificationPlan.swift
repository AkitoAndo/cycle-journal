//
//  TrialNotificationPlan.swift
//  CycleJournal
//
//  Issue #37 C-2 決定: 7 日間トライアル中の Day1/3/6/7 通知計画を生成する純粋関数。
//
//  起点は Apple Introductory Offer の purchaseDate(StoreKit2 Transaction)。
//  すべてローカル通知 (UNTimeIntervalNotificationTrigger / UNCalendarNotificationTrigger
//  どちらでもよいが、Scheduler 側で UNTimeInterval を採用)。
//

import Foundation

/// 1 件のトライアル通知 (Scheduler が UNNotificationRequest に変換)
struct TrialNotification: Equatable {
    let day: Int           // 1, 3, 6, 7
    let scheduledAt: Date
    let title: String
    let body: String
    let identifier: String // "trial.day{N}"
}

enum TrialNotificationPlan {
    /// Day1/3/6/7 の通知 4 件を生成する.
    ///
    /// - parameter purchaseDate: Apple Intro Offer の起点 (StoreKit2 `Transaction.purchaseDate`)
    /// - parameter goal: オンボーディングで選択したゴール (Day3 文面のパーソナライズに使う)
    /// - parameter calendar: 時刻計算用カレンダー (TimeZone はユーザーのものを推奨)
    static func generate(
        purchaseDate: Date,
        goal: OnboardingGoal?,
        calendar: Calendar = .current
    ) -> [TrialNotification] {
        return [
            day1Notification(purchaseDate: purchaseDate, calendar: calendar),
            day3Notification(purchaseDate: purchaseDate, goal: goal, calendar: calendar),
            day6Notification(purchaseDate: purchaseDate, calendar: calendar),
            day7Notification(purchaseDate: purchaseDate, calendar: calendar),
        ]
    }

    // MARK: - Day-specific factories

    private static func day1Notification(
        purchaseDate: Date,
        calendar: Calendar
    ) -> TrialNotification {
        return TrialNotification(
            day: 1,
            scheduledAt: nextMorning(after: purchaseDate, hour: 8, minute: 30, calendar: calendar),
            title: "今日の振り返りを 3 分で",
            body: "最初のジャーナルから、自分との対話を始めましょう。",
            identifier: "trial.day1"
        )
    }

    private static func day3Notification(
        purchaseDate: Date,
        goal: OnboardingGoal?,
        calendar: Calendar
    ) -> TrialNotification {
        let scheduledAt = morningOf(
            day: 3,
            from: purchaseDate,
            hour: 8,
            minute: 30,
            calendar: calendar
        )
        return TrialNotification(
            day: 3,
            scheduledAt: scheduledAt,
            title: "AI コーチがあなたを待っています",
            body: day3Body(for: goal),
            identifier: "trial.day3"
        )
    }

    private static func day6Notification(
        purchaseDate: Date,
        calendar: Calendar
    ) -> TrialNotification {
        return TrialNotification(
            day: 6,
            scheduledAt: morningOf(
                day: 6,
                from: purchaseDate,
                hour: 9,
                minute: 0,
                calendar: calendar
            ),
            title: "まもなくトライアル終了",
            body: "明日、年額プランへの自動更新が始まります。"
                + "継続も解約も「設定 → Apple ID → サブスクリプション」から行えます。",
            identifier: "trial.day6"
        )
    }

    private static func day7Notification(
        purchaseDate: Date,
        calendar: Calendar
    ) -> TrialNotification {
        // 課金 2 時間前 (sunk cost 想起 + 不意打ち回避)
        let trialEnd = purchaseDate.addingTimeInterval(7 * 86400)
        let scheduledAt = trialEnd.addingTimeInterval(-2 * 3600)
        return TrialNotification(
            day: 7,
            scheduledAt: scheduledAt,
            title: "プレミアム継続開始",
            body: "今日からプレミアムが継続されます。"
                + "これまでのジャーナルと対話が、あなたの一年を支えます。",
            identifier: "trial.day7"
        )
    }

    // MARK: - Day3 goal-based body

    private static func day3Body(for goal: OnboardingGoal?) -> String {
        switch goal {
        case .selfAwareness:
            return "AI コーチがあなたの自己理解を深めるための問いを準備しています。"
        case .stressManagement:
            return "AI コーチがストレスの源を整理するヒントを準備しています。"
        case .goalAchievement:
            return "AI コーチが目標達成への次の一歩を一緒に考えます。"
        case .dailyHabits:
            return "AI コーチが習慣を続けるためのコツを共有します。"
        case .personalGrowth:
            return "AI コーチがあなたの成長の手応えを一緒に振り返ります。"
        case .none:
            return "AI コーチとの対話で、Day1-2 の気づきを深掘りしませんか。"
        }
    }

    // MARK: - Date helpers

    /// 翌朝の指定時刻 (Day1 で 6h 後より朝のほうが遅ければ朝を採用)
    private static func nextMorning(
        after date: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: date
        )
        components.hour = hour
        components.minute = minute
        components.second = 0
        var morning = calendar.date(from: components) ?? date

        // 購入が既に朝の時刻を過ぎていたら翌日朝に
        if morning <= date.addingTimeInterval(6 * 3600) {
            morning = calendar.date(byAdding: .day, value: 1, to: morning) ?? morning
        }
        return morning
    }

    /// 購入日から N 日後の指定時刻
    private static func morningOf(
        day: Int,
        from purchaseDate: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let target = calendar.date(byAdding: .day, value: day, to: purchaseDate) ?? purchaseDate
        var components = calendar.dateComponents([.year, .month, .day], from: target)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? target
    }
}
