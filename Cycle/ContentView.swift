//
//  ContentView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // メインコンテンツ
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        JournalListView()
                    }
                case 1:
                    CoachView_Placeholder()
                case 2:
                    NavigationStack {
                        TaskListView()
                    }
                case 3:
                    SettingsView_Placeholder()
                default:
                    NavigationStack {
                        JournalListView()
                    }
                }
            }
            .padding(.bottom, 55)

            // カスタムタブバー
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

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

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))

                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Placeholders

private struct CoachView_Placeholder: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Coach MVP").font(.title3)
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
                Text("Settings MVP").font(.title3)
                Text("ここに設定画面が入ります。")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}
