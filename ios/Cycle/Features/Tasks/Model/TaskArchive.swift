//
//  TaskArchive.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/28.
//

import Foundation

/// 見送ったタスクと、そのときに残した任意の理由
struct SkippedTaskArchiveItem: Identifiable, Codable, Hashable {
    var task: TaskItem
    var reason: String
    var skippedAt: Date

    var id: UUID { task.id }
}

/// 日付ごとのタスクアーカイブ
///
/// 特定の日に完了または見送ったタスクを保管するモデル
struct TaskArchive: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// アーカイブ日付（その日の0時）
    var date: Date

    /// 完了したタスクのリスト
    var completedTasks: [TaskItem]

    /// 未完了のまま見送ったタスクのリスト
    var skippedTasks: [SkippedTaskArchiveItem]

    /// 作成日時
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        date: Date,
        completedTasks: [TaskItem],
        skippedTasks: [SkippedTaskArchiveItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.completedTasks = completedTasks
        self.skippedTasks = skippedTasks
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case completedTasks
        case skippedTasks
        case createdAt
    }

    /// `skippedTasks` が存在しない旧形式のJSONも引き続き読み込めるようにする。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        completedTasks = try container.decodeIfPresent([TaskItem].self, forKey: .completedTasks) ?? []
        skippedTasks = try container.decodeIfPresent([SkippedTaskArchiveItem].self, forKey: .skippedTasks) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var isEmpty: Bool {
        completedTasks.isEmpty && skippedTasks.isEmpty
    }

    var allTasks: [TaskItem] {
        completedTasks + skippedTasks.map(\.task)
    }

    /// 日付の開始時刻（0時）を取得
    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// 今日の0時を取得
    static var todayStart: Date {
        startOfDay(for: Date())
    }
}
