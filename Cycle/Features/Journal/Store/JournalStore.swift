//
//  JournalStore.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import Foundation

/// ジャーナルエントリの永続化を担当
///
/// JSONFileStoreを利用してジャーナルエントリを
/// ローカルストレージに保存・読み込み
enum JournalStore {
    private static let file = "journals.json"

    /// 全てのジャーナルエントリを読み込み
    /// - Returns: 保存されているエントリの配列（失敗時は空配列）
    static func loadAll() -> [JournalEntry] {
        JSONFileStore.load(file, as: [JournalEntry].self) ?? []
    }

    /// 全てのジャーナルエントリを保存
    /// - Parameter items: 保存するエントリの配列
    static func saveAll(_ items: [JournalEntry]) {
        JSONFileStore.save(items, to: file)
    }
}
