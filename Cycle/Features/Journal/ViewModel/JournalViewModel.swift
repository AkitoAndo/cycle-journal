//
//  JournalViewModel.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import Foundation
import Combine

/// ジャーナル機能のビジネスロジックとステート管理を担当
///
/// 主な責務:
/// - エントリの作成・編集・削除
/// - タグ管理
/// - 日付ベースのフィルタリング
/// - 検索機能
/// - 週カレンダーのナビゲーション
@MainActor
final class JournalViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 全てのジャーナルエントリ
    @Published private(set) var entries: [JournalEntry] = []

    /// ユーザーが作成した利用可能なタグ一覧
    @Published var availableTags: [String] = []

    /// 現在選択されている日付
    @Published var selectedDate: Date = Date()

    /// 現在の週のオフセット（0が今週）
    @Published var currentWeekOffset: Int = 0

    /// 検索テキスト
    @Published var searchText: String = ""

    /// 検索で選択されているタグ
    @Published var selectedSearchTags: [String] = []

    /// 検索モードかどうか
    @Published var isSearching: Bool = false

    // MARK: - Initialization

    init() {
        entries = JournalStore.loadAll()
        availableTags = loadAvailableTags()
    }

    // MARK: - Computed Properties

    /// 選択された日付のエントリ（新しい順）
    var todays: [JournalEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
               .sorted { $0.date > $1.date }
    }

    /// 検索条件に一致するエントリ（新しい順）
    var searchResults: [JournalEntry] {
        var results = entries

        if !searchText.isEmpty {
            results = results.filter { entry in
                entry.text.localizedCaseInsensitiveContains(searchText)
            }
        }

        if !selectedSearchTags.isEmpty {
            results = results.filter { entry in
                selectedSearchTags.contains { tag in
                    entry.tags.contains(tag)
                }
            }
        }

        return results.sorted { $0.date > $1.date }
    }

    /// 利用可能な全てのタグ（作成済み + エントリで使用中）
    var allTags: [String] {
        let entryTags = entries.flatMap { $0.tags }
        let combined = Set(availableTags + entryTags)
        return Array(combined).sorted()
    }

    // MARK: - Entry Management

    /// 新しいエントリを追加
    func addEntry(text: String, tags: [String] = []) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        entries.append(.init(text: trimmedText, tags: tags))
        persist()
    }

    /// エントリを削除
    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    /// エントリを更新
    func updateEntry(_ entry: JournalEntry, newText: String, newTags: [String]) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].text = newText
            entries[index].tags = newTags
            persist()
        }
    }

    // MARK: - Tag Management

    /// タグを追加
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !allTags.contains(trimmed) else { return }

        availableTags.append(trimmed)
        saveAvailableTags()
    }

    /// タグを削除（全てのエントリからも削除される）
    func removeTag(_ tag: String) {
        availableTags.removeAll { $0 == tag }

        // 全てのエントリからも削除
        for entry in entries where entry.tags.contains(tag) {
            let newTags = entry.tags.filter { $0 != tag }
            updateEntry(entry, newText: entry.text, newTags: newTags)
        }

        saveAvailableTags()
    }

    // MARK: - Date & Calendar Helpers

    /// 指定した日付にエントリが存在するか確認
    func hasEntries(on date: Date) -> Bool {
        entries.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Week Navigation Helpers

    /// 指定したオフセットの週の日付配列を取得（日曜始まり）
    /// - Parameter offset: 今週からのオフセット（0が今週、-1が先週、1が来週）
    /// - Returns: 7日分の日付配列
    func getWeekDays(offset: Int) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1

        let today = Date()
        let targetDate = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate)
        let sunday = calendar.date(from: components) ?? targetDate

        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: sunday)
        }
    }

    /// 現在の週オフセットに合わせて選択日を更新
    /// 選択日が現在の週に含まれていない場合、週の最初の日に設定
    func updateSelectedDateForCurrentWeek() {
        let currentWeek = getWeekDays(offset: currentWeekOffset)
        if !currentWeek.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
            if let firstDay = currentWeek.first {
                selectedDate = firstDay
            }
        }
    }

    /// 指定した日付にジャンプ（週オフセットも自動調整）
    func jumpToDate(_ date: Date) {
        selectedDate = date

        let today = Date()
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let targetComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)

        if let todayYear = todayComponents.yearForWeekOfYear,
           let todayWeek = todayComponents.weekOfYear,
           let targetYear = targetComponents.yearForWeekOfYear,
           let targetWeek = targetComponents.weekOfYear {
            let yearDiff = targetYear - todayYear
            let weekDiff = targetWeek - todayWeek
            currentWeekOffset = yearDiff * 52 + weekDiff
        }
    }

    // MARK: - Private Helpers

    /// エントリをストレージに保存
    private func persist() {
        JournalStore.saveAll(entries)
    }

    /// UserDefaultsから利用可能なタグを読み込み
    private func loadAvailableTags() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: "availableTags"),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }

    /// 利用可能なタグをUserDefaultsに保存
    private func saveAvailableTags() {
        if let data = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(data, forKey: "availableTags")
        }
    }
}
