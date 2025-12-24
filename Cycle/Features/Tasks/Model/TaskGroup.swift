//
//  TaskGroup.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/12/10.
//

import Foundation

/// タスクグループのデータモデル
///
/// タスクをグループ化して管理するためのモデル
/// - グループ名
/// - 色情報（オプション）
/// - 並び順
struct TaskGroup: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// グループ名
    var name: String

    /// グループの色（16進数カラーコード、例: "#FF5733"）
    var colorHex: String?

    /// 表示順序（小さいほど上に表示）
    var order: Int

    /// 作成日時
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, colorHex: String? = nil, order: Int = 0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.order = order
    }
}
