//
//  TrialNotificationScheduler.swift
//  CycleJournal
//
//  Issue #37 C-2: TrialNotificationPlan で生成した通知を
//  UNUserNotificationCenter にローカル通知として登録する。
//
//  - 解約検知時は cancelAllTrialNotifications() で予約取り消し
//    (ASSN V2 DID_CHANGE_RENEWAL_STATUS を受けたらサーバから silent push、
//     端末側で本 API を呼ぶ運用を想定)
//

import Foundation
import UserNotifications

@MainActor
final class TrialNotificationScheduler {
    static let shared = TrialNotificationScheduler()

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// purchaseDate を起点に Day1/3/6/7 通知をローカルでスケジュール.
    ///
    /// 既存のトライアル通知は全てキャンセルしてから再登録 (購入再開や goal 変更後の更新用)。
    func scheduleTrialNotifications(
        purchaseDate: Date,
        goal: OnboardingGoal?,
        now: Date = Date()
    ) async {
        cancelAllTrialNotifications()

        let plan = TrialNotificationPlan.generate(purchaseDate: purchaseDate, goal: goal)
        for notification in plan {
            let interval = notification.scheduledAt.timeIntervalSince(now)
            // 既に過ぎている、または非常に直近(60s 未満)の通知はスキップ
            guard interval >= 60 else { continue }

            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notification.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// trial.day1〜day7 の予約通知を全て取り消す.
    ///
    /// 解約・refund・期限切れ検知時に呼ぶ。
    func cancelAllTrialNotifications() {
        let identifiers = (1...7).map { "trial.day\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
