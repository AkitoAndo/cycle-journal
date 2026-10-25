//
//  WeeklyReviewWeek.swift
//  Cycle
//
//  週のふりかえり（U-03）の「週」の範囲と、コーチに渡す材料の組み立て。
//  週は「ふりかえり日の翌日 〜 ふりかえり日」とする（ふりかえり日が日曜なら月〜日）。
//

import Foundation

struct WeeklyReviewWeek: Equatable {
    /// ふりかえり日の曜日（Calendar の weekday: 1=日曜 … 7=土曜）。設定での変更は U-03 実装単位4で対応
    static let defaultReviewWeekday = 1

    /// 週の初日（0時）
    let start: Date
    /// 週の最終日＝ふりかえり日（0時）
    let reviewDay: Date

    /// date を含む週を返す
    init(containing date: Date, reviewWeekday: Int = defaultReviewWeekday, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysUntilReview = (reviewWeekday - weekday + 7) % 7
        reviewDay = calendar.date(byAdding: .day, value: daysUntilReview, to: day) ?? day
        start = calendar.date(byAdding: .day, value: -6, to: reviewDay) ?? day
    }

    /// 来週の初日（ふりかえり日の翌日、0時）。「来週の一歩」はこの日のタスクになる
    func nextWeekStart(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: reviewDay) ?? reviewDay
    }

    /// 週の7日間（初日から順）
    func days(calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= start && day <= reviewDay
    }

    /// date がふりかえり日当日か
    func isReviewDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: reviewDay)
    }

    /// 「10月19日(月)〜10月25日(日)」
    var rangeText: String {
        "\(Self.dayText(start))〜\(Self.dayText(reviewDay))"
    }

    static func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }

    /// コーチに渡す材料の文を組み立てる。何も選ばれていなければ nil
    func material(journals: [JournalEntry], completedTasks: [TaskItem]) -> String? {
        guard !journals.isEmpty || !completedTasks.isEmpty else { return nil }

        var lines = ["今週（\(rangeText)）のふりかえりの材料です。"]
        if !journals.isEmpty {
            lines.append("")
            lines.append("【日記】")
            for entry in journals.sorted(by: { $0.date < $1.date }) {
                lines.append("・\(Self.dayText(entry.date)) \(entry.text)")
            }
        }
        if !completedTasks.isEmpty {
            lines.append("")
            lines.append("【完了したタスク】")
            for task in completedTasks {
                let insight = task.insight.trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append(insight.isEmpty ? "・\(task.title)" : "・\(task.title)（気づき: \(insight)）")
            }
        }
        return lines.joined(separator: "\n")
    }
}
