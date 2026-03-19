//
//  TaskViewModel.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/15.
//

import Foundation
import Combine

/// タスク管理のビジネスロジックを担当するViewModel
/// タスクとグループの CRUD 操作、フィルタリング、並び替えを提供
@MainActor
final class TaskViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 全てのタスク
    @Published private(set) var tasks: [TaskItem] = []

    /// 全てのアーカイブ
    @Published private(set) var archives: [TaskArchive] = []

    // MARK: - Initialization

    init() {
        loadData()
        loadArchives()
    }

    // MARK: - Computed Properties

    /// 未完了タスク（sortOrder順）
    var incompleteTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted && $0.deletedAt == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 完了タスク（完了日時の降順）
    var completedTasks: [TaskItem] {
        tasks
            .filter { $0.isCompleted && $0.deletedAt == nil }
            .sorted { $0.completedAt ?? $0.createdAt > $1.completedAt ?? $1.createdAt }
    }

    /// 最近削除したタスク（削除日時の降順）
    var deletedTasks: [TaskItem] {
        tasks
            .filter { $0.deletedAt != nil }
            .sorted { $0.deletedAt! > $1.deletedAt! }
    }

    // MARK: - Task Management

    /// 新しいタスクを追加
    func addTask(
        title: String,
        description: String = "",
        intent: String = "",
        achievementVision: String = "",
        notes: String = "",
        fact: String = "",
        insight: String = "",
        nextAction: String = ""
    ) {
        guard let trimmedTitle = trimTitle(title), !trimmedTitle.isEmpty else { return }

        let maxSortOrder = incompleteTasks.map { $0.sortOrder }.max() ?? -1
        var newTask = TaskItem(
            title: trimmedTitle,
            description: description,
            intent: intent,
            achievementVision: achievementVision,
            notes: notes
        )
        newTask.sortOrder = maxSortOrder + 1
        newTask.fact = fact
        newTask.insight = insight
        newTask.nextAction = nextAction

        tasks.append(newTask)
        persist()
    }

    /// タスクの完了状態を切り替え
    func toggleCompletion(_ task: TaskItem) {
        guard let index = findTaskIndex(task) else { return }

        tasks[index].isCompleted.toggle()
        tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
        persist()
    }

    /// タスクを更新
    func updateTask(
        _ task: TaskItem,
        newTitle: String,
        newDescription: String,
        newIntent: String = "",
        newAchievementVision: String = "",
        newNotes: String = "",
        newFact: String = "",
        newInsight: String = "",
        newNextAction: String = ""
    ) {
        guard let trimmedTitle = trimTitle(newTitle), !trimmedTitle.isEmpty else { return }

        // 通常のタスクリストで検索
        if let index = findTaskIndex(task) {
            tasks[index].title = trimmedTitle
            tasks[index].description = newDescription
            tasks[index].intent = newIntent
            tasks[index].achievementVision = newAchievementVision
            tasks[index].notes = newNotes
            tasks[index].fact = newFact
            tasks[index].insight = newInsight
            tasks[index].nextAction = newNextAction
            persist()
        } else {
            // アーカイブ内のタスクとして更新
            updateArchivedTask(
                task,
                newTitle: trimmedTitle,
                newDescription: newDescription,
                newIntent: newIntent,
                newAchievementVision: newAchievementVision,
                newNotes: newNotes,
                newFact: newFact,
                newInsight: newInsight,
                newNextAction: newNextAction
            )
        }
    }

    /// タスクを削除（論理削除）
    func deleteTask(_ task: TaskItem) {
        guard let index = findTaskIndex(task) else { return }
        tasks[index].deletedAt = Date()
        persist()
    }

    /// タスクを復元
    func restoreTask(_ task: TaskItem) {
        guard let index = findTaskIndex(task) else { return }
        tasks[index].deletedAt = nil
        persist()
    }

    /// タスクを完全に削除（物理削除）
    func permanentlyDeleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    /// 未完了タスクの順序を変更
    func moveIncompleteTasks(from source: IndexSet, to destination: Int) {
        var reorderedTasks = incompleteTasks
        let itemsToMove = source.map { reorderedTasks[$0] }

        // 元の位置から削除（降順で削除して位置ずれを防ぐ）
        for index in source.sorted().reversed() {
            reorderedTasks.remove(at: index)
        }

        // 新しい位置に挿入
        let adjustedDestination = min(destination, reorderedTasks.count)
        reorderedTasks.insert(contentsOf: itemsToMove, at: adjustedDestination)

        // sortOrder を更新
        updateSortOrders(for: reorderedTasks)
        persist()
    }

    // MARK: - Private Helpers - Initialization

    /// データをロード
    private func loadData() {
        tasks = TaskStore.loadAll()
    }

    /// アーカイブをロード
    private func loadArchives() {
        archives = TaskArchiveStore.loadAll()
    }

    // MARK: - Private Helpers - Finding

    /// タスクのインデックスを検索
    private func findTaskIndex(_ task: TaskItem) -> Int? {
        tasks.firstIndex(where: { $0.id == task.id })
    }

    // MARK: - Private Helpers - Updating

    /// sortOrderを更新
    private func updateSortOrders(for reorderedTasks: [TaskItem]) {
        for (index, task) in reorderedTasks.enumerated() {
            if let taskIndex = findTaskIndex(task) {
                tasks[taskIndex].sortOrder = index
            }
        }
    }

    // MARK: - Private Helpers - Validation

    /// タイトルをトリム
    private func trimTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Private Helpers - Persistence

    /// タスクを永続化
    private func persist() {
        TaskStore.saveAll(tasks)
    }

    // MARK: - Archive Management

    /// 個別の完了タスクをアーカイブ
    func archiveTask(_ task: TaskItem) {
        guard task.isCompleted else { return }

        // 今日の0時のアーカイブを取得または作成
        let today = TaskArchive.todayStart
        var archive = TaskArchiveStore.load(for: today) ?? TaskArchive(date: today, completedTasks: [])

        // アーカイブに追加（重複を避ける）
        let existingIds = Set(archive.completedTasks.map { $0.id })
        if !existingIds.contains(task.id) {
            archive.completedTasks.append(task)
        }

        // アーカイブを保存
        TaskArchiveStore.save(archive)

        // タスクリストから削除
        tasks.removeAll { $0.id == task.id }

        persist()
        loadArchives()
    }

    /// 完了タスクをアーカイブ
    func archiveCompletedTasks() {
        let completed = completedTasks

        guard !completed.isEmpty else { return }

        // 今日の0時のアーカイブを取得または作成
        let today = TaskArchive.todayStart
        var archive = TaskArchiveStore.load(for: today) ?? TaskArchive(date: today, completedTasks: [])

        // 既存のアーカイブに追加（重複を避ける）
        let existingIds = Set(archive.completedTasks.map { $0.id })
        let newTasks = completed.filter { !existingIds.contains($0.id) }
        archive.completedTasks.append(contentsOf: newTasks)

        // アーカイブを保存
        TaskArchiveStore.save(archive)

        // 完了タスクを削除
        tasks.removeAll { $0.isCompleted }

        persist()
        loadArchives()
    }

    /// アーカイブ内のタスクを更新
    func updateArchivedTask(
        _ task: TaskItem,
        newTitle: String,
        newDescription: String,
        newIntent: String = "",
        newAchievementVision: String = "",
        newNotes: String = "",
        newFact: String = "",
        newInsight: String = "",
        newNextAction: String = ""
    ) {
        guard let trimmedTitle = trimTitle(newTitle), !trimmedTitle.isEmpty else { return }

        var updatedArchives = archives
        var taskFound = false

        for archiveIndex in updatedArchives.indices {
            if let taskIndex = updatedArchives[archiveIndex].completedTasks.firstIndex(where: { $0.id == task.id }) {
                updatedArchives[archiveIndex].completedTasks[taskIndex].title = trimmedTitle
                updatedArchives[archiveIndex].completedTasks[taskIndex].description = newDescription
                updatedArchives[archiveIndex].completedTasks[taskIndex].intent = newIntent
                updatedArchives[archiveIndex].completedTasks[taskIndex].achievementVision = newAchievementVision
                updatedArchives[archiveIndex].completedTasks[taskIndex].notes = newNotes
                updatedArchives[archiveIndex].completedTasks[taskIndex].fact = newFact
                updatedArchives[archiveIndex].completedTasks[taskIndex].insight = newInsight
                updatedArchives[archiveIndex].completedTasks[taskIndex].nextAction = newNextAction

                TaskArchiveStore.save(updatedArchives[archiveIndex])
                taskFound = true
                break
            }
        }

        if taskFound {
            loadArchives()
        }
    }

    /// アーカイブ内のタスクを削除（論理削除として復帰）
    func deleteArchivedTask(_ task: TaskItem) {
        var updatedArchives = archives
        var deletedTask: TaskItem?

        for archiveIndex in updatedArchives.indices {
            if let taskIndex = updatedArchives[archiveIndex].completedTasks.firstIndex(where: { $0.id == task.id }) {
                // タスクを取得してアーカイブから削除
                deletedTask = updatedArchives[archiveIndex].completedTasks[taskIndex]
                updatedArchives[archiveIndex].completedTasks.remove(at: taskIndex)

                // アーカイブが空になった場合は削除、そうでない場合は更新
                if updatedArchives[archiveIndex].completedTasks.isEmpty {
                    updatedArchives.remove(at: archiveIndex)
                    TaskArchiveStore.saveAll(updatedArchives)
                } else {
                    TaskArchiveStore.save(updatedArchives[archiveIndex])
                }
                break
            }
        }

        // タスクを論理削除状態で通常のタスクリストに追加
        if var task = deletedTask {
            task.deletedAt = Date()
            tasks.append(task)
            persist()
        }

        loadArchives()
    }
}
