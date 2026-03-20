//
//  TestDataProvider.swift
//  Cycle
//

import Foundation

/// UIテスト用のテストデータ投入
///
/// `--uitesting` 起動引数が渡された場合のみ動作
/// 既存データをクリアし、テスト用の固定データを投入する
enum TestDataProvider {
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }

    /// テストデータを投入（既存データはクリア）
    @MainActor
    static func setupIfNeeded() {
        guard isUITesting else { return }
        clearAllData()
        insertJournalEntries()
        insertTasks()
    }

    /// デモデータ投入（CycleApp.init から同期的に呼ぶ）
    @MainActor
    static func setupSync() {
        guard isPreviewData else { return }
        clearAllData()
        insertJournalEntries()
        insertTasks()
    }

    // true にするとデモデータ投入（確認後 false に戻す）
    static var isPreviewData: Bool { false }

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
            TaskItem(title: "朝の瞑想を10分する", description: "マインドフルネス瞑想を試す", intent: "心を落ち着ける習慣をつけたい"),
            TaskItem(title: "週報を書く", description: "今週の振り返りと来週の計画", notes: "金曜日の夕方までに"),
            TaskItem(title: "読書30分", description: "嫌われる勇気の続きを読む"),
            TaskItem(title: "ジムに行く", description: "上半身トレーニング"),
            TaskItem(title: "部屋の掃除", description: "リビングと寝室"),
            TaskItem(title: "APIドキュメント更新", description: "OpenAPI specを最新にする"),
            TaskItem(title: "母に電話する", description: "週末の予定確認"),
            TaskItem(title: "レシピ調べる", description: "今週の作り置き用"),
            TaskItem(title: "歯医者の予約", description: "定期検診"),
            TaskItem(title: "プレゼン資料作成", description: "来週の社内共有用"),
        ]

        for i in tasks.indices {
            tasks[i].sortOrder = i
        }

        // 完了済みタスク
        let completedTitles = [
            ("企画書のレビュー", "3つの改善点を提案できた"),
            ("買い出し", "冷蔵庫が充実した"),
            ("ランニング5km", "ペースが安定してきた"),
        ]
        for (title, fact) in completedTitles {
            var t = TaskItem(title: title)
            t.isCompleted = true
            t.completedAt = Date().addingTimeInterval(-3600)
            t.fact = fact
            tasks.append(t)
        }

        JSONFileStore.save(tasks, to: "tasks.json")
    }
}
