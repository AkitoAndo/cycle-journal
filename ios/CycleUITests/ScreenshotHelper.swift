//
//  ScreenshotHelper.swift
//  CycleUITests
//
//  スクリーンショットを docs/public/screenshots/ に直接保存するヘルパー
//

import XCTest

enum ScreenshotHelper {
    /// スクリーンショットを撮影し、docs/public/screenshots/ に保存する
    ///
    /// - Parameters:
    ///   - app: XCUIApplication
    ///   - name: ファイル名（拡張子なし）。例: "journal-list"
    ///   - testCase: XCTestCase（XCTAttachment 追加用）
    static func capture(_ app: XCUIApplication, name: String, in testCase: XCTestCase) {
        // アニメーション完了を待つ
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = app.windows.firstMatch.screenshot()

        // テスト結果にも添付（Xcode で確認できるように）
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)

        // docs/public/screenshots/ に直接保存
        saveToDocsDirectory(screenshot: screenshot, name: name)
    }

    private static func saveToDocsDirectory(screenshot: XCUIScreenshot, name: String) {
        // プロジェクトルートの docs/public/screenshots/ を探す
        guard let docsDir = findDocsScreenshotsDir() else {
            print("⚠️ docs/public/screenshots/ が見つかりません。XCTAttachment のみ保存します。")
            return
        }

        let fileURL = docsDir.appendingPathComponent("\(name).png")
        let pngData = screenshot.pngRepresentation

        do {
            try pngData.write(to: fileURL)
            print("📸 Screenshot saved: \(fileURL.path)")
        } catch {
            print("⚠️ Screenshot save failed: \(error.localizedDescription)")
        }
    }

    private static func findDocsScreenshotsDir() -> URL? {
        // __FILE__ からプロジェクトルートを辿る
        // CycleUITests/ → ios/ → project-root/
        let testFileDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let iosDir = testFileDir.deletingLastPathComponent()
        let projectRoot = iosDir.deletingLastPathComponent()
        let screenshotsDir = projectRoot
            .appendingPathComponent("docs")
            .appendingPathComponent("public")
            .appendingPathComponent("screenshots")

        // ディレクトリが存在しなければ作成
        let fm = FileManager.default
        if !fm.fileExists(atPath: screenshotsDir.path) {
            try? fm.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        }

        return fm.fileExists(atPath: screenshotsDir.path) ? screenshotsDir : nil
    }
}
