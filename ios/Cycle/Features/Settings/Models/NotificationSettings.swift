//
//  NotificationSettings.swift
//  Cycle
//

import Foundation

/// 通知設定のデータモデル
///
/// リマインダーとタスク締切通知の設定を保持します。
/// JSONFileStoreで永続化されます。
struct NotificationSettings: Codable {
    /// リマインダー通知が有効かどうか
    var isReminderEnabled: Bool = false

    /// リマインダー時刻（時）
    var reminderHour: Int = 21

    /// リマインダー時刻（分）
    var reminderMinute: Int = 0

    /// タスク締切通知が有効かどうか
    var isTaskDeadlineEnabled: Bool = false

    /// 締切の何分前に通知するか
    var deadlineAlertMinutesBefore: Int = 30
}
