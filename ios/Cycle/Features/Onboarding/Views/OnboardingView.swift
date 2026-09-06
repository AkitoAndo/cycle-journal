//
//  OnboardingView.swift
//  CycleJournal
//

import SwiftUI

// MARK: - Onboarding Page Data

private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String?
    let useAppIcon: Bool
    let title: String
    let subtitle: String
    let details: [OnboardingDetail]?

    init(id: Int, icon: String? = nil, useAppIcon: Bool = false, title: String, subtitle: String, details: [OnboardingDetail]? = nil) {
        self.id = id
        self.icon = icon
        self.useAppIcon = useAppIcon
        self.title = title
        self.subtitle = subtitle
        self.details = details
    }
}

private struct OnboardingDetail: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Goal

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case selfAwareness = "self_awareness"
    case stressManagement = "stress_management"
    case goalAchievement = "goal_achievement"
    case dailyHabits = "daily_habits"
    case personalGrowth = "personal_growth"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selfAwareness: return "自己理解"
        case .stressManagement: return "ストレス管理"
        case .goalAchievement: return "目標達成"
        case .dailyHabits: return "日々の習慣"
        case .personalGrowth: return "自分の成長"
        }
    }

    var icon: String {
        switch self {
        case .selfAwareness: return "eye"
        case .stressManagement: return "leaf"
        case .goalAchievement: return "flag"
        case .dailyHabits: return "arrow.trianglehead.2.clockwise"
        case .personalGrowth: return "arrow.up.right"
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var flow = OnboardingFlow()

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            useAppIcon: true,
            title: "自分と向き合う日記アプリ",
            subtitle: "日記を書き、振り返り、\n成長のサイクルを回そう"
        ),
        OnboardingPage(
            id: 1,
            icon: "tree",
            title: "Treowという考え方",
            subtitle: "気づきと行動の循環が、あなたを育てます",
            details: [
                OnboardingDetail(icon: "leaf", title: "Root", description: "想いを植える", color: DesignSystem.Colors.accent),
                OnboardingDetail(icon: "drop", title: "Water", description: "日々をふりかえる", color: Color(red: 0.4, green: 0.6, blue: 0.7)),
                OnboardingDetail(icon: "tree", title: "Trunk", description: "行動で育てる", color: Color(red: 0.5, green: 0.4, blue: 0.3)),
                OnboardingDetail(icon: "sparkles", title: "Fruit", description: "成長を実感する", color: Color(red: 0.7, green: 0.5, blue: 0.3)),
            ]
        ),
        OnboardingPage(
            id: 2,
            icon: "questionmark.circle",
            title: "何を大切にしたいですか？",
            subtitle: "あなたに合った体験を届けます"
        )
    ]

    var body: some View {
        Group {
            switch flow.step {
            case .welcome, .cycleConcept, .goal:
                introductionStep
            case .signIn:
                signInStep
            case .firstJournal:
                OnboardingFirstJournalView()
            case .notificationPermission:
                OnboardingNotificationPermissionView()
            case .paywall:
                OnboardingPaywallView()
            case .done:
                DesignSystem.Colors.background
                    .ignoresSafeArea()
            }
        }
        .environmentObject(flow)
        .background(DesignSystem.Colors.background.ignoresSafeArea())
        .animation(DesignSystem.Timing.gentleSpring, value: flow.step)
        .onChange(of: authStore.state) { _, state in
            guard state.isAuthenticated, flow.step == .signIn else { return }
            flow.advance()
        }
        .onChange(of: flow.step) { _, step in
            if step == .signIn, authStore.state.isAuthenticated {
                flow.advance()
            } else if step == .done {
                hasCompletedOnboarding = true
            }
        }
    }

    // MARK: - Introduction

    private var introductionStep: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if flow.step != .goal {
                    Button("スキップ") {
                        flow.skipIntroduction()
                    }
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }
            .frame(minHeight: 44)

            if let page = pageForCurrentStep {
                pageView(page)
                    .id(page.id)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            VStack(spacing: DesignSystem.Spacing.xxl) {
                pageDots

                PrimaryButton(
                    flow.step == .goal ? "サインインへ" : "つぎへ",
                    icon: "arrow.right"
                ) {
                    flow.advance()
                }
                .disabled(!flow.canAdvance)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.bottom, DesignSystem.Spacing.xxl + 16)
        }
    }

    private var pageForCurrentStep: OnboardingPage? {
        let index = flow.step.rawValue
        guard pages.indices.contains(index) else { return nil }
        return pages[index]
    }

    // MARK: - Authentication

    @ViewBuilder
    private var signInStep: some View {
        switch authStore.state {
        case .unknown:
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView()
                    .tint(DesignSystem.Colors.accent)
                Text("サインイン状態を確認しています")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unauthenticated:
            SignInView()
        case .authenticated:
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView()
                    .tint(DesignSystem.Colors.accent)
                Text("最初の記録を準備しています")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                guard flow.step == .signIn else { return }
                flow.advance()
            }
        }
    }

    // MARK: - Page View

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Spacer()
                    .frame(height: 40)

                // Icon
                if page.useAppIcon {
                    Image("CycleIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(color: DesignSystem.Colors.accent.opacity(0.2), radius: 20)
                } else if let icon = page.icon {
                    IconCircle(icon: icon, size: 100, color: DesignSystem.Colors.accent)
                }

                // Title & Subtitle
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(page.title)
                        .font(DesignSystem.Fonts.sectionTitle)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(page.subtitle)
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Details (Cycle concept page)
                if let details = page.details {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(details) { detail in
                            cycleDetailRow(detail)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                // Goal selection (page 2)
                if page.id == 2 {
                    goalSelectionView
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Cycle Detail Row

    private func cycleDetailRow(_ detail: OnboardingDetail) -> some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: detail.icon)
                .font(.system(size: 20))
                .foregroundStyle(detail.color)
                .frame(width: 36, height: 36)
                .background(detail.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(DesignSystem.Fonts.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(detail.description)
                    .font(DesignSystem.Fonts.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Goal Selection

    private var goalSelectionView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(OnboardingGoal.allCases) { goal in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        flow.selectGoal(goal)
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 18))
                            .frame(width: 28)
                            .foregroundStyle(flow.selectedGoal == goal ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)

                        Text(goal.label)
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()

                        if flow.selectedGoal == goal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignSystem.Colors.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(DesignSystem.Spacing.mlg)
                    .background(
                        flow.selectedGoal == goal
                            ? DesignSystem.Colors.accent.opacity(0.08)
                            : DesignSystem.Colors.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                flow.selectedGoal == goal ? DesignSystem.Colors.accent : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index == flow.step.rawValue ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                    .frame(width: index == flow.step.rawValue ? 10 : 8, height: index == flow.step.rawValue ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: flow.step)
            }
        }
    }
}
