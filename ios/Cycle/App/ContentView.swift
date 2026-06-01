//
//  ContentView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var coachStore: CoachStore
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var taskViewModel: TaskViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            switch authStore.state {
            case .unknown:
                splashView
            case .unauthenticated:
                SignInView()
            case .authenticated:
                mainContent
            }
        }
    }

    private var splashView: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            ProgressView()
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        JournalListView()
                    }
                case 1:
                    NavigationStack {
                        CoachHomeView()
                    }
                case 2:
                    NavigationStack {
                        TaskListView()
                    }
                case 3:
                    SettingsView()
                default:
                    NavigationStack {
                        JournalListView()
                    }
                }
            }
            .padding(.bottom, 55)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCoachChat)) { _ in
            selectedTab = 1
            coachStore.shouldOpenChat = true
        }
        .ignoresSafeArea(.keyboard)
        .overlay {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "leaf",
                selectedIcon: "leaf.fill",
                label: "ジャーナル",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )

            TabBarButton(
                icon: "bubble.left.and.bubble.right",
                selectedIcon: "bubble.left.and.bubble.right.fill",
                label: "セッション",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )

            TabBarButton(
                icon: "checklist",
                selectedIcon: "checklist.checked",
                label: "タスクリスト",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )

            TabBarButton(
                icon: "gearshape",
                selectedIcon: "gearshape.fill",
                label: "設定",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .frame(height: 55)
        .background(DesignSystem.Colors.background)
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: DesignSystem.FontSize.title3))

                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("tab_\(label)")
    }
}

// MARK: - Placeholders

private struct CoachView_Placeholder: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Coach MVP").font(DesignSystem.Fonts.sectionTitle)
                Text("ここにコーチ画面が入ります。")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Coach")
        }
    }
}

private struct SettingsView_Placeholder: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Settings MVP").font(DesignSystem.Fonts.sectionTitle)
                Text("ここに設定画面が入ります。")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}
