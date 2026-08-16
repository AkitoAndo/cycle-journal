//
//  TaskService.swift
//  CycleJournal
//

import Foundation

protocol TaskSyncing {
    func getTasks(status: String?, limit: Int, offset: Int) async throws -> TaskListData
    func createTask(
        title: String,
        clientTaskId: String?,
        description: String?,
        sessionId: String?,
        cycleElement: String?
    ) async throws -> TaskData
    func updateTask(
        taskId: String,
        title: String?,
        description: String?,
        status: String?
    ) async throws -> TaskData
    func deleteTask(taskId: String) async throws
}

class TaskService: TaskSyncing {
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
            requiresAuth: true
        )

        return response.data
    }

    /// タスクを作成
    func createTask(
        title: String,
        clientTaskId: String? = nil,
        description: String? = nil,
        sessionId: String? = nil,
        cycleElement: String? = nil
    ) async throws -> TaskData {
        let request = CreateTaskRequest(
            title: title,
            clientTaskId: clientTaskId,
            description: description,
            sessionId: sessionId,
            cycleElement: cycleElement
        )

        let response: APIResponse<TaskData> = try await apiClient.post(
            path: "/tasks",
            body: request,
            requiresAuth: true
        )

        return response.data
    }

    /// タスクを更新
    func updateTask(
        taskId: String,
        title: String? = nil,
        description: String? = nil,
        status: String? = nil
    ) async throws -> TaskData {
        let request = UpdateTaskRequest(
            title: title,
            description: description,
            status: status
        )

        let response: APIResponse<TaskData> = try await apiClient.put(
            path: "/tasks/\(taskId)",
            body: request,
            requiresAuth: true
        )

        return response.data
    }

    /// タスクを削除
    func deleteTask(taskId: String) async throws {
        try await apiClient.delete(
            path: "/tasks/\(taskId)",
            requiresAuth: true
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
            requiresAuth: true
        )

        return response.data
    }
}
