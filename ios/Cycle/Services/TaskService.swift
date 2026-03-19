//
//  TaskService.swift
//  CycleJournal
//

import Foundation

class TaskService {
    private let apiClient = APIClient.shared

    // MARK: - Tasks

    /// タスク一覧を取得
    func getTasks(status: String? = nil, limit: Int = 20, offset: Int = 0) async throws -> TaskListData {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        let response: APIResponse<TaskListData> = try await apiClient.get(
            path: "/tasks",
            queryItems: queryItems,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }

    /// タスクを作成
    func createTask(
        title: String,
        description: String? = nil,
        sessionId: String? = nil,
        cycleElement: String? = nil,
        dueDate: Date? = nil
    ) async throws -> TaskData {
        let request = CreateTaskRequest(
            title: title,
            description: description,
            sessionId: sessionId,
            cycleElement: cycleElement,
            dueDate: dueDate
        )

        let response: APIResponse<TaskData> = try await apiClient.post(
            path: "/tasks",
            body: request,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }

    /// タスクを更新
    func updateTask(
        taskId: String,
        title: String? = nil,
        description: String? = nil,
        status: String? = nil,
        dueDate: Date? = nil
    ) async throws -> TaskData {
        let request = UpdateTaskRequest(
            title: title,
            description: description,
            status: status,
            dueDate: dueDate
        )

        let response: APIResponse<TaskData> = try await apiClient.put(
            path: "/tasks/\(taskId)",
            body: request,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }

    /// タスクを削除
    func deleteTask(taskId: String) async throws {
        try await apiClient.delete(
            path: "/tasks/\(taskId)",
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )
    }

    /// タスクのふりかえりを登録
    func createReflection(
        taskId: String,
        whatIDid: String,
        whatINoticed: String,
        whatIWantToTry: String? = nil,
        overallFeeling: String? = nil
    ) async throws -> ReflectionData {
        let request = CreateReflectionRequest(
            whatIDid: whatIDid,
            whatINoticed: whatINoticed,
            whatIWantToTry: whatIWantToTry,
            overallFeeling: overallFeeling
        )

        let response: APIResponse<ReflectionData> = try await apiClient.post(
            path: "/tasks/\(taskId)/reflection",
            body: request,
            requiresAuth: false // TODO: 認証実装後にtrueに変更
        )

        return response.data
    }
}
