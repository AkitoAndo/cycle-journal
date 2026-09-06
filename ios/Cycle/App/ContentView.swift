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
            .task {
                await journalViewModel.syncWithServer()
            }
    }

    private var splashView: some View {
        SplashView()
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // 全タブをマウントしたまま opacity で出し分ける。
            // 切替時に描画前の裏地（システム背景）が一瞬見えないよう、
            // 次のタブを常に描画済みの状態にしておくため。
            // 非選択タブは accessibilityHidden + allowsHitTesting(false) で
            // VoiceOver / タップ対象から外す。
            ZStack {
                tabContainer(index: 0) {
                    NavigationStack { HomeView() }
                }
                tabContainer(index: 1) {
                    NavigationStack { JournalListView() }
                }
                tabContainer(index: 2) {
                    NavigationStack { CoachHomeView() }
                }
                tabContainer(index: 3) {
                    NavigationStack { TaskListView() }
                }
                tabContainer(index: 4) {
                    MyPageView()
                }
            }
            .padding(.bottom, 55)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCoachChat)) { _ in
            selectedTab = 2
            coachStore.shouldOpenChat = true
        }
        .ignoresSafeArea(.keyboard)
    }


    /// タブのコンテナ。全タブを常にマウントし、選択中のみ表示・操作可能にする。
    /// opacity の切替はアニメーションさせない（クロスフェード中に裏地が
    /// 透けるのを防ぎ、即座に次のタブへ切り替える）。
    @ViewBuilder
    private func tabContainer<Content: View>(
        index: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isSelected = selectedTab == index
        content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .environment(\.cycleTabIsActive, isSelected)
            .animation(nil, value: selectedTab)
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
                icon: "house",
                selectedIcon: "house.fill",
                label: "ホーム",
                identifier: "tab_Home",
                isSelected: selectedTab == 0,
                namespace: indicatorNamespace,
                action: { select(0) }
            )

            TabBarButton(
                icon: "leaf",
                selectedIcon: "leaf.fill",
                label: "ジャーナル",
                identifier: "tab_Journal",
                isSelected: selectedTab == 1,
                namespace: indicatorNamespace,
                action: { select(1) }
            )

            TabBarButton(
                // Cycleロゴ（大樹アイコン）をそのまま表示。中央タブとして大きめに
                icon: "CycleIcon",
                selectedIcon: "CycleIcon",
                label: "セッション",
                identifier: "tab_Coach",
                isAssetIcon: true,
                isProminent: true,
                isSelected: selectedTab == 2,
                namespace: indicatorNamespace,
                action: { select(2) }
            )

            TabBarButton(
                icon: "checklist",
                selectedIcon: "checklist.checked",
                label: "タスクリスト",
                identifier: "tab_Tasks",
                isSelected: selectedTab == 3,
                namespace: indicatorNamespace,
                action: { select(3) }
            )

            TabBarButton(
                icon: "person",
                selectedIcon: "person.fill",
                label: "マイページ",
                identifier: "tab_MyPage",
                isSelected: selectedTab == 4,
                namespace: indicatorNamespace,
                action: { select(4) }
            )
        }
        .frame(height: 55)
        .background(DesignSystem.Colors.background)
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
    /// true の場合、icon をアセット画像名として扱う（Cycleロゴ等のカラー画像用）
    var isAssetIcon: Bool = false
    /// true の場合、他タブよりアイコンを大きく表示して目立たせる（中央タブ用）
    var isProminent: Bool = false
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    private var iconSize: CGFloat {
        isProminent ? 72 : DesignSystem.ComponentSize.iconSize
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isAssetIcon {
                        Image(icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(Circle())
                            // ブランドロゴは選択状態に関わらず常時フルカラーで表示
                            .frame(width: iconSize, height: iconSize)
                            // 中央タブはタブバー上端から少し飛び出させ、中心として際立たせる
                            .offset(y: isProminent ? -8 : 0)
                    } else {
                        // トランジションなしで即アイコン切替（ふわっとしない）
                        Image(systemName: isSelected ? selectedIcon : icon)
                    }
                }
                .font(.system(size: DesignSystem.FontSize.title3))
                .frame(width: DesignSystem.ComponentSize.iconSize, height: DesignSystem.ComponentSize.iconSize)

                // 中央の強調タブはロゴのみ表示（文字なし）
                if !isProminent {
                    Text(label)
                        .font(.system(size: 10))
                }
            }
            .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(label)
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
