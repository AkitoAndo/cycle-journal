//
//  OnboardingFirstJournalView.swift
//  CycleJournal
//
//  Issue #37 C-1: Paywall 前のアクティベーション (最初のジャーナル) を必須化するステップ.
//

import SwiftUI

struct OnboardingFirstJournalView: View {
    @EnvironmentObject private var flow: OnboardingFlow
    @EnvironmentObject private var journalViewModel: JournalViewModel
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("はじめの一歩")
                    .font(DesignSystem.Fonts.screenTitle)
                Text("いま感じていることを、3 行でいいので書いてみましょう。短くて大丈夫。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if flow.firstJournalText.isEmpty {
                    Text(prompt(for: flow.selectedGoal))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditor(
                    text: Binding(
                        get: { flow.firstJournalText },
                        set: { flow.setFirstJournalText($0) }
                    )
                )
                .focused($isEditorFocused)
                .padding(8)
                .frame(minHeight: 180)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            Button {
                let text = flow.firstJournalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                Task {
                    await journalViewModel.addEntry(text: text)
                    flow.advance()
                }
            } label: {
                Text("保存して次へ")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(flow.canAdvance ? DesignSystem.Colors.accent : DesignSystem.Colors.grey)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md, style: .continuous))
            }
            .disabled(!flow.canAdvance)
        }
        .padding(24)
        .onAppear { isEditorFocused = true }
    }

    private func prompt(for goal: OnboardingGoal?) -> String {
        switch goal {
        case .selfAwareness:
            return "今日、自分のなかでいちばん大きく動いた気持ちは何でしたか?"
        case .stressManagement:
            return "今日、心や体が「ふっと軽くなった」瞬間はありましたか?"
        case .goalAchievement:
            return "いま向き合っている目標について、思いついたことを書いてみましょう。"
        case .dailyHabits:
            return "今日続けたかった習慣について、できたこと・できなかったことを書いてみましょう。"
        case .personalGrowth:
            return "最近、自分のなかで「ちょっと変わったかも」と思える小さな変化はありますか?"
        case .none:
            return "今日のいちばん覚えておきたい一場面を、短く書いてみましょう。"
        }
    }
}
