//
//  ContentView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var journalViewModel: JournalViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @EnvironmentObject var coachStore: CoachStore
    @EnvironmentObject var authStore: AuthStore

    @State private var selectedTab = 0

    var body: some View {
        if #available(iOS 26.0, *) {
            liquidGlassLayout
        } else {
            legacyLayout
        }
    }

    // MARK: - iOS 26+ Liquid Glass Layout

    @available(iOS 26.0, *)
    private var liquidGlassLayout: some View {
        ZStack(alignment: .bottom) {
            // コンテンツはタブバーの裏まで広がる（透けて見える）
            tabContent
                .ignoresSafeArea(.keyboard)

            // フローティング Liquid Glass タブバー
            GlassEffectContainer {
                HStack(spacing: 0) {
                    TabBarButton(
                        icon: "leaf",
                        label: "Journal",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    TabBarButton(
                        icon: "bubble.left.and.bubble.right",
                        label: "Coach",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                    TabBarButton(
                        icon: "checklist",
                        label: "Tasks",
                        isSelected: selectedTab == 2,
                        action: { selectedTab = 2 }
                    )
                    TabBarButton(
                        icon: "gearshape",
                        label: "Settings",
                        isSelected: selectedTab == 3,
                        action: { selectedTab = 3 }
                    )
                }
                .frame(height: 55)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - iOS 17-25 Legacy Layout

    private var legacyLayout: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .padding(.bottom, 55)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Tab Content

    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                NavigationStack {
                    JournalListView()
                }
            case 1:
                CoachHomeView()
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
    }
}

// MARK: - Custom Tab Bar (iOS 17-25)

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "leaf",
                label: "Journal",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            TabBarButton(
                icon: "bubble.left.and.bubble.right",
                label: "Coach",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            TabBarButton(
                icon: "checklist",
                label: "Tasks",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            TabBarButton(
                icon: "gearshape",
                label: "Settings",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .frame(height: 55)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.FontSize.title3))

                Text(label)
                    .font(DesignSystem.Fonts.caption2)
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("tab_\(label)")
    }
}
