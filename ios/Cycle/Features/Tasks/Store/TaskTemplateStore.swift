//
//  TaskTemplateStore.swift
//  Cycle
//
//  タスクテンプレートの永続化を担当するストア（TaskStore と同じ JSON ファイル方式）
//

import Foundation

enum TaskTemplateStore {
    private static let file = "task_templates.json"

    /// 全てのテンプレートを読み込み
    static func loadAll() -> [TaskTemplate] {
        JSONFileStore.load(file, as: [TaskTemplate].self) ?? []
    }

    /// 全てのテンプレートを保存
    static func saveAll(_ templates: [TaskTemplate]) {
        JSONFileStore.save(templates, to: file)
    }
}
