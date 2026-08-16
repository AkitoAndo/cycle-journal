//
//  CoachSessionDeletionStore.swift
//  Cycle
//
//  会話削除をオフライン後も再送し、サーバー履歴からの復活を防ぐ。
//

import Foundation

enum CoachSessionDeletionStore {
    private static let file = "coach_deleted_session_ids.json"

    static func load() -> Set<String> {
        Set(JSONFileStore.load(file, as: [String].self) ?? [])
    }

    static func add(_ serverID: String) {
        var ids = load()
        ids.insert(serverID)
        save(ids)
    }

    static func remove(_ serverID: String) {
        var ids = load()
        ids.remove(serverID)
        save(ids)
    }

    private static func save(_ ids: Set<String>) {
        JSONFileStore.save(ids.sorted(), to: file)
    }
}
