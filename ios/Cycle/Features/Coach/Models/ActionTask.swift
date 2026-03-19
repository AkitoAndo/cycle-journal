//
//  ActionTask.swift
//  CycleJournal
//

import Foundation

/// 行動タスク
struct ActionTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var status: TaskStatus
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?
    var sourceSessionId: UUID?
    var reflection: TaskReflection?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        status: TaskStatus = .pending,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        sourceSessionId: UUID? = nil,
        reflection: TaskReflection? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sourceSessionId = sourceSessionId
        self.reflection = reflection
    }
}

/// タスクのステータス
enum TaskStatus: String, Codable {
    case pending    // 未着手
    case inProgress // 進行中
    case completed  // 完了
}

/// タスクのふりかえり
struct TaskReflection: Codable {
    var fact: String       // 事実の確認「何をした？」
    var emotion: String    // 感情の観察「どう感じた？」
    var learning: String   // 学びの抽出「何に気づいた？」
    var nextStep: String   // 次への調整「次はどうする？」
    var createdAt: Date

    init(
        fact: String = "",
        emotion: String = "",
        learning: String = "",
        nextStep: String = "",
        createdAt: Date = Date()
    ) {
        self.fact = fact
        self.emotion = emotion
        self.learning = learning
        self.nextStep = nextStep
        self.createdAt = createdAt
    }
}
