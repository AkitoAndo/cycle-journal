//
//  NotificationSettingsStore.swift
//  Cycle
//

import Foundation

/// 通知設定の永続化を担当するストア
///
/// JSONFileStoreを使用して通知設定をJSONファイルに保存・読み込みします。
enum NotificationSettingsStore {
    private static let file = "notification_settings.json"

    /// 通知設定を読み込み
    static func load() -> NotificationSettings {
        JSONFileStore.load(file, as: NotificationSettings.self) ?? NotificationSettings()
    }

    /// 通知設定を保存
    static func save(_ settings: NotificationSettings) {
        JSONFileStore.save(settings, to: file)
    }
}
