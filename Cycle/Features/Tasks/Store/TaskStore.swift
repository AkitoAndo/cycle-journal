//
//  TaskStore.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation

enum TaskStore {
    private static let file = "tasks.json"

    static func loadAll() -> [TaskItem] {
        JSONFileStore.load(file, as: [TaskItem].self) ?? []
    }

    static func saveAll(_ tasks: [TaskItem]) {
        JSONFileStore.save(tasks, to: file)
    }
}
