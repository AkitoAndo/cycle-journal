//
//  CoachSession.swift
//  CycleJournal
//

import Foundation

/// コーチとの会話セッション
struct CoachSession: Identifiable, Codable {
    let id: UUID
    var messages: [CoachMessage]
    var createdAt: Date
    var updatedAt: Date
    var summary: String?
    var emotionLabel: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        messages: [CoachMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        summary: String? = nil,
        emotionLabel: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summary = summary
        self.emotionLabel = emotionLabel
        self.isActive = isActive
    }

    /// セッションの最初のユーザーメッセージを取得
    var firstUserMessage: String? {
        messages.first { $0.role == .user }?.content
    }
}

/// コーチとの会話メッセージ
struct CoachMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let createdAt: Date
    var metadata: MessageMetadata?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

/// メッセージの送信者
enum MessageRole: String, Codable {
    case user
    case coach
}

/// メッセージのメタデータ
struct MessageMetadata: Codable {
    var cycleElement: String?
    var emotionDetected: String?
    var suggestedAction: SuggestedAction?
}

/// 提案されたアクション
struct SuggestedAction: Codable {
    let description: String
    let taskId: UUID?
}
