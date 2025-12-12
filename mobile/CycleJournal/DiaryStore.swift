import Foundation

class DiaryStore: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var selectedTags: Set<String> = []
    @Published var searchText: String = ""
    @Published var selectedDate: Date? = nil
    @Published var availableTags: Set<String> = []
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "DiaryEntries"
    private let tagsKey = "AvailableTags"
    
    init() {
        loadEntries()
        loadTags()
    }
    
    func loadEntries() {
        if let data = userDefaults.data(forKey: entriesKey),
           let decodedEntries = try? JSONDecoder().decode([DiaryEntry].self, from: data) {
            entries = decodedEntries.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    func loadTags() {
        if let data = userDefaults.data(forKey: tagsKey),
           let decodedTags = try? JSONDecoder().decode(Set<String>.self, from: data) {
            availableTags = decodedTags
        }
    }
    
    func saveTags() {
        if let encodedData = try? JSONEncoder().encode(availableTags) {
            userDefaults.set(encodedData, forKey: tagsKey)
        }
    }
    
    func saveEntries() {
        if let encodedData = try? JSONEncoder().encode(entries) {
            userDefaults.set(encodedData, forKey: entriesKey)
        }
    }
    
    func addEntry(_ entry: DiaryEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
    }
    
    func updateEntry(_ entry: DiaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            entries.sort { $0.createdAt > $1.createdAt }
            saveEntries()
        }
    }
    
    func deleteEntry(_ entry: DiaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }
    
    var allTags: [String] {
        let entryTags = Set(entries.flatMap { $0.tags })
        let combinedTags = availableTags.union(entryTags)
        return Array(combinedTags).sorted()
    }
    
    var filteredEntries: [DiaryEntry] {
        var result = entries
        
        // 日付フィルタリング
        if let selectedDate = selectedDate {
            let calendar = Calendar.current
            result = result.filter { entry in
                calendar.isDate(entry.createdAt, inSameDayAs: selectedDate)
            }
        }
        
        // タグフィルタリング
        if !selectedTags.isEmpty {
            result = result.filter { entry in
                !Set(entry.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // 検索フィルタリング
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            result = result.filter { entry in
                entry.content.lowercased().contains(searchTerm) ||
                entry.tags.contains { $0.lowercased().contains(searchTerm) }
            }
        }
        
        return result
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    func clearTagFilter() {
        selectedTags.removeAll()
    }
    
    func setSelectedDate(_ date: Date?) {
        selectedDate = date
    }
    
    func clearDateFilter() {
        selectedDate = nil
    }
    
    func clearAllFilters() {
        selectedTags.removeAll()
        searchText = ""
        selectedDate = nil
    }
    
    func createTag(_ tagName: String) {
        let trimmedTag = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        guard !allTags.contains(trimmedTag) else { return }
        
        availableTags.insert(trimmedTag)
        saveTags()
    }
    
    func renameTag(from oldTag: String, to newTag: String) {
        guard !newTag.isEmpty && !allTags.contains(newTag) else { return }
        
        // 日記エントリのタグを更新
        for i in 0..<entries.count {
            if let index = entries[i].tags.firstIndex(of: oldTag) {
                entries[i].tags[index] = newTag
            }
        }
        
        // 利用可能タグを更新
        availableTags.remove(oldTag)
        availableTags.insert(newTag)
        
        // 選択中のタグも更新
        if selectedTags.contains(oldTag) {
            selectedTags.remove(oldTag)
            selectedTags.insert(newTag)
        }
        
        saveEntries()
        saveTags()
    }
    
    func deleteTag(_ tagName: String) {
        // 日記エントリからタグを削除
        for i in 0..<entries.count {
            entries[i].tags.removeAll { $0 == tagName }
        }
        
        // 利用可能タグからも削除
        availableTags.remove(tagName)
        
        // 選択中のタグからも削除
        selectedTags.remove(tagName)
        
        saveEntries()
        saveTags()
    }
}