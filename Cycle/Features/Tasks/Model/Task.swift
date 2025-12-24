//
//  Task.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation

/// タスクアイテムのデータモデル
///
/// 1つのタスクを表現するモデル
/// - タイトル、詳細説明
/// - グループ
/// - 完了状態と日時
struct TaskItem: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// タスクのタイトル
    var title: String

    /// タスクの詳細説明
    var description: String = ""

    /// 所属するグループのID（nilの場合は「未分類」）
    var groupId: UUID?

    /// 完了状態
    var isCompleted: Bool = false

    /// 作成日時
    var createdAt: Date = Date()

    /// 完了日時
    var completedAt: Date?
}
