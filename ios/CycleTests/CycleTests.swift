//
//  CycleTests.swift
//  CycleTests
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import Testing
import Foundation
@testable import Cycle

// MARK: - JournalEntry Tests

struct JournalEntryTests {
    @Test func createEntryWithDefaults() {
        let entry = JournalEntry(text: "今日は良い天気だった")
        #expect(entry.text == "今日は良い天気だった")
        #expect(entry.tags.isEmpty)
        #expect(entry.deletedAt == nil)
    }

    @Test func createEntryWithTags() {
        let entry = JournalEntry(text: "ランニングした", tags: ["運動", "健康"])
        #expect(entry.tags.count == 2)
        #expect(entry.tags.contains("運動"))
        #expect(entry.tags.contains("健康"))
    }

    @Test func entryIdentifiable() {
        let entry1 = JournalEntry(text: "entry1")
        let entry2 = JournalEntry(text: "entry2")
        #expect(entry1.id != entry2.id)
    }

    @Test func entryCodable() throws {
        let entry = JournalEntry(text: "テスト", tags: ["タグ1"])
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(JournalEntry.self, from: data)
        #expect(decoded.text == "テスト")
        #expect(decoded.tags == ["タグ1"])
        #expect(decoded.id == entry.id)
    }
}

// MARK: - JournalViewModel Tests

@MainActor
struct JournalViewModelTests {
    @Test func addEntry() {
        let vm = JournalViewModel()
        let initialCount = vm.entries.count
        vm.addEntry(text: "テストエントリ")
        #expect(vm.entries.count == initialCount + 1)
        #expect(vm.entries.last?.text == "テストエントリ")
    }

    @Test func addEntryWithTags() {
        let vm = JournalViewModel()
        vm.addEntry(text: "タグ付きエントリ", tags: ["仕事", "メモ"])
        let last = vm.entries.last
        #expect(last?.tags == ["仕事", "メモ"])
    }

    @Test func addEntryRejectsEmpty() {
        let vm = JournalViewModel()
        let initialCount = vm.entries.count
        vm.addEntry(text: "")
        #expect(vm.entries.count == initialCount)
    }

    @Test func addEntryRejectsWhitespace() {
        let vm = JournalViewModel()
        let initialCount = vm.entries.count
        vm.addEntry(text: "   \n  ")
        #expect(vm.entries.count == initialCount)
    }

    @Test func addEntryTrimsWhitespace() {
        let vm = JournalViewModel()
        vm.addEntry(text: "  前後にスペース  ")
        #expect(vm.entries.last?.text == "前後にスペース")
    }

    @Test func updateEntry() {
        let vm = JournalViewModel()
        vm.addEntry(text: "元のテキスト")
        guard let entry = vm.entries.last else {
            Issue.record("エントリが追加されていない")
            return
        }
        vm.updateEntry(entry, newText: "更新後テキスト", newTags: ["更新"])
        let updated = vm.entries.first { $0.id == entry.id }
        #expect(updated?.text == "更新後テキスト")
        #expect(updated?.tags == ["更新"])
    }

    @Test func deleteEntry() {
        let vm = JournalViewModel()
        vm.addEntry(text: "削除対象")
        guard let entry = vm.entries.last else { return }
        vm.deleteEntry(entry)
        let deleted = vm.entries.first { $0.id == entry.id }
        #expect(deleted?.deletedAt != nil)
    }

    @Test func restoreEntry() {
        let vm = JournalViewModel()
        vm.addEntry(text: "復元対象")
        guard let entry = vm.entries.last else { return }
        vm.deleteEntry(entry)
        vm.restoreEntry(vm.entries.first { $0.id == entry.id }!)
        let restored = vm.entries.first { $0.id == entry.id }
        #expect(restored?.deletedAt == nil)
    }

    @Test func permanentlyDeleteEntry() {
        let vm = JournalViewModel()
        vm.addEntry(text: "完全削除対象")
        guard let entry = vm.entries.last else { return }
        let id = entry.id
        vm.permanentlyDeleteEntry(entry)
        #expect(vm.entries.contains { $0.id == id } == false)
    }

