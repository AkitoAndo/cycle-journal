//
//  TaskStore.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation

/// タスクの永続化を担当するストア
///
/// JSONFileStoreを使用してタスクをJSONファイルに保存・読み込みします。
enum TaskStore {
    private static let file = "tasks.json"

    /// 全てのタスクを読み込み
    static func loadAll() -> [TaskItem] {
        JSONFileStore.load(file, as: [TaskItem].self) ?? []
    }

    /// 全てのタスクを保存
    static func saveAll(_ tasks: [TaskItem]) {
        JSONFileStore.save(tasks, to: file)
    }
}
