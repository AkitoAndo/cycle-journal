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
            Group {
                if coachStore.sessions.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "会話履歴がありません",
                        subtitle: "コーチと会話を始めると、ここに履歴が表示されます"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(coachStore.sessions) { session in
                                SessionRowView(session: session)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .task {
                await coachStore.fetchServerSessions()
            }
        }
    }
}