    @Test func deletedEntriesNotInAllEntries() {
        let vm = JournalViewModel()
        vm.addEntry(text: "通常エントリ")
        vm.addEntry(text: "削除エントリ")
        guard let toDelete = vm.entries.last else { return }
        vm.deleteEntry(toDelete)
        #expect(vm.allEntries.contains { $0.id == toDelete.id } == false)
        #expect(vm.deletedEntries.contains { $0.id == toDelete.id } == true)
    }

    @Test func addTag() {
        let vm = JournalViewModel()
        vm.addTag("新しいタグ")
        #expect(vm.availableTags.contains("新しいタグ"))
    }

    @Test func addDuplicateTag() {
        let vm = JournalViewModel()
        vm.addTag("重複タグ")
        let countBefore = vm.availableTags.count
        vm.addTag("重複タグ")
        #expect(vm.availableTags.count == countBefore)
    }

    @Test func removeTag() {
        let vm = JournalViewModel()
        vm.addTag("削除タグ")
        vm.removeTag("削除タグ")
        #expect(vm.availableTags.contains("削除タグ") == false)
    }

    @Test func renameTag() {
        let vm = JournalViewModel()
        vm.addTag("旧名")
        vm.addEntry(text: "エントリ", tags: ["旧名"])
        vm.renameTag("旧名", to: "新名")
        #expect(vm.availableTags.contains("新名"))
        #expect(vm.availableTags.contains("旧名") == false)
        let entry = vm.entries.last
        #expect(entry?.tags.contains("新名") == true)
    }

    @Test func searchByText() {
        let vm = JournalViewModel()
        vm.addEntry(text: "今日はカレーを食べた")
        vm.addEntry(text: "明日はラーメンにする")
        vm.searchText = "カレー"
        #expect(vm.searchResults.count >= 1)
        #expect(vm.searchResults.allSatisfy { $0.text.contains("カレー") })
    }

    @Test func searchByTag() {
        let vm = JournalViewModel()
        vm.addEntry(text: "運動日記", tags: ["運動"])
        vm.addEntry(text: "仕事日記", tags: ["仕事"])
        vm.selectedSearchTags = ["運動"]
        let results = vm.searchResults
        #expect(results.contains { $0.tags.contains("運動") })
    }

    @Test func weekDaysReturns7Days() {
        let vm = JournalViewModel()
        let days = vm.getWeekDays(offset: 0)
        #expect(days.count == 7)
    }

    @Test func jumpToDate() {
        let vm = JournalViewModel()
        let targetDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        vm.jumpToDate(targetDate)
        #expect(Calendar.current.isDate(vm.selectedDate, inSameDayAs: targetDate))
    }
}

// MARK: - TaskItem Tests

struct TaskItemTests {
    @Test func createTaskWithDefaults() {
        let task = TaskItem(title: "テストタスク")
        #expect(task.title == "テストタスク")
        #expect(task.isCompleted == false)
        #expect(task.deletedAt == nil)
        #expect(task.completedAt == nil)
        #expect(task.description == "")
    }

    @Test func taskCodable() throws {
        let task = TaskItem(
            title: "タスク",
            description: "説明",
            intent: "意図",
            achievementVision: "完了イメージ"
        )
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(TaskItem.self, from: data)
        #expect(decoded.title == "タスク")
        #expect(decoded.description == "説明")
        #expect(decoded.intent == "意図")
        #expect(decoded.achievementVision == "完了イメージ")
        #expect(decoded.id == task.id)
    }

    @Test func taskIdentifiable() {
        let task1 = TaskItem(title: "task1")
        let task2 = TaskItem(title: "task2")
        #expect(task1.id != task2.id)
    }
}

// MARK: - TaskViewModel Tests

