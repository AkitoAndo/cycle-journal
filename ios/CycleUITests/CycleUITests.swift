//
//  CycleUITests.swift
//  CycleUITests
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import XCTest

final class CycleUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Helper

    private func takeScreenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // docs/public/screenshots/ に直接保存
        let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let projectRoot = testDir.deletingLastPathComponent().deletingLastPathComponent()
        let screenshotsDir = projectRoot
            .appendingPathComponent("docs/public/screenshots")
        try? FileManager.default.createDirectory(
            at: screenshotsDir, withIntermediateDirectories: true
        )
        let fileURL = screenshotsDir.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
    }

    private func tapTab(_ name: String) {
        app.buttons["tab_\(name)"].tap()
    }

    private func waitAndTap(_ element: XCUIElement, timeout: TimeInterval = 3) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        element.tap()
    }

    private func openJournalMenu() {
        waitAndTap(app.buttons["journal_menu"])
    }

    private func openTaskMenu() {
        waitAndTap(app.buttons["task_menu"])
    }

    // MARK: - Journal Screenshots

    @MainActor
    func testScreenshots_Journal_01_List() {
        tapTab("Journal")
        let entryText = app.staticTexts["朝ランニングをした。空気が澄んでいて気持ちよかった。"]
        XCTAssertTrue(entryText.waitForExistence(timeout: 3))
        takeScreenshot("journal-list")
    }

    @MainActor
    func testScreenshots_Journal_02_NewEntry() {
        tapTab("Journal")
        waitAndTap(app.buttons["fab_plus"])
        takeScreenshot("journal-new")
    }

    @MainActor
    func testScreenshots_Journal_03_Search() {
        tapTab("Journal")
        openJournalMenu()
        waitAndTap(app.buttons["検索"])
        takeScreenshot("journal-search")
    }

    @MainActor
    func testScreenshots_Journal_04_TagManagement() {
        tapTab("Journal")
        openJournalMenu()
        waitAndTap(app.buttons["タグ管理"])
        takeScreenshot("journal-tags")
    }

    @MainActor
    func testScreenshots_Journal_05_Trash() {
        tapTab("Journal")
        openJournalMenu()
        waitAndTap(app.buttons["最近削除した項目"])
        takeScreenshot("journal-trash")
    }

    @MainActor
    func testScreenshots_Journal_06_Calendar() {
        tapTab("Journal")
        openJournalMenu()
        waitAndTap(app.buttons["日付選択"])
        takeScreenshot("journal-calendar")
    }

    // MARK: - Tasks Screenshots

    @MainActor
    func testScreenshots_Tasks_01_List() {
        tapTab("Tasks")
        let taskText = app.staticTexts["朝の瞑想を10分する"]
        XCTAssertTrue(taskText.waitForExistence(timeout: 3))
        takeScreenshot("task-list")
    }

    @MainActor
    func testScreenshots_Tasks_02_NewEntry() {
        tapTab("Tasks")
        waitAndTap(app.buttons["fab_plus"])
        takeScreenshot("task-new")
    }

    @MainActor
    func testScreenshots_Tasks_03_Reorder() {
        tapTab("Tasks")
        openTaskMenu()
        waitAndTap(app.buttons["並び替え"])
        takeScreenshot("task-reorder")
    }

    @MainActor
    func testScreenshots_Tasks_04_Archive() {
        tapTab("Tasks")
        openTaskMenu()
        waitAndTap(app.buttons["アーカイブ"])
        takeScreenshot("task-archive")
    }

    @MainActor
    func testScreenshots_Tasks_05_Trash() {
        tapTab("Tasks")
        openTaskMenu()
        waitAndTap(app.buttons["最近削除した項目"])
        takeScreenshot("task-trash")
    }

    // MARK: - Coach Screenshots

    @MainActor
    func testScreenshots_Coach_01_Home() {
        tapTab("Coach")
        takeScreenshot("coach-home")
    }

    // MARK: - Settings Screenshots

    @MainActor
    func testScreenshots_Settings_01_Main() {
        tapTab("Settings")
        takeScreenshot("settings")
    }

    // MARK: - Tab Overview

    @MainActor
    func testScreenshots_Tabs() {
        tapTab("Journal")
        takeScreenshot("tab-journal")

        tapTab("Coach")
        takeScreenshot("tab-coach")

        tapTab("Tasks")
        takeScreenshot("tab-tasks")

        tapTab("Settings")
        takeScreenshot("tab-settings")
    }

    // MARK: - Functional Tests

    @MainActor
    func testJournalCreateEntry() {
        tapTab("Journal")
        waitAndTap(app.buttons["fab_plus"])

        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 3))
        textView.tap()
        textView.typeText("UIテストから作成したエントリ")
        app.buttons["保存"].tap()

        let newEntry = app.staticTexts["UIテストから作成したエントリ"]
        XCTAssertTrue(newEntry.waitForExistence(timeout: 3))
    }

    @MainActor
    func testJournalCancelCreate() {
        tapTab("Journal")
        waitAndTap(app.buttons["fab_plus"])

        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 3))
        textView.tap()
        textView.typeText("キャンセルするエントリ")
        app.buttons["キャンセル"].tap()

        let entry = app.staticTexts["キャンセルするエントリ"]
        XCTAssertFalse(entry.exists)
    }

    @MainActor
    func testTaskCreateTask() {
        tapTab("Tasks")
        waitAndTap(app.buttons["fab_plus"])

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("UIテストから作成したタスク")
        app.buttons["保存"].tap()

        let newTask = app.staticTexts["UIテストから作成したタスク"]
        XCTAssertTrue(newTask.waitForExistence(timeout: 3))
    }

    @MainActor
    func testTaskCancelCreate() {
        tapTab("Tasks")
        waitAndTap(app.buttons["fab_plus"])

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("キャンセルするタスク")
        app.buttons["キャンセル"].tap()

        let task = app.staticTexts["キャンセルするタスク"]
        XCTAssertFalse(task.exists)
    }

    @MainActor
    func testTaskToggleCompletion() {
        tapTab("Tasks")
        let checkbox = app.images["circle"].firstMatch
        if checkbox.waitForExistence(timeout: 3) {
            checkbox.tap()
        }
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let perfApp = XCUIApplication()
            perfApp.launchArguments = ["--uitesting"]
            perfApp.launch()
        }
    }
}
