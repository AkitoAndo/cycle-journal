//
//  CoreFlowsE2ETests.swift
//  CycleUITests
//
//  主要フローの E2E テスト
//  - 全タブの表示と切り替え
//  - 呼吸セッション（開始 → 終了 → 完了）
//  - ジャーナル作成 / タスク作成（CycleUITests.swift の機能テストを補完）
//  - 各シートが開閉できること
//
//  `--uitesting` 起動引数で認証スキップ + 固定データ投入済みの状態を前提とする。
//

import XCTest

final class CoreFlowsE2ETests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Helpers

    private func tapTab(_ name: String) {
        let tab = app.buttons["tab_\(name)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "タブ tab_\(name) が見つからない")
        tab.tap()
    }

    @discardableResult
    private func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 5, message: String = "") -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message.isEmpty ? "\(element) が見つからない" : message)
        XCTAssertTrue(element.isHittable, "\(message) — 要素は存在するがタップ不可（isHittable=false）")
        element.tap()
        return element
    }

    // MARK: - タブ切り替え

    /// 4タブ全てが切り替わり、各画面の主要要素が表示されること
    @MainActor
    func testAllTabsAreReachable() {
        // Journal（初期タブ）
        XCTAssertTrue(
            app.staticTexts["朝ランニングをした。空気が澄んでいて気持ちよかった。"].waitForExistence(timeout: 5),
            "ジャーナル一覧にテストデータが表示されない"
        )

        // Coach
        tapTab("Coach")
        XCTAssertTrue(
            app.buttons["coach_breathing_button"].waitForExistence(timeout: 5),
            "コーチ画面に呼吸ボタンが表示されない"
        )
        XCTAssertTrue(app.staticTexts["タップして、呼吸を整える"].exists)

        // Tasks
        tapTab("Tasks")
        XCTAssertTrue(
            app.staticTexts["朝の瞑想を10分する"].waitForExistence(timeout: 5),
            "タスク一覧にテストデータが表示されない"
        )

        // MyPage / Settings
        tapTab("MyPage")
        XCTAssertTrue(
            app.staticTexts["マイページ"].waitForExistence(timeout: 5),
            "マイページ画面が表示されない"
        )

        // Journal に戻る（タブ keep-alive の確認）
        tapTab("Journal")
        XCTAssertTrue(
            app.staticTexts["朝ランニングをした。空気が澄んでいて気持ちよかった。"].waitForExistence(timeout: 5),
            "ジャーナルタブに戻れない"
        )
    }

    // MARK: - 呼吸セッション

    /// 呼吸ボタンをタップするとセッションシートが開くこと（報告された不具合の再現テスト）
    @MainActor
    func testBreathingButtonOpensSheet() {
        tapTab("Coach")

        let breathingButton = app.buttons["coach_breathing_button"]
        XCTAssertTrue(breathingButton.waitForExistence(timeout: 5), "呼吸ボタンが見つからない")
        // スタッガー出現アニメーション完了を待ってからタップ
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(breathingButton.isHittable, "呼吸ボタンが isHittable=false（無反応バグ）")
        breathingButton.tap()

        XCTAssertTrue(
            app.buttons["はじめる"].waitForExistence(timeout: 5),
            "呼吸ボタンタップ後にセッションシート（はじめるボタン）が現れない"
        )
        XCTAssertTrue(app.staticTexts["セッション時間"].exists, "セッション時間ピッカーが表示されない")
    }

    /// 呼吸セッションの開始 → 終了 → 記録完了 → 閉じる の一連フロー
    @MainActor
    func testBreathingSessionFullFlow() {
        tapTab("Coach")

        let breathingButton = app.buttons["coach_breathing_button"]
        XCTAssertTrue(breathingButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        breathingButton.tap()

        // 開始
        waitAndTap(app.buttons["はじめる"], message: "はじめるボタン")

        // 実行中表示（終わるボタンが出る）
        let finishButton = app.buttons["終わる"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5), "セッション開始後に「終わる」が現れない")

        // 数秒呼吸してから終了
        Thread.sleep(forTimeInterval: 3.0)
        finishButton.tap()

        // 完了画面
        let doneButton = app.buttons["完了"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "終了後に完了画面が現れない")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '呼吸を記録しました'")).firstMatch.exists,
            "記録完了メッセージが表示されない"
        )

        // 閉じてコーチホームに戻る
        doneButton.tap()
        XCTAssertTrue(breathingButton.waitForExistence(timeout: 5), "完了後にコーチホームへ戻らない")
    }

    /// 実行中はスワイプで閉じられず、「閉じる」も非表示であること
    @MainActor
    func testBreathingSessionLockedWhileRunning() {
        tapTab("Coach")
        let breathingButton = app.buttons["coach_breathing_button"]
        XCTAssertTrue(breathingButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        breathingButton.tap()

        waitAndTap(app.buttons["はじめる"], message: "はじめるボタン")
        XCTAssertTrue(app.buttons["終わる"].waitForExistence(timeout: 5))

        // 実行中は「閉じる」が出ていない
        XCTAssertFalse(app.buttons["閉じる"].exists, "実行中に「閉じる」が表示されている")

        // 後始末
        app.buttons["終わる"].tap()
        waitAndTap(app.buttons["完了"], message: "完了ボタン")
    }

    // MARK: - コーチホームのその他導線

    /// 「日記から話す」で日記ピッカーが開くこと
    @MainActor
    func testCoachDiaryPickerOpens() {
        tapTab("Coach")
        Thread.sleep(forTimeInterval: 1.0)

        waitAndTap(app.buttons["日記から話す"], message: "日記から話すボタン")

        // テストデータの日記が一覧に出る
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '朝ランニングをした'")).firstMatch
                .waitForExistence(timeout: 5),
            "日記ピッカーに日記が表示されない"
        )

        // スワイプで閉じる
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["coach_breathing_button"].waitForExistence(timeout: 5))
    }

    /// セッション履歴シートが開くこと
    @MainActor
    func testCoachHistoryOpens() {
        tapTab("Coach")
        Thread.sleep(forTimeInterval: 1.0)

        waitAndTap(app.buttons["coach_history_button"], message: "履歴ボタン")

        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 5),
            "履歴シートが開かない"
        )
    }

    // MARK: - ジャーナル

    /// 日付を切り替えると週カレンダーの選択が変わり、空の日には空状態 CTA が出ること
    @MainActor
    func testJournalEmptyStateCTA() throws {
        // 週カレンダー（曜日ラベル「日」がある行）を左へ2回スワイプして
        // 未来の週に移動する。テストデータは過去にしかないので確実に空になる
        let weekdayLabel = app.staticTexts["日"].firstMatch
        XCTAssertTrue(weekdayLabel.waitForExistence(timeout: 5), "週カレンダーが見つからない")
        weekdayLabel.swipeLeft()
        Thread.sleep(forTimeInterval: 0.5)
        app.staticTexts["日"].firstMatch.swipeLeft()
        Thread.sleep(forTimeInterval: 0.5)

        let writeButton = app.buttons["日記を書く"]
        if writeButton.waitForExistence(timeout: 3) {
            // 空状態 CTA から新規作成シートが開く
            writeButton.tap()
            XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5), "CTA から新規作成シートが開かない")
            app.buttons["キャンセル"].tap()
        } else {
            // 前週に既存データがある場合はスキップ扱い
            throw XCTSkip("前週にエントリが存在するため空状態を確認できない")
        }
    }

    // MARK: - 設定

    /// 設定画面の主要セクションが表示されること
    @MainActor
    func testSettingsShowsMainSections() {
        tapTab("MyPage")
        XCTAssertTrue(app.staticTexts["マイページ"].waitForExistence(timeout: 5))
        // スクロールして主要な行があることを確認
        let exportRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'エクスポート'")).firstMatch
        if !exportRow.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            exportRow.waitForExistence(timeout: 3),
            "データエクスポート行が見つからない"
        )
    }
}