@MainActor
struct TaskViewModelTests {
    @Test func addTask() {
        let vm = TaskViewModel()
        let initialCount = vm.tasks.count
        vm.addTask(title: "新しいタスク")
        #expect(vm.tasks.count == initialCount + 1)
        #expect(vm.tasks.last?.title == "新しいタスク")
    }

    @Test func addTaskRejectsEmpty() {
        let vm = TaskViewModel()
        let initialCount = vm.tasks.count
        vm.addTask(title: "")
        #expect(vm.tasks.count == initialCount)
    }

    @Test func addTaskRejectsWhitespace() {
        let vm = TaskViewModel()
        let initialCount = vm.tasks.count
        vm.addTask(title: "   ")
        #expect(vm.tasks.count == initialCount)
    }

    @Test func addTaskTrimsTitle() {
        let vm = TaskViewModel()
        vm.addTask(title: "  タスク名  ")
        #expect(vm.tasks.last?.title == "タスク名")
    }

    @Test func addTaskWithExtendedFields() {
        let vm = TaskViewModel()
        vm.addTask(
            title: "拡張タスク",
            description: "詳細",
            intent: "やりたいこと",
            achievementVision: "完成イメージ",
            notes: "メモ"
        )
        let task = vm.tasks.last
        #expect(task?.description == "詳細")
        #expect(task?.intent == "やりたいこと")
        #expect(task?.achievementVision == "完成イメージ")
        #expect(task?.notes == "メモ")
    }

    @Test func toggleCompletion() {
        let vm = TaskViewModel()
        vm.addTask(title: "完了テスト")
        guard let task = vm.tasks.last else { return }
        #expect(task.isCompleted == false)

        vm.toggleCompletion(task)
        let toggled = vm.tasks.first { $0.id == task.id }
        #expect(toggled?.isCompleted == true)
        #expect(toggled?.completedAt != nil)
    }

    @Test func toggleCompletionTwiceUncompletes() {
        let vm = TaskViewModel()
        vm.addTask(title: "トグルテスト")
        guard let task = vm.tasks.last else { return }
        vm.toggleCompletion(task)
        vm.toggleCompletion(vm.tasks.first { $0.id == task.id }!)
        let result = vm.tasks.first { $0.id == task.id }
        #expect(result?.isCompleted == false)
        #expect(result?.completedAt == nil)
    }

