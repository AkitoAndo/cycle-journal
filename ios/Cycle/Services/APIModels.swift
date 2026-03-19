//
//  APIModels.swift
//  CycleJournal
//

import Foundation

// MARK: - Coach API Models

struct CoachRequest: Encodable {
    let message: String
    let sessionId: String?
    let diaryContent: String?
    let context: CoachContext?
}

struct CoachContext: Encodable {
    let cycleElement: String?
}

struct CoachResponseData: Decodable {
    let message: String
    let sessionId: String?
    let metadata: CoachMetadata?
}

struct CoachMetadata: Decodable {
    let stage: String?
    let model: String?
    let cycleElement: String?
    let detectedEmotion: String?
    let responseType: String?
}

// MARK: - Session API Models

struct CreateSessionRequest: Encodable {
    let title: String?
    let diaryContent: String?
    let cycleElement: String?
}

struct SessionData: Decodable {
    let sessionId: String
    let title: String?
    let cycleElement: String?
    let messageCount: Int?
    let lastMessageAt: Date?
    let createdAt: Date
}

struct SessionListData: Decodable {
    let sessions: [SessionData]
    let total: Int
    let limit: Int
    let offset: Int
}

struct SessionDetailData: Decodable {
    let sessionId: String
    let title: String?
    let cycleElement: String?
    let hasDiaryContext: Bool?
    let messages: [MessageData]
    let createdAt: Date
    let updatedAt: Date?
}

struct MessageData: Decodable {
    let messageId: String
    let role: String
    let content: String
    let metadata: MessageMetadataData?
    let createdAt: Date
}

struct MessageMetadataData: Decodable {
    let detectedEmotion: String?
    let responseType: String?
}

// MARK: - Task API Models

struct CreateTaskRequest: Encodable {
    let title: String
    let description: String?
    let sessionId: String?
    let cycleElement: String?
    let dueDate: Date?
}

struct UpdateTaskRequest: Encodable {
    let title: String?
    let description: String?
    let status: String?
    let dueDate: Date?
}

struct TaskData: Decodable {
    let taskId: String
    let title: String
    let description: String?
    let status: String
    let sessionId: String?
    let cycleElement: String?
    let dueDate: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date?
}

struct TaskListData: Decodable {
    let tasks: [TaskData]
    let total: Int
    let limit: Int
    let offset: Int
}

struct CreateReflectionRequest: Encodable {
    let whatIDid: String
    let whatINoticed: String
    let whatIWantToTry: String?
    let overallFeeling: String?
}

struct ReflectionData: Decodable {
    let reflectionId: String
    let taskId: String
    let whatIDid: String
    let whatINoticed: String
    let whatIWantToTry: String?
    let overallFeeling: String?
    let createdAt: Date
}

// MARK: - User API Models

struct UserData: Decodable {
    let userId: String
    let appleUserId: String?
    let email: String?
    let displayName: String?
    let settings: UserSettings?
    let createdAt: Date
    let updatedAt: Date?
}

struct UserSettings: Decodable {
    let notificationEnabled: Bool?
    let reminderTime: String?
}

// MARK: - Health API Models

struct HealthData: Decodable {
    let status: String
    let stage: String
    let timestamp: String
}
