//
//  ScheduleEvent.swift
//  Cycle
//
//  アプリ独自の予定モデル（iOSカレンダー非依存・ローカル保存）
//

import Foundation

/// アプリ内で管理する予定
struct ScheduleEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    /// タイトル
    var title: String
    /// 開始日時
    var startDate: Date
    /// 終了日時
    var endDate: Date
    /// 終日予定か
    var isAllDay: Bool = false
    /// メモ
    var notes: String = ""
    /// 作成日時
    var createdAt: Date = Date()

    /// 時刻表示（終日は「終日」）
    var timeText: String {
        if isAllDay { return "終日" }
        return "\(startDate.timeHM) - \(endDate.timeHM)"
    }
}
