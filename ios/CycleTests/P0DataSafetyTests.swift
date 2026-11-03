import Foundation
import Testing

@testable import Cycle

struct UserDataScopeTests {
    @Test func usersHaveDistinctOpaqueStorageLocationsAndDefaultsKeys() {
        let aliceDirectory = UserDataScope.dataDirectory(for: "alice@example.com")
        let bobDirectory = UserDataScope.dataDirectory(for: "bob@example.com")

        #expect(aliceDirectory != bobDirectory)
        #expect(!aliceDirectory.path.contains("alice@example.com"))
        #expect(
            UserDataScope.scopedDefaultsKey("userGoal", userID: "alice@example.com")
                != UserDataScope.scopedDefaultsKey("userGoal", userID: "bob@example.com")
        )
    }

    @Test func deletingAccountScopeRemovesFilesAndDefaults() throws {
        let userID = "delete-test-\(UUID().uuidString)"
        let directory = UserDataScope.dataDirectory(for: userID)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let file = directory.appendingPathComponent("journals.json")
        try Data("private".utf8).write(to: file)

        let defaultsKey = UserDataScope.scopedDefaultsKey("userGoal", userID: userID)
        UserDefaults.standard.set("selfAwareness", forKey: defaultsKey)

        UserDataScope.deleteData(for: userID)

        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(UserDefaults.standard.object(forKey: defaultsKey) == nil)
    }
}

struct TaskSyncMutationStoreTests {
    @Test func latestUpsertPreservesDeleteAndReplacesOlderUpsert() {
        let taskID = UUID()
        let otherID = UUID()
        let existing = [
            TaskSyncMutation(localTaskID: taskID, kind: .delete, serverID: "server-1"),
            TaskSyncMutation(localTaskID: taskID, kind: .upsert),
            TaskSyncMutation(localTaskID: otherID, kind: .upsert),
        ]

        let result = TaskSyncMutationStore.applyingUpsert(
            to: existing,
            localTaskID: taskID
        )

        let taskMutations = result.filter { $0.localTaskID == taskID }
        #expect(taskMutations.map(\.kind) == [.delete, .upsert])
        #expect(taskMutations[0].serverID == "server-1")
        #expect(taskMutations[0].createdAt < taskMutations[1].createdAt)
        #expect(result.contains { $0.localTaskID == otherID })
    }

    @Test func deletingNeverSyncedTaskCancelsPendingCreate() {
        let taskID = UUID()
        let existing = [TaskSyncMutation(localTaskID: taskID, kind: .upsert)]

        let result = TaskSyncMutationStore.applyingDelete(
            to: existing,
            localTaskID: taskID,
            serverID: nil
        )

        #expect(result.isEmpty)
    }

    @Test func deletingSyncedTaskPersistsServerTombstone() {
        let taskID = UUID()

        let result = TaskSyncMutationStore.applyingDelete(
            to: [],
            localTaskID: taskID,
            serverID: "server-1"
        )

        #expect(result.count == 1)
        #expect(result[0].kind == .delete)
        #expect(result[0].serverID == "server-1")
    }

    @Test func recreatingTaskQueuesDeleteBeforeUpsert() {
        let taskID = UUID()

        let result = TaskSyncMutationStore.applyingRecreate(
            to: [TaskSyncMutation(localTaskID: taskID, kind: .upsert)],
            localTaskID: taskID,
            previousServerID: "server-1"
        )

        #expect(result.count == 2)
        #expect(result[0].kind == .delete)
        #expect(result[0].serverID == "server-1")
        #expect(result[1].kind == .upsert)
    }

    @Test func recreatingNeverSyncedTaskQueuesOnlyUpsert() {
        let taskID = UUID()

        let result = TaskSyncMutationStore.applyingRecreate(
            to: [],
            localTaskID: taskID,
            previousServerID: nil
        )

        #expect(result.count == 1)
        #expect(result[0].kind == .upsert)
    }

    @Test func editingRestoredTaskKeepsOldServerDeletion() {
        let taskID = UUID()
        let restored = TaskSyncMutationStore.applyingRecreate(
            to: [], localTaskID: taskID, previousServerID: "old-server"
        )
        let edited = TaskSyncMutationStore.applyingUpsert(to: restored, localTaskID: taskID)
        #expect(edited.map(\.kind) == [.delete, .upsert])
        #expect(edited[0].serverID == "old-server")
        #expect(edited[0].createdAt < edited[1].createdAt)
    }

    @Test func deletingRestoredTaskKeepsOldServerDeletion() {
        let taskID = UUID()
        let restored = TaskSyncMutationStore.applyingRecreate(
            to: [], localTaskID: taskID, previousServerID: "old-server"
        )
        let deleted = TaskSyncMutationStore.applyingDelete(
            to: restored, localTaskID: taskID, serverID: nil
        )
        #expect(deleted.count == 1)
        #expect(deleted[0].kind == .delete)
        #expect(deleted[0].serverID == "old-server")
    }

    @Test func restoringAgainRetainsDeletionWithoutDuplicates() {
        let taskID = UUID()
        let restored = TaskSyncMutationStore.applyingRecreate(
            to: [], localTaskID: taskID, previousServerID: "old-server"
        )
        let repeated = TaskSyncMutationStore.applyingRecreate(
            to: restored, localTaskID: taskID, previousServerID: "old-server"
        )
        let withoutServerID = TaskSyncMutationStore.applyingRecreate(
            to: repeated, localTaskID: taskID, previousServerID: nil
        )
        #expect(withoutServerID.map(\.kind) == [.delete, .upsert])
        #expect(withoutServerID[0].serverID == "old-server")
        #expect(withoutServerID[0].createdAt < withoutServerID[1].createdAt)
    }
}
