//
//  SessionHistoryView.swift
//  CycleJournal
//

import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var meditationStore: MeditationStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab = 0
    @State private var selectedSession: CoachSession?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: { selectedTab = 0 }) {
                            Text("対話")
                                .font(.system(size: DesignSystem.FontSize.body, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 0 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }

                        Button(action: { selectedTab = 1 }) {
                            Text("瞑想")
                                .font(.system(size: DesignSystem.FontSize.body, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundStyle(selectedTab == 1 ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }
                    }

                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(selectedTab == 0 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                                .frame(width: geometry.size.width / 2, height: selectedTab == 0 ? 2 : 0.5)

                            Rectangle()
                                .fill(selectedTab == 1 ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                                .frame(width: geometry.size.width / 2, height: selectedTab == 1 ? 2 : 0.5)
                        }
                    }
                    .frame(height: 2)
                }

                if selectedTab == 0 {
                    conversationList
                } else {
                    meditationList
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
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
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
                    .environmentObject(coachStore)
            }
        }
    }

    // MARK: - Conversation List

    @ViewBuilder
    private var conversationList: some View {
        if coachStore.sessions.isEmpty {
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: "対話履歴がありません"
            )
        } else {
            List {
                ForEach(coachStore.sessions) { session in
                    Button(action: { selectedSession = session }) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                    .customListRowStyle()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            coachStore.deleteSession(session)
                        } label: {
                            Label("削除", systemImage: "trash")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Meditation List

    @ViewBuilder
    private var meditationList: some View {
        if meditationStore.logs.isEmpty {
            EmptyStateView(
                icon: "timer",
                title: "瞑想履歴がありません"
            )
        } else {
            List {
                ForEach(meditationStore.logs) { log in
                    MeditationRowView(log: log)
                        .customListRowStyle()
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                meditationStore.deleteLog(log)
                            } label: {
                                Label("削除", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Meditation Row

struct MeditationRowView: View {
    let log: MeditationLog

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("\(log.durationText)の瞑想")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(dateFormatter.string(from: log.date))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()
            }
        }
    }
}