    @Test func updateTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "元のタイトル")
        guard let task = vm.tasks.last else { return }
        vm.updateTask(task, newTitle: "新しいタイトル", newDescription: "新しい説明")
        let updated = vm.tasks.first { $0.id == task.id }
        #expect(updated?.title == "新しいタイトル")
        #expect(updated?.description == "新しい説明")
    }

    @Test func updateTaskRejectsEmptyTitle() {
        let vm = TaskViewModel()
        vm.addTask(title: "元のタイトル")
        guard let task = vm.tasks.last else { return }
        vm.updateTask(task, newTitle: "", newDescription: "")
        let result = vm.tasks.first { $0.id == task.id }
        #expect(result?.title == "元のタイトル")
    }

    @Test func deleteTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "削除対象")
        guard let task = vm.tasks.last else { return }
        vm.deleteTask(task)
        let deleted = vm.tasks.first { $0.id == task.id }
        #expect(deleted?.deletedAt != nil)
    }

    @Test func restoreTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "復元対象")
        guard let task = vm.tasks.last else { return }
        vm.deleteTask(task)
        vm.restoreTask(vm.tasks.first { $0.id == task.id }!)
        let restored = vm.tasks.first { $0.id == task.id }
        #expect(restored?.deletedAt == nil)
    }

    @Test func permanentlyDeleteTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "完全削除対象")
        guard let task = vm.tasks.last else { return }
        let id = task.id
        vm.permanentlyDeleteTask(task)
        #expect(vm.tasks.contains { $0.id == id } == false)
    }

    @Test func incompleteTasksFiltering() {
        let vm = TaskViewModel()
        vm.addTask(title: "未完了1")
        vm.addTask(title: "未完了2")
        vm.addTask(title: "完了タスク")
        if let task = vm.tasks.last {
            vm.toggleCompletion(task)
        }
        let incomplete = vm.incompleteTasks
        #expect(incomplete.allSatisfy { !$0.isCompleted && $0.deletedAt == nil })
    }

    @Test func completedTasksFiltering() {
        let vm = TaskViewModel()
        vm.addTask(title: "完了タスク")
        guard let task = vm.tasks.last else { return }
        vm.toggleCompletion(task)
        let completed = vm.completedTasks
        #expect(completed.contains { $0.id == task.id })
        #expect(completed.allSatisfy { $0.isCompleted && $0.deletedAt == nil })
    }

    @Test func deletedTasksFiltering() {
        let vm = TaskViewModel()
        vm.addTask(title: "削除タスク")
        guard let task = vm.tasks.last else { return }
        vm.deleteTask(task)
        let deleted = vm.deletedTasks
        #expect(deleted.contains { $0.id == task.id })
        #expect(deleted.allSatisfy { $0.deletedAt != nil })
    }

    @Test func sortOrderAssignment() {
        let vm = TaskViewModel()
        vm.addTask(title: "タスクA")
        vm.addTask(title: "タスクB")
        vm.addTask(title: "タスクC")
        let incomplete = vm.incompleteTasks
        for i in 0..<incomplete.count - 1 {
            #expect(incomplete[i].sortOrder <= incomplete[i + 1].sortOrder)
        }
    }

    @Test func archiveCompletedTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "アーカイブ対象")
        guard let task = vm.tasks.last else { return }
        let id = task.id
        vm.toggleCompletion(task)
        vm.archiveTask(vm.tasks.first { $0.id == id }!)
        #expect(vm.tasks.contains { $0.id == id } == false)
        #expect(vm.archives.contains { archive in
            archive.completedTasks.contains { $0.id == id }
        })
    }

    @Test func archiveRejectsIncompleteTask() {
        let vm = TaskViewModel()
        vm.addTask(title: "未完了タスク")
        guard let task = vm.tasks.last else { return }
        let id = task.id
        vm.archiveTask(task)
        #expect(vm.tasks.contains { $0.id == id } == true)
    }
}

// MARK: - TaskArchive Tests

struct TaskArchiveTests {
    @Test func todayStartIsStartOfDay() {
        let todayStart = TaskArchive.todayStart
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: todayStart)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test func startOfDayForDate() {
        let now = Date()
        let start = TaskArchive.startOfDay(for: now)
        #expect(Calendar.current.isDate(start, inSameDayAs: now))
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: start)
        #expect(components.hour == 0)
    }

    @Test func archiveCodable() throws {
        let task = TaskItem(title: "完了タスク")
        let archive = TaskArchive(date: Date(), completedTasks: [task])
        let data = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(TaskArchive.self, from: data)
        #expect(decoded.completedTasks.count == 1)
        #expect(decoded.completedTasks.first?.title == "完了タスク")
    }
}

// MARK: - CoachSession Tests

struct CoachSessionTests {
    @Test func createSessionWithDefaults() {
        let session = CoachSession()
        #expect(session.messages.isEmpty)
        #expect(session.isActive == true)
        #expect(session.summary == nil)
        #expect(session.emotionLabel == nil)
    }

    @Test func firstUserMessage() {
        var session = CoachSession()
        session.messages.append(CoachMessage(role: .coach, content: "こんにちは"))
        session.messages.append(CoachMessage(role: .user, content: "今日は疲れた"))
        session.messages.append(CoachMessage(role: .user, content: "2つ目のメッセージ"))
        #expect(session.firstUserMessage == "今日は疲れた")
    }

    @Test func firstUserMessageNil() {
        var session = CoachSession()
        session.messages.append(CoachMessage(role: .coach, content: "こんにちは"))
        #expect(session.firstUserMessage == nil)
    }

