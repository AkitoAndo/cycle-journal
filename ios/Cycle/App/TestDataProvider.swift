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
            UserDataScope.activate(userID: "ui-test-user")
            // UIテスト: オンボーディング・データをリセットして既知の状態にする
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            clearAllData()
            insertJournalEntries()
            insertTasks()
            insertHomeActivity()
            return
        }

        #if DEBUG
        if APIClient.debugAuthBypass {
            UserDataScope.activate(userID: "debug-user")
        }
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
        UserDefaults.standard.removeObject(
            forKey: UserDataScope.scopedDefaultsKey("availableTags")
        )
        // コーチセッション（過去セッションが残っていると表示が不定になる）
        UserDefaults.standard.removeObject(
            forKey: UserDataScope.scopedDefaultsKey("CoachSessions")
        )
        UserDefaults.standard.removeObject(
            forKey: UserDataScope.scopedDefaultsKey("MeditationLogs")
        )
        JSONFileStore.save([ScheduleEvent](), to: "schedules.json")
    }

    // MARK: - Journal

    private static func insertJournalEntries() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let tags = ["気づき", "感謝", "運動", "仕事", "読書"]
        if let data = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(
                data,
                forKey: UserDataScope.scopedDefaultsKey("availableTags")
            )
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
        var reflectionTask = TaskItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            title: "会議前に伝えたいことを3行で書く",
            description: "明日のチームミーティング"
        )
        reflectionTask.intent = "考えを落ち着いて伝えるため"
        reflectionTask.achievementVision = "要点を短く、自分の言葉で話せる"
        reflectionTask.notes = "結論から書く"
        reflectionTask.fact = "要点を先に話すと、落ち着いて伝えられた"
        reflectionTask.insight = "3行の準備があるだけで、不安が小さくなった"
        reflectionTask.nextAction = "次回も前日に3行メモを作る"

        var tasks: [TaskItem] = [
            reflectionTask,
            TaskItem(title: "朝の瞑想を10分する", description: "一日の始まりに呼吸を整える"),
            TaskItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
                title: "週報を10分で振り返る",
                description: "今週の気づきをひとつ残す"
            ),
            TaskItem(title: "母に電話する", description: "週末の予定を聞く"),
            TaskItem(title: "本を10ページ読む", description: "眠る前の静かな時間に"),
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

    // MARK: - Home

    private static func insertHomeActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sessionDate = today.addingTimeInterval(17 * 3600 + 30 * 60)
        let session = CoachSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            messages: [
                CoachMessage(
                    role: .user,
                    content: "会議で伝えたいことを、うまく整理できるか不安。",
                    createdAt: sessionDate
                ),
                CoachMessage(
                    role: .coach,
                    content: "いちばん伝えたいことを、一文にするとしたら？",
                    createdAt: sessionDate.addingTimeInterval(60)
                ),
            ],
            createdAt: sessionDate,
            updatedAt: sessionDate.addingTimeInterval(60),
            summary: "会議で伝えたいことを整理する",
            emotionLabel: "少し不安",
            isActive: false
        )
        if let data = try? JSONEncoder().encode([session]) {
            UserDefaults.standard.set(
                data,
                forKey: UserDataScope.scopedDefaultsKey("CoachSessions")
            )
        }

        let meditation = MeditationLog(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            date: today.addingTimeInterval(7 * 3600),
            duration: 60
        )
        if let data = try? JSONEncoder().encode([meditation]) {
            UserDefaults.standard.set(
                data,
                forKey: UserDataScope.scopedDefaultsKey("MeditationLogs")
            )
        }

        let schedules = [
            ScheduleEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
                title: "朝の散歩",
                startDate: today.addingTimeInterval(7 * 3600 + 30 * 60),
                endDate: today.addingTimeInterval(8 * 3600)
            ),
            ScheduleEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
                title: "チームミーティング",
                startDate: today.addingTimeInterval(10 * 3600),
                endDate: today.addingTimeInterval(10 * 3600 + 30 * 60)
            ),
        ]
        JSONFileStore.save(schedules, to: "schedules.json")
    }
}
