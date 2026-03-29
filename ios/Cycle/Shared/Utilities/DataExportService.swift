//
//  DataExportService.swift
//  Cycle
//
//  Created for CycleJournal data export feature.
//

import Foundation

/// エクスポート形式
enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}

/// エクスポート用のラッパー構造体
struct CycleJournalExport: Codable {
    let metadata: ExportMetadata
    let journals: [JournalEntry]
    let tasks: [TaskItem]
    let archives: [TaskArchive]
    let sessions: [CoachSessionExport]
}

/// エクスポートメタデータ
struct ExportMetadata: Codable {
    let exportDate: Date
    let appVersion: String
    let format: String
}

/// CoachSession のエクスポート用構造体（CoachSession は Codable 準拠済みだが明示的に定義）
struct CoachSessionExport: Codable {
    let id: UUID
    let messages: [CoachMessageExport]
    let createdAt: Date
    let updatedAt: Date
    let summary: String?
    let emotionLabel: String?

    init(from session: CoachSession) {
        self.id = session.id
        self.messages = session.messages.map { CoachMessageExport(from: $0) }
        self.createdAt = session.createdAt
        self.updatedAt = session.updatedAt
        self.summary = session.summary
        self.emotionLabel = session.emotionLabel
    }
}

struct CoachMessageExport: Codable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date

    init(from message: CoachMessage) {
        self.id = message.id
        self.role = message.role.rawValue
        self.content = message.content
        self.createdAt = message.createdAt
    }
}

/// データエクスポートサービス
enum DataExportService {

    // MARK: - JSON Export

    static func exportJSON(
        journals: [JournalEntry],
        tasks: [TaskItem],
        archives: [TaskArchive],
        sessions: [CoachSession]
    ) -> Data {
        let filteredJournals = journals.filter { $0.deletedAt == nil }
        let filteredTasks = mergedTasks(active: tasks, archives: archives)
        let filteredArchives = archives
        let sessionExports = sessions.map { CoachSessionExport(from: $0) }

        let export = CycleJournalExport(
            metadata: ExportMetadata(
                exportDate: Date(),
                appVersion: appVersion,
                format: "json"
            ),
            journals: filteredJournals,
            tasks: filteredTasks,
            archives: filteredArchives,
            sessions: sessionExports
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        return (try? encoder.encode(export)) ?? Data()
    }

    // MARK: - CSV Export

    static func exportCSV(
        journals: [JournalEntry],
        tasks: [TaskItem],
        archives: [TaskArchive],
        sessions: [CoachSession]
    ) -> Data {
        var csv = "\u{FEFF}" // UTF-8 BOM for Excel compatibility

        let filteredJournals = journals.filter { $0.deletedAt == nil }
        let filteredTasks = mergedTasks(active: tasks, archives: archives)
        let dateFormatter = ISO8601DateFormatter()

        // ジャーナルセクション
        csv += "# ジャーナル\n"
        csv += "ID,日付,本文,タグ\n"
        for entry in filteredJournals {
            csv += "\(csvEscape(entry.id.uuidString)),"
            csv += "\(csvEscape(dateFormatter.string(from: entry.date))),"
            csv += "\(csvEscape(entry.text)),"
            csv += "\(csvEscape(entry.tags.joined(separator: "; ")))\n"
        }

        csv += "\n"

        // タスクセクション
        csv += "# タスク\n"
        csv += "ID,タイトル,説明,完了,作成日,完了日,意図,完了イメージ,注意点,事実,気づき,次の一手\n"
        for task in filteredTasks {
            csv += "\(csvEscape(task.id.uuidString)),"
            csv += "\(csvEscape(task.title)),"
            csv += "\(csvEscape(task.description)),"
            csv += "\(task.isCompleted ? "はい" : "いいえ"),"
            csv += "\(csvEscape(dateFormatter.string(from: task.createdAt))),"
            csv += "\(csvEscape(task.completedAt.map { dateFormatter.string(from: $0) } ?? "")),"
            csv += "\(csvEscape(task.intent)),"
            csv += "\(csvEscape(task.achievementVision)),"
            csv += "\(csvEscape(task.notes)),"
            csv += "\(csvEscape(task.fact)),"
            csv += "\(csvEscape(task.insight)),"
            csv += "\(csvEscape(task.nextAction))\n"
        }

        csv += "\n"

        // アーカイブセクション
        csv += "# タスクアーカイブ\n"
        csv += "ID,日付,完了タスク数,作成日\n"
        for archive in archives {
            csv += "\(csvEscape(archive.id.uuidString)),"
            csv += "\(csvEscape(dateFormatter.string(from: archive.date))),"
            csv += "\(archive.completedTasks.count),"
            csv += "\(csvEscape(dateFormatter.string(from: archive.createdAt)))\n"
        }

        csv += "\n"

        // コーチセッションセクション
        csv += "# コーチセッション\n"
        csv += "セッションID,作成日,更新日,サマリー,感情ラベル,メッセージ数\n"
        for session in sessions {
            csv += "\(csvEscape(session.id.uuidString)),"
            csv += "\(csvEscape(dateFormatter.string(from: session.createdAt))),"
            csv += "\(csvEscape(dateFormatter.string(from: session.updatedAt))),"
            csv += "\(csvEscape(session.summary ?? "")),"
            csv += "\(csvEscape(session.emotionLabel ?? "")),"
            csv += "\(session.messages.count)\n"
        }

        csv += "\n"

        // コーチメッセージセクション
        csv += "# コーチメッセージ\n"
        csv += "セッションID,メッセージID,役割,内容,日時\n"
        for session in sessions {
            for message in session.messages {
                csv += "\(csvEscape(session.id.uuidString)),"
                csv += "\(csvEscape(message.id.uuidString)),"
                csv += "\(csvEscape(message.role.rawValue)),"
                csv += "\(csvEscape(message.content)),"
                csv += "\(csvEscape(dateFormatter.string(from: message.createdAt)))\n"
            }
        }

        return csv.data(using: .utf8) ?? Data()
    }

    // MARK: - File Creation

    static func createTemporaryFile(data: Data, format: ExportFormat) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "CycleJournal_Export_\(dateString).\(format.fileExtension)"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing export file: \(error)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// アクティブタスクとアーカイブタスクをマージ（重複排除）
    private static func mergedTasks(active: [TaskItem], archives: [TaskArchive]) -> [TaskItem] {
        var taskMap: [UUID: TaskItem] = [:]

        // アーカイブのタスクを先に追加
        for archive in archives {
            for task in archive.completedTasks {
                if task.deletedAt == nil {
                    taskMap[task.id] = task
                }
            }
        }

        // アクティブタスクで上書き（最新状態を優先）
        for task in active {
            if task.deletedAt == nil {
                taskMap[task.id] = task
            }
        }

        return Array(taskMap.values).sorted { $0.createdAt < $1.createdAt }
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