    @Test func sessionCodable() throws {
        var session = CoachSession(summary: "テストセッション", emotionLabel: "嬉しい")
        session.messages.append(CoachMessage(role: .user, content: "テスト"))
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(CoachSession.self, from: data)
        #expect(decoded.summary == "テストセッション")
        #expect(decoded.emotionLabel == "嬉しい")
        #expect(decoded.messages.count == 1)
    }
}

// MARK: - CoachMessage Tests

struct CoachMessageTests {
    @Test func createMessage() {
        let message = CoachMessage(role: .user, content: "テストメッセージ")
        #expect(message.role == .user)
        #expect(message.content == "テストメッセージ")
        #expect(message.metadata == nil)
    }

    @Test func createMessageWithMetadata() {
        let metadata = MessageMetadata(
            cycleElement: "Root",
            emotionDetected: "安心",
            suggestedAction: nil
        )
        let message = CoachMessage(role: .coach, content: "応答", metadata: metadata)
        #expect(message.metadata?.cycleElement == "Root")
        #expect(message.metadata?.emotionDetected == "安心")
    }

    @Test func messageRoleCodable() throws {
        let user = MessageRole.user
        let coach = MessageRole.coach
        let userData = try JSONEncoder().encode(user)
        let coachData = try JSONEncoder().encode(coach)
        #expect(try JSONDecoder().decode(MessageRole.self, from: userData) == .user)
        #expect(try JSONDecoder().decode(MessageRole.self, from: coachData) == .coach)
    }
}

// MARK: - Date Extension Tests

struct DateExtensionTests {
    @Test func ymdStringFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 19
        let date = Calendar.current.date(from: components)!
        #expect(date.ymdString == "2026-03-19")
    }

    @Test func timeHMFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        components.hour = 14
        components.minute = 30
        let date = Calendar.current.date(from: components)!
        #expect(date.timeHM == "14:30")
    }
}

// MARK: - APIError Tests

struct APIErrorTests {
    @Test func errorDescriptions() {
        #expect(APIError.invalidURL.errorDescription != nil)
        #expect(APIError.invalidResponse.errorDescription != nil)
        #expect(APIError.unauthorized.errorDescription != nil)
        #expect(APIError.httpError(statusCode: 500, message: nil).errorDescription != nil)
        #expect(APIError.httpError(statusCode: 500, message: "サーバーエラー").errorDescription == "サーバーエラー")
        #expect(APIError.validationError("バリデーション失敗").errorDescription == "バリデーション失敗")
    }
}

// MARK: - APIEnvironment Tests

struct APIEnvironmentTests {
    @Test func developmentBaseURL() {
        let env = APIEnvironment.development
        #expect(env.baseURL.hasPrefix("https://"))
        #expect(env.baseURL.contains("run.app"))
    }

    @Test func productionBaseURL() {
        let env = APIEnvironment.production
        #expect(env.baseURL.hasPrefix("https://"))
    }
}

// MARK: - AuthState Tests

struct AuthStateTests {
    @Test func isAuthenticatedTrue() {
        let state = AuthState.authenticated(userId: "user123")
        #expect(state.isAuthenticated == true)
    }

    @Test func isAuthenticatedFalse() {
        #expect(AuthState.unauthenticated.isAuthenticated == false)
        #expect(AuthState.unknown.isAuthenticated == false)
    }

    @Test func equatable() {
        #expect(AuthState.unknown == AuthState.unknown)
        #expect(AuthState.unauthenticated == AuthState.unauthenticated)
        #expect(AuthState.authenticated(userId: "a") == AuthState.authenticated(userId: "a"))
        #expect(AuthState.authenticated(userId: "a") != AuthState.authenticated(userId: "b"))
    }
}

// MARK: - AuthUser Tests

struct AuthUserTests {
    @Test func codable() throws {
        let user = AuthUser(
            userId: "user1",
            appleUserId: "apple1",
            email: "test@example.com",
            fullName: "テスト太郎",
            createdAt: Date()
        )
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(AuthUser.self, from: data)
        #expect(decoded.userId == "user1")
        #expect(decoded.email == "test@example.com")
        #expect(decoded.fullName == "テスト太郎")
    }
}
