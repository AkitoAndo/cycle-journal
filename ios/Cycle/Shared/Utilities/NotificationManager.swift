//
//  NotificationManager.swift
//  Cycle
//

import Foundation
import UserNotifications

/// 通知管理のシングルトン
///
/// UNUserNotificationCenterを使用して、
/// デイリーリマインダーとタスク締切通知のスケジューリングを管理します。
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
        content.title = "CycleJournal"
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

    // MARK: - Task Deadline

    /// タスク締切通知をスケジュール
    /// - Parameters:
    ///   - taskId: タスクのUUID
    ///   - title: タスクのタイトル
    ///   - dueDate: 締切日時
    ///   - minutesBefore: 何分前に通知するか
    func scheduleTaskDeadlineNotification(taskId: UUID, title: String, dueDate: Date, minutesBefore: Int) {
        let content = UNMutableNotificationContent()
        content.title = "タスク締切通知"
        content.body = "「\(title)」の締切が\(minutesBefore)分後です"
        content.sound = .default

        let notifyDate = dueDate.addingTimeInterval(-Double(minutesBefore * 60))
        guard notifyDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notifyDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task_deadline_\(taskId.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    /// タスク締切通知をキャンセル
    /// - Parameter taskId: タスクのUUID
    func cancelTaskDeadlineNotification(taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["task_deadline_\(taskId.uuidString)"])
    }
}
