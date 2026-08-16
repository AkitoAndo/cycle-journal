//
//  UserDataScope.swift
//  Cycle
//
//  ユーザーごとのローカルデータ領域を管理する。
//

import CryptoKit
import Foundation

extension Notification.Name {
    static let localDataScopeDidChange = Notification.Name("localDataScopeDidChange")
}

enum UserDataScope {
    private static let activeUserKey = "cycle.activeLocalDataUserID"
    private static let migrationOwnerKey = "cycle.legacyLocalDataMigrationOwner"

    private static let legacyFiles = [
        "journals.json",
        "tasks.json",
        "task_archives.json",
        "task_templates.json",
        "schedules.json",
        "notification_settings.json",
        "task_sync_mutations.json",
        "coach_deleted_session_ids.json",
    ]

    private static let scopedDefaultsKeys = [
        "availableTags",
        "CoachSessions",
        "MeditationLogs",
        "journalLastSyncedAt",
        "journalPendingDeletedIDs",
        "userGoal",
        "isPostActionPromptEnabled",
        "breathingCompletedCount",
    ]

    static var activeUserID: String? {
        UserDefaults.standard.string(forKey: activeUserKey)
    }

    /// 認証済みユーザーの保存領域へ切り替える。
    ///
    /// 旧バージョンの共有領域は、起動時に Keychain から同一ユーザーを特定できた場合だけ
    /// `adoptLegacyData` を true にして移行する。新規サインイン時には所有者を断定できないため
    /// 自動移行しない。
    static func activate(userID: String, adoptLegacyData: Bool = false) {
        if adoptLegacyData {
            migrateLegacyDataIfNeeded(to: userID)
        }

        let changed = activeUserID != userID
        UserDefaults.standard.set(userID, forKey: activeUserKey)
        adoptPendingOnboardingGoal(for: userID)
        try? FileManager.default.createDirectory(
            at: dataDirectory(for: userID),
            withIntermediateDirectories: true
        )
        if changed {
            NotificationCenter.default.post(name: .localDataScopeDidChange, object: nil)
        }
    }

    static func deactivate() {
        guard activeUserID != nil else { return }
        UserDefaults.standard.removeObject(forKey: activeUserKey)
        NotificationCenter.default.post(name: .localDataScopeDidChange, object: nil)
    }

    static func deleteData(for userID: String) {
        try? FileManager.default.removeItem(at: dataDirectory(for: userID))
        let defaults = UserDefaults.standard
        let userPrefix = "cycle.user.\(scopeIdentifier(for: userID))."
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(userPrefix) {
            defaults.removeObject(forKey: key)
        }

        if activeUserID == userID {
            defaults.removeObject(forKey: activeUserKey)
            NotificationCenter.default.post(name: .localDataScopeDidChange, object: nil)
        }
    }

    static func scopedDefaultsKey(_ key: String, userID: String? = nil) -> String {
        let scope = scopeIdentifier(for: userID ?? activeUserID)
        return "cycle.user.\(scope).\(key)"
    }

    static func currentDataDirectory() -> URL {
        dataDirectory(for: activeUserID)
    }

    static func dataDirectory(for userID: String?) -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("Cycle", isDirectory: true)
            .appendingPathComponent("Users", isDirectory: true)
            .appendingPathComponent(scopeIdentifier(for: userID), isDirectory: true)
    }

    private static func scopeIdentifier(for userID: String?) -> String {
        guard let userID, !userID.isEmpty else { return "signed-out" }
        let digest = SHA256.hash(data: Data(userID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func migrateLegacyDataIfNeeded(to userID: String) {
        let defaults = UserDefaults.standard
        if let owner = defaults.string(forKey: migrationOwnerKey) {
            guard owner == userID else { return }
        } else {
            defaults.set(userID, forKey: migrationOwnerKey)
        }

        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let destination = dataDirectory(for: userID)
        try? fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for fileName in legacyFiles {
            let sourceURL = documents.appendingPathComponent(fileName)
            let destinationURL = destination.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: sourceURL.path),
                  !fileManager.fileExists(atPath: destinationURL.path) else { continue }
            try? fileManager.moveItem(at: sourceURL, to: destinationURL)
        }

        for key in scopedDefaultsKeys {
            let destinationKey = scopedDefaultsKey(key, userID: userID)
            guard defaults.object(forKey: destinationKey) == nil,
                  let value = defaults.object(forKey: key) else { continue }
            defaults.set(value, forKey: destinationKey)
            defaults.removeObject(forKey: key)
        }
    }

    private static func adoptPendingOnboardingGoal(for userID: String) {
        let defaults = UserDefaults.standard
        let destinationKey = scopedDefaultsKey("userGoal", userID: userID)
        guard defaults.object(forKey: destinationKey) == nil,
              let goal = defaults.string(forKey: "pendingOnboardingGoal") else { return }
        defaults.set(goal, forKey: destinationKey)
        defaults.removeObject(forKey: "pendingOnboardingGoal")
    }
}
