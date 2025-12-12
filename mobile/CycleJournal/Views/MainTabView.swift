//
//  MainTabView.swift
//  CycleJournal
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authStore: AuthStore

    @StateObject private var diaryStore = DiaryStore()
    @StateObject private var coachStore = CoachStore()
    @StateObject private var taskStore = TaskStore()

    @State private var selectedTab: Tab = .diary

    enum Tab {
        case diary
        case coach
        case tasks
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 日記タブ
            DiaryListView()
                .environmentObject(diaryStore)
                .tabItem {
                    Label("日記", systemImage: "book")
                }
                .tag(Tab.diary)

            // コーチタブ
            CoachHomeView()
                .environmentObject(coachStore)
                .environmentObject(diaryStore)
                .tabItem {
                    Label("コーチ", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(Tab.coach)

            // タスクタブ
            TaskListView()
                .environmentObject(taskStore)
                .environmentObject(coachStore)
                .tabItem {
                    Label("タスク", systemImage: taskTabIcon)
                }
                .tag(Tab.tasks)

            // 設定タブ
            SettingsView()
                .environmentObject(authStore)
                .environmentObject(diaryStore)
                .environmentObject(taskStore)
                .environmentObject(coachStore)
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }

    /// タスクタブのアイコン（未完了タスクがあれば表示を変える）
    private var taskTabIcon: String {
        taskStore.pendingTasks.isEmpty ? "checkmark.circle" : "checkmark.circle.badge.questionmark"
    }
}

#Preview {
    MainTabView()
}
