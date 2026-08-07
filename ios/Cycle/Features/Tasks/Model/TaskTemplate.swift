//
//  TaskTemplate.swift
//  Cycle
//
//  何度も使うタスクをあらかじめ登録しておく「テンプレート」のモデル。
//  実行後の振り返り（事実・気づき・次の一手）は
//  タスクごとに変わる値のため、テンプレートには含めない。
//

import Foundation

struct TaskTemplate: Identifiable, Codable, Hashable {
    /// 一意識別子
    var id = UUID()

    /// タスクのタイトル
    var title: String

    /// タスクの詳細説明
    var description: String = ""

    /// 意図
    var intent: String = ""

    /// 完了イメージ
    var achievementVision: String = ""

    /// 注意点
    var notes: String = ""

    /// 登録日時
    var createdAt: Date = Date()
}

extension TaskTemplate {
    /// 一覧の2行目に出すプレビュー（詳細 → 意図 → 注意点の順で最初の非空欄）
    var previewText: String {
        [description, intent, notes].first { !$0.isEmpty } ?? ""
    }
}
