//
//  SessionHistoryView.swift
//  CycleJournal
//

import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject var coachStore: CoachStore
    @Environment(\.dismiss) var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if coachStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "会話履歴がありません",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("コーチと会話を始めると、ここに履歴が表示されます")
                    )
                } else {
                    ForEach(coachStore.sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: session.createdAt))
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(.secondary)

                            Text(session.summary ?? session.firstUserMessage ?? "会話")
                                .font(DesignSystem.Fonts.body)
                                .lineLimit(2)

                            if let emotion = session.emotionLabel {
                                Text(emotion)
                                    .font(DesignSystem.Fonts.caption)
                                    .foregroundStyle(DesignSystem.Colors.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .task {
                await coachStore.fetchServerSessions()
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = coachStore.sessions[index]
            coachStore.deleteSession(session)
        }
    }
}
