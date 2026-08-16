//
//  MeditationStore.swift
//  CycleJournal
//

import Combine
import Foundation

class MeditationStore: ObservableObject {
    @Published var logs: [MeditationLog] = []

    private let userDefaults = UserDefaults.standard
    private var logsKey: String {
        UserDataScope.scopedDefaultsKey("MeditationLogs")
    }
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadLogs()
        NotificationCenter.default.publisher(for: .localDataScopeDidChange)
            .sink { [weak self] _ in self?.loadLogs() }
            .store(in: &cancellables)
    }
    
    func loadLogs() {
        let stored = userDefaults.data(forKey: logsKey)
        if let data = stored,
           let decoded = try? JSONDecoder().decode([MeditationLog].self, from: data) {
            logs = decoded.sorted { $0.date > $1.date }
        } else {
            logs = []
        }
    }

    func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            userDefaults.set(encoded, forKey: logsKey)
        }
    }

    func addLog(duration: Int) {
        let log = MeditationLog(duration: duration)
        logs.insert(log, at: 0)
        saveLogs()
    }

    func deleteLog(_ log: MeditationLog) {
        logs.removeAll { $0.id == log.id }
        saveLogs()
    }
}
