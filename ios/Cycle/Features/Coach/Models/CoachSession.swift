//
//  CoachSession.swift
//  CycleJournal
//

import Foundation

/// コーチとの会話セッション
struct CoachSession: Identifiable, Codable {
    let id: UUID
    var serverId: String?
    var messages: [CoachMessage]
    var createdAt: Date
    var updatedAt: Date
    var summary: String?
    var emotionLabel: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        serverId: String? = nil,
        messages: [CoachMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        summary: String? = nil,
        emotionLabel: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.serverId = serverId
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

    /// サーバーのSessionDataからCoachSessionを生成
    static func from(_ data: SessionData) -> CoachSession {
        CoachSession(
            serverId: data.sessionId,
            createdAt: data.createdAt,
            updatedAt: data.lastMessageAt ?? data.createdAt,
            summary: data.title,
            isActive: false
        )
    }

    /// サーバーのSessionDetailDataからCoachSessionを生成（メッセージ付き）
    static func from(_ detail: SessionDetailData) -> CoachSession {
        let messages = detail.messages.map { msg in
            CoachMessage(
                role: msg.role == "user" ? .user : .coach,
                content: msg.content,
                createdAt: msg.createdAt,
                metadata: msg.metadata.map { meta in
                    MessageMetadata(
                        cycleElement: nil,
                        emotionDetected: meta.detectedEmotion,
                        suggestedAction: nil
                    )
                }
            )
        }
        return CoachSession(
            serverId: detail.sessionId,
            messages: messages,
            createdAt: detail.createdAt,
            updatedAt: detail.updatedAt ?? detail.createdAt,
            summary: detail.title,
            isActive: false
        )
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
