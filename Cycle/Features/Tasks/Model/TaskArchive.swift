//
//  TaskArchive.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/28.
//

import Foundation

/// 日付ごとのタスクアーカイブ
///
/// 特定の日に完了したタスクを保管するモデル
struct TaskArchive: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// アーカイブ日付（その日の0時）
    var date: Date

    /// 完了したタスクのリスト
    var completedTasks: [TaskItem]

    /// 作成日時
    var createdAt: Date = Date()

    /// 日付の開始時刻（0時）を取得
    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// 今日の0時を取得
    static var todayStart: Date {
        startOfDay(for: Date())
    }
}
