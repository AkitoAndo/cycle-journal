//
//  CycleJournalApp.swift
//  CycleJournal
//
//  Created by Akito Ando on 2025/08/08.
//

import SwiftUI

@main
struct CycleJournalApp: App {
    @StateObject private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        Group {
            switch authStore.state {
            case .unknown:
                // 認証状態確認中
                LoadingView()

            case .unauthenticated:
                // 未認証 - サインイン画面
                SignInView()
                    .environmentObject(authStore)

            case .authenticated:
                // 認証済み - メインコンテンツ
                ContentView()
            }
        }
        .animation(.easeInOut, value: authStore.state)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "tree")
                    .font(.system(size: 35))
                    .foregroundColor(.green)
            }

            ProgressView()
        }
    }
}
