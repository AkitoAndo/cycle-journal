//
//  TaskViewModel.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation
import Combine

@MainActor
final class TaskViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var groups: [TaskGroup] = []
    @Published var selectedGroupId: UUID? = nil

    init() {
        tasks = TaskStore.loadAll()
        groups = loadGroups()
    }

    /// 選択されたグループまたは全てのタスクを取得
    var filteredTasks: [TaskItem] {
        if let groupId = selectedGroupId {
            return tasks.filter { $0.groupId == groupId }
        } else {
            return tasks
        }
    }

    /// フィルタリングされた未完了タスク
    var incompleteTasks: [TaskItem] {
        filteredTasks.filter { !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// フィルタリングされた完了タスク
    var completedTasks: [TaskItem] {
        filteredTasks.filter { $0.isCompleted }
            .sorted { $0.completedAt ?? $0.createdAt > $1.completedAt ?? $1.createdAt }
    }

    /// グループを表示順にソート
    var sortedGroups: [TaskGroup] {
        groups.sorted { $0.order < $1.order }
    }

    func addTask(title: String, description: String = "", groupId: UUID? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        var newTask = TaskItem(title: trimmedTitle, description: description)
        newTask.groupId = groupId ?? selectedGroupId
        tasks.append(newTask)
        persist()
    }

    func toggleCompletion(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
        persist()
    }

    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    func updateTask(_ task: TaskItem, newTitle: String, newDescription: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        tasks[index].title = trimmedTitle
        tasks[index].description = newDescription
        persist()
    }

    // MARK: - Private Helpers

    private func persist() {
        TaskStore.saveAll(tasks)
    }

    // MARK: - Group Management

    /// 新しいグループを追加
    func addGroup(name: String, colorHex: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newOrder = (groups.map { $0.order }.max() ?? -1) + 1
        let newGroup = TaskGroup(name: trimmedName, colorHex: colorHex, order: newOrder)
        groups.append(newGroup)
        saveGroups()
    }

    /// グループを更新
    func updateGroup(_ group: TaskGroup, newName: String, newColorHex: String?) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }

        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        groups[index].name = trimmedName
        groups[index].colorHex = newColorHex
        saveGroups()
    }

    /// グループを削除（グループ内のタスクは未分類に移動）
    func deleteGroup(_ group: TaskGroup) {
        // グループ内のタスクのgroupIdをnilに設定
        for task in tasks where task.groupId == group.id {
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].groupId = nil
            }
        }

        groups.removeAll { $0.id == group.id }
        persist()
        saveGroups()

        // 削除したグループが選択されていた場合、選択を解除
        if selectedGroupId == group.id {
            selectedGroupId = nil
        }
    }

    /// グループを選択
    func selectGroup(_ groupId: UUID?) {
        selectedGroupId = groupId
    }

    /// UserDefaultsからグループを読み込み
    private func loadGroups() -> [TaskGroup] {
        guard let data = UserDefaults.standard.data(forKey: "taskGroups"),
              let groups = try? JSONDecoder().decode([TaskGroup].self, from: data) else {
            return []
        }
        return groups
    }

    /// グループをUserDefaultsに保存
    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: "taskGroups")
        }
    }
}
