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
    @Test func latestUpsertReplacesOlderMutationForSameTask() {
        let taskID = UUID()
        let otherID = UUID()
        let existing = [
            TaskSyncMutation(localTaskID: taskID, kind: .delete, serverID: "server-1"),
            TaskSyncMutation(localTaskID: otherID, kind: .upsert),
        ]

        let result = TaskSyncMutationStore.applyingUpsert(
            to: existing,
            localTaskID: taskID
        )

        #expect(result.filter { $0.localTaskID == taskID }.count == 1)
        #expect(result.first { $0.localTaskID == taskID }?.kind == .upsert)
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
}
