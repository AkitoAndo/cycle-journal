//
//  TaskStore.swift
//  CycleJournal
//

import Foundation

class TaskStore: ObservableObject {
    @Published var tasks: [ActionTask] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let userDefaults = UserDefaults.standard
    private let tasksKey = "ActionTasks"
    private let taskService = TaskService()

    /// APIを使用するかどうか（falseの場合はローカルストレージのみ）
    /// 現在はバックエンドのタスクAPIが未実装のためfalse
    var useAPI: Bool = false

    init() {
        loadTasks()
    }

    // MARK: - Persistence

    func loadTasks() {
        if let data = userDefaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([ActionTask].self, from: data) {
            tasks = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            userDefaults.set(encoded, forKey: tasksKey)
        }
    }

    // MARK: - Task Management

    /// タスクを追加
    func addTask(_ task: ActionTask) {
        tasks.insert(task, at: 0)
        saveTasks()
    }

    /// タスクを追加（簡易版）
    func addTask(title: String, description: String? = nil, dueDate: Date? = nil, sourceSessionId: UUID? = nil) {
        let task = ActionTask(
            title: title,
            description: description,
            dueDate: dueDate,
            sourceSessionId: sourceSessionId
        )
        addTask(task)
    }

    /// タスクを更新
    func updateTask(_ task: ActionTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
        }
    }

    /// タスクを更新（フィールド指定版）
    func updateTask(_ task: ActionTask, title: String, description: String?, dueDate: Date?) {
        var updatedTask = task
        updatedTask.title = title
        updatedTask.description = description
        updatedTask.dueDate = dueDate
        updateTask(updatedTask)
    }

    /// タスクを削除
    func deleteTask(_ task: ActionTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    /// タスクのステータスを変更
    func updateTaskStatus(_ task: ActionTask, to status: TaskStatus) {
        var updatedTask = task
        updatedTask.status = status

        if status == .completed {
            updatedTask.completedAt = Date()
        }

        updateTask(updatedTask)
    }

    /// タスクにふりかえりを追加
    func addReflection(to task: ActionTask, reflection: TaskReflection) {
        var updatedTask = task
        updatedTask.reflection = reflection
        updatedTask.status = .completed
        updatedTask.completedAt = Date()
        updateTask(updatedTask)
    }

    // MARK: - Computed Properties

    /// 未完了タスク
    var pendingTasks: [ActionTask] {
        tasks.filter { $0.status != .completed }
    }

    /// 完了済みタスク
    var completedTasks: [ActionTask] {
        tasks.filter { $0.status == .completed }
    }

    /// 進行中タスク
    var inProgressTasks: [ActionTask] {
        tasks.filter { $0.status == .inProgress }
    }

    /// 期限が近いタスク（3日以内）
    var upcomingTasks: [ActionTask] {
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return pendingTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= threeDaysFromNow
        }
    }
}
