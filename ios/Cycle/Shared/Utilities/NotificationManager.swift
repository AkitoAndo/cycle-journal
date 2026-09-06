//
//  NotificationManager.swift
//  Cycle
//

import Foundation
import UserNotifications

/// 通知管理のシングルトン
///
/// UNUserNotificationCenterを使用して、
/// デイリーリマインダーのスケジューリングを管理します。
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// 通知権限をリクエスト
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// 現在の通知権限ステータスを取得
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Daily Reminder

    /// デイリーリマインダーをスケジュール
    /// - Parameter time: リマインダー時刻（時・分のみ使用）
    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Treow"
        content.body = "今日のふりかえりを書きましょう"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// デイリーリマインダーをキャンセル
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }
}
