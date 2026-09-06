//
//  TaskSyncMutationStore.swift
//  Cycle
//
//  オフラインや一時障害をまたいでタスク同期を再送する永続Outbox。
//

import Foundation

struct TaskSyncMutation: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case upsert
        case delete
    }

    let id: UUID
    let localTaskID: UUID
    let kind: Kind
    let serverID: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        localTaskID: UUID,
        kind: Kind,
        serverID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localTaskID = localTaskID
        self.kind = kind
        self.serverID = serverID
        self.createdAt = createdAt
    }
}

enum TaskSyncMutationStore {
    private static let file = "task_sync_mutations.json"

    static func loadAll() -> [TaskSyncMutation] {
        JSONFileStore.load(file, as: [TaskSyncMutation].self) ?? []
    }

    static func enqueueUpsert(localTaskID: UUID) {
        save(applyingUpsert(to: loadAll(), localTaskID: localTaskID))
    }

    static func enqueueDelete(localTaskID: UUID, serverID: String?) {
        save(
            applyingDelete(
                to: loadAll(),
                localTaskID: localTaskID,
                serverID: serverID
            )
        )
    }

    static func applyingUpsert(
        to existing: [TaskSyncMutation],
        localTaskID: UUID
    ) -> [TaskSyncMutation] {
        var mutations = existing
        mutations.removeAll { $0.localTaskID == localTaskID }
        mutations.append(.init(localTaskID: localTaskID, kind: .upsert))
        return mutations
    }

    static func applyingDelete(
        to existing: [TaskSyncMutation],
        localTaskID: UUID,
        serverID: String?
    ) -> [TaskSyncMutation] {
        var mutations = existing
        mutations.removeAll { $0.localTaskID == localTaskID }
        if let serverID {
            mutations.append(
                .init(localTaskID: localTaskID, kind: .delete, serverID: serverID)
            )
        }
        return mutations
    }

    static func remove(id: UUID) {
        var mutations = loadAll()
        mutations.removeAll { $0.id == id }
        save(mutations)
    }

    static func removeAll() {
        save([])
    }

    static func pendingDeletedServerIDs() -> Set<String> {
        Set(loadAll().compactMap { mutation in
            mutation.kind == .delete ? mutation.serverID : nil
        })
    }

    static func pendingUpsertLocalIDs() -> Set<UUID> {
        Set(loadAll().compactMap { mutation in
            mutation.kind == .upsert ? mutation.localTaskID : nil
        })
    }

    private static func save(_ mutations: [TaskSyncMutation]) {
        JSONFileStore.save(mutations.sorted { $0.createdAt < $1.createdAt }, to: file)
    }
}
