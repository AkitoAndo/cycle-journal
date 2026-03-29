//
//  Task.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation

/// タスクアイテムのデータモデル
///
/// 1つのタスクを表現するモデル。
/// タイトル、詳細説明、完了状態、グループ所属などの情報を保持します。
///
/// - Note: JSONファイルに永続化されます
struct TaskItem: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// サーバー側のID（同期済みの場合に設定）
    var serverId: String?

    /// タスクのタイトル
    var title: String

    /// タスクの詳細説明
    var description: String = ""

    /// 完了状態
    var isCompleted: Bool = false

    /// 作成日時
    var createdAt: Date = Date()

    /// 完了日時
    var completedAt: Date?

    /// 締切日時
    var dueDate: Date?

    /// 削除日時（論理削除用）
    var deletedAt: Date?

    /// 並び順（小さい値が上位）
    var sortOrder: Int = 0

    /// 意図
    var intent: String = ""

    /// 完了イメージ
    var achievementVision: String = ""

    /// 注意点
    var notes: String = ""

    /// 事実
    var fact: String = ""

    /// 気づき
    var insight: String = ""

    /// 次の一手
    var nextAction: String = ""
}
