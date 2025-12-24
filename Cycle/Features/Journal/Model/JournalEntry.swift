//
//  JournalEntry.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import Foundation

/// ジャーナルエントリのデータモデル
///
/// 1つの日記エントリを表現するモデル
/// - テキスト本文
/// - 作成日時
/// - 複数のタグ
struct JournalEntry: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// エントリの作成日時
    var date: Date = Date()

    /// エントリの本文
    var text: String

    /// 関連付けられたタグ
    var tags: [String] = []
}
