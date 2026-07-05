//
//  ContentView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import SwiftUI
import Pow

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var coachStore: CoachStore
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var taskViewModel: TaskViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// アプリ起動時のフロー:
    ///
    ///   1. Onboarding 体験 (登録なし・カード不要) ← user spec ステップ1
    ///   2. SignIn (Apple/Google) — 課金主体を identify
    ///   3. Main (MVP期間は課金なしで全機能)
    ///
    /// 課金再開時は SubscriptionStore / PaywallView をハードゲートに戻す。
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                switch authStore.state {
                case .unknown:
                    splashView
                case .unauthenticated:
                    SignInView()
                case .authenticated:
                    authenticatedContent
                }
            }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        mainContent
    }

    private var splashView: some View {
        SplashView()
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // タブは switch で出し分ける（非表示タブをビュー階層に残すと
            // NavigationStack 境界で accessibilityHidden が効かず、
            // VoiceOver / UI テストに非表示タブの要素が漏れるため）。
            // 出現アニメーションの再発火は StaggeredAppear のセッションメモリで防ぐ。
            ZStack {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        JournalListView()
                    }
                    .transition(tabTransition)
                case 1:
                    NavigationStack {
                        CoachHomeView()
                    }
                    .transition(tabTransition)
                case 2:
                    NavigationStack {
                        TaskListView()
                    }
                    .transition(tabTransition)
                case 3:
                    SettingsView()
                        .transition(tabTransition)
                default:
                    NavigationStack {
                        JournalListView()
                    }
                    .transition(tabTransition)
                }
            }
            .animation(DesignSystem.Timing.gentleSpring, value: selectedTab)
            .padding(.bottom, 55)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCoachChat)) { _ in
            selectedTab = 1
            coachStore.shouldOpenChat = true
        }
        .ignoresSafeArea(.keyboard)
    }


    /// タブ切替時のクロスフェード + わずかなスケール
    private var tabTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}

// MARK: - Splash

/// 起動直後（認証状態の確認中）に表示するスプラッシュ
/// ロゴがゆっくり呼吸するアニメーション付き
private struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundGradient.ignoresSafeArea()

            Image("CycleIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .scaleEffect(isBreathing ? 1.06 : 0.98)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "leaf",
                selectedIcon: "leaf.fill",
                label: "ジャーナル",
                identifier: "tab_Journal",
                isSelected: selectedTab == 0,
                namespace: indicatorNamespace,
                action: { select(0) }
            )

            TabBarButton(
                icon: "bubble.left.and.bubble.right",
                selectedIcon: "bubble.left.and.bubble.right.fill",
                label: "セッション",
                identifier: "tab_Coach",
                isSelected: selectedTab == 1,
                namespace: indicatorNamespace,
                action: { select(1) }
            )

            TabBarButton(
                icon: "checklist",
                selectedIcon: "checklist.checked",
                label: "タスクリスト",
                identifier: "tab_Tasks",
                isSelected: selectedTab == 2,
                namespace: indicatorNamespace,
                action: { select(2) }
            )

            TabBarButton(
                icon: "gearshape",
                selectedIcon: "gearshape.fill",
                label: "設定",
                identifier: "tab_Settings",
                isSelected: selectedTab == 3,
                namespace: indicatorNamespace,
                action: { select(3) }
            )
        }
        .frame(height: 55)
        .background(DesignSystem.Colors.background)
        .overlay(alignment: .top) {
            Divider()
                .background(DesignSystem.Colors.grey.opacity(0.4))
        }
    }

    private func select(_ tab: Int) {
        withAnimation(DesignSystem.Timing.bouncySpring) {
            selectedTab = tab
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    /// 表示ラベルと独立した UI テスト用の安定 ID（例: "tab_Journal"）
    let identifier: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Image(systemName: selectedIcon)
                            .transition(.movingParts.pop(DesignSystem.Colors.accent))
                    } else {
                        Image(systemName: icon)
                            .transition(.opacity)
                    }
                }
                .font(.system(size: DesignSystem.FontSize.title3))
                .frame(width: DesignSystem.ComponentSize.iconSize, height: DesignSystem.ComponentSize.iconSize)
                .changeEffect(.jump(height: 5), value: isSelected, isEnabled: isSelected)

                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    Capsule()
                        .fill(DesignSystem.Colors.accent.opacity(0.10))
                        .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
        .animation(DesignSystem.Timing.easing, value: isSelected)
        .accessibilityIdentifier(identifier)
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
