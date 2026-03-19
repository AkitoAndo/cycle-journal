//
//  TaskArchiveStore.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2026/02/28.
//

import Foundation

/// タスクアーカイブの永続化を担当するストア
///
/// JSONFileStoreを使用してアーカイブをJSONファイルに保存・読み込みします。
enum TaskArchiveStore {
    private static let file = "task_archives.json"

    /// 全てのアーカイブを読み込み
    static func loadAll() -> [TaskArchive] {
        JSONFileStore.load(file, as: [TaskArchive].self) ?? []
    }

    /// 全てのアーカイブを保存
    static func saveAll(_ archives: [TaskArchive]) {
        JSONFileStore.save(archives, to: file)
    }

    /// 特定の日付のアーカイブを取得
    static func load(for date: Date) -> TaskArchive? {
        let startOfDay = TaskArchive.startOfDay(for: date)
        return loadAll().first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// 特定の日付のアーカイブを保存または更新
    static func save(_ archive: TaskArchive) {
        var archives = loadAll()
        let startOfDay = TaskArchive.startOfDay(for: archive.date)

        if let index = archives.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            archives[index] = archive
        } else {
            archives.append(archive)
        }

        // 日付の降順でソート
        archives.sort { $0.date > $1.date }
        saveAll(archives)
    }
}
