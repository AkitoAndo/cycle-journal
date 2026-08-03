//
//  ScheduleStore.swift
//  Cycle
//
//  アプリ独自の予定のローカル永続化 + 状態管理
//

import Combine
import Foundation

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var events: [ScheduleEvent] = []

    private static let file = "schedules.json"

    init() {
        events = JSONFileStore.load(Self.file, as: [ScheduleEvent].self) ?? []
    }

    /// 指定日の予定（終日を先頭、以降は開始時刻順）
    func events(on date: Date) -> [ScheduleEvent] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
    }

    /// 予定のある日（記録ドット用）
    var recordedDays: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(events.map { calendar.dateComponents([.year, .month, .day], from: $0.startDate) })
    }

    func add(_ event: ScheduleEvent) {
        events.append(event)
        persist()
    }

    func update(_ event: ScheduleEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            persist()
        }
    }

    func delete(_ event: ScheduleEvent) {
        events.removeAll { $0.id == event.id }
        persist()
    }

    private func persist() {
        JSONFileStore.save(events, to: Self.file)
    }
}
