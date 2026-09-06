//
//  JournalService.swift
//  CycleJournal
//

import Foundation

protocol JournalSyncing {
    func sync(
        entries: [JournalEntry],
        deletedEntryIds: [UUID],
        lastPulledAt: Date?
    ) async throws -> JournalSyncData
}

class JournalService: JournalSyncing {
    private let apiClient = APIClient.shared

    func sync(
        entries: [JournalEntry],
        deletedEntryIds: [UUID],
        lastPulledAt: Date?
    ) async throws -> JournalSyncData {
        let request = JournalSyncRequest(
            journals: entries.map(JournalSyncItem.init(entry:)),
            deletedJournalIds: deletedEntryIds.map(\.uuidString),
            lastPulledAt: lastPulledAt
        )

        let response: APIResponse<JournalSyncData> = try await apiClient.post(
            path: "/journals/sync",
            body: request,
            requiresAuth: true
        )
        return response.data
    }
}

extension JournalSyncItem {
    init(entry: JournalEntry) {
        journalId = entry.id.uuidString
        text = entry.text
        tags = entry.tags
        entryDate = entry.date
        deletedAt = entry.deletedAt
        createdAt = entry.date
        updatedAt = entry.updatedAt ?? entry.syncUpdatedAt
    }
}

extension JournalEntry {
    init(apiData: JournalData) {
        id = UUID(uuidString: apiData.journalId) ?? UUID()
        date = apiData.entryDate
        text = apiData.text
        tags = apiData.tags
        deletedAt = apiData.deletedAt
        updatedAt = apiData.updatedAt
    }
}
