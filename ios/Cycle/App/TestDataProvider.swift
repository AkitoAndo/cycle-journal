//
//  TestDataProvider.swift
//  Cycle
//

import Foundation

/// テストデータ投入
///
/// - `--uitesting` 起動引数: 既存データをクリアして固定データを投入
/// - DEBUG ビルド: データが空の場合のみサンプルデータを投入
enum TestDataProvider {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    /// テストデータを投入
    @MainActor
    static func setupIfNeeded() {
        if isUITesting {
            // UIテスト: クリアして再投入
            clearAllData()
            insertJournalEntries()
            insertTasks()
            return
        }

        #if DEBUG
        // DEBUGビルド: データが空の場合のみサンプルデータを投入
        let journals = JSONFileStore.load("journals.json", as: [JournalEntry].self)
        let tasks = JSONFileStore.load("tasks.json", as: [TaskItem].self)
        let isEmpty = (journals ?? []).isEmpty && (tasks ?? []).isEmpty

        if isEmpty {
            insertJournalEntries()
            insertTasks()
        }
        #endif
    }

    // MARK: - Clear

    private static func clearAllData() {
        // ジャーナル
        JSONFileStore.save([JournalEntry](), to: "journals.json")
        // タスク
        JSONFileStore.save([TaskItem](), to: "tasks.json")
        JSONFileStore.save([TaskArchive](), to: "task_archives.json")
        // タグ
        UserDefaults.standard.removeObject(forKey: "availableTags")
    }

    // MARK: - Journal

    private static func insertJournalEntries() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let tags = ["気づき", "感謝", "運動", "仕事", "読書"]
        if let data = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(data, forKey: "availableTags")
        }

        let entries: [JournalEntry] = [
            JournalEntry(
                date: today.addingTimeInterval(8 * 3600),
                text: "朝ランニングをした。空気が澄んでいて気持ちよかった。",
                tags: ["運動", "気づき"]
            ),
            JournalEntry(
                date: today.addingTimeInterval(12 * 3600),
                text: "同僚とランチに行った。新しいプロジェクトの話で盛り上がった。",
                tags: ["仕事", "感謝"]
            ),
            JournalEntry(
                date: today.addingTimeInterval(-86400 + 20 * 3600),
                text: "夜に読書をした。「嫌われる勇気」を読み始めた。自分の価値観について考えさせられた。",
                tags: ["読書", "気づき"]
            ),
            JournalEntry(
                date: today.addingTimeInterval(-86400 * 2 + 9 * 3600),
                text: "週末にカフェで作業した。集中できる環境を見つけることの大切さを実感。",
                tags: ["仕事"]
            ),
            JournalEntry(
                date: today.addingTimeInterval(-86400 * 3 + 18 * 3600),
                text: "友人と電話で話した。久しぶりに笑い合えて元気が出た。",
                tags: ["感謝"]
            ),
        ]

        JSONFileStore.save(entries, to: "journals.json")
    }

    // MARK: - Tasks

    private static func insertTasks() {
        var tasks: [TaskItem] = [
            TaskItem(
                title: "朝の瞑想を10分する",
                description: "マインドフルネス瞑想を試す",
                intent: "心を落ち着ける習慣をつけたい",
                achievementVision: "毎朝穏やかな気持ちでスタートできる"
            ),
            TaskItem(
                title: "週報を書く",
                description: "今週の振り返りと来週の計画",
                intent: "自分の進捗を可視化する",
                notes: "金曜日の夕方までに"
            ),
            TaskItem(
                title: "読書30分",
                description: "嫌われる勇気の続きを読む"
            ),
        ]

        for i in tasks.indices {
            tasks[i].sortOrder = i
        }

        // 1つ完了済みタスク
        var completedTask = TaskItem(
            title: "企画書のレビュー",
            description: "チームメンバーの企画書にフィードバック"
        )
        completedTask.isCompleted = true
        completedTask.completedAt = Date().addingTimeInterval(-3600)
        completedTask.fact = "3つの改善点を提案できた"
        completedTask.insight = "具体的な例を添えるとフィードバックが伝わりやすい"
        completedTask.nextAction = "次回はもっと早めにレビューする"
        tasks.append(completedTask)

        JSONFileStore.save(tasks, to: "tasks.json")
    }
}
