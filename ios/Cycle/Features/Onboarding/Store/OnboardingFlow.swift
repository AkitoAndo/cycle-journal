//
//  OnboardingFlow.swift
//  CycleJournal
//
//  Issue #37 C-1 決定のオンボーディング state machine.
//
//  フロー: Welcome → Cycle 概念 → Goal 選択 → Apple Sign In →
//         初ジャーナル誘導 → 通知 opt-in → Done
//
//  業界ベストプラクティス反映:
//  - 通知 opt-in は "最初のジャーナル保存直後" の value moment (Blinkist 事例 6%→74%)
//  - MVP期間は課金なし。Paywall step は課金再開時の復帰用に残す。
//

import Combine
import Foundation
import SwiftUI

/// オンボーディング進行の段階.
enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome = 0
    case cycleConcept = 1
    case goal = 2
    case signIn = 3
    case firstJournal = 4
    case notificationPermission = 5
    case paywall = 6
    case done = 7

    static let initial: OnboardingStep = .welcome

    var displayOrder: Int { rawValue }

    /// 次の step を返す. done は terminal.
    func next() -> OnboardingStep {
        if self == .notificationPermission {
            return .done
        }
        guard let next = OnboardingStep(rawValue: rawValue + 1) else { return .done }
        return next
    }
}

/// オンボーディング全体のステートを保持する ObservableObject.
@MainActor
final class OnboardingFlow: ObservableObject {
    @Published var step: OnboardingStep = .initial
    @Published var selectedGoal: OnboardingGoal?
    @Published var firstJournalText: String = ""

    var isComplete: Bool { step == .done }

    /// 次の step に進めるかどうかを判定する.
    var canAdvance: Bool {
        switch step {
        case .goal:
            return selectedGoal != nil
        case .firstJournal:
            let trimmed = firstJournalText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        default:
            return true
        }
    }

    func advance() {
        guard canAdvance else { return }
        step = step.next()
    }

    /// 紹介ページだけを省略し、認証以降の価値体験は維持する。
    func skipIntroduction() {
        guard step == .welcome || step == .cycleConcept else { return }
        step = .signIn
    }

    func selectGoal(_ goal: OnboardingGoal) {
        selectedGoal = goal
        UserDefaults.standard.set(goal.rawValue, forKey: "pendingOnboardingGoal")
    }

    func setFirstJournalText(_ text: String) {
        firstJournalText = text
    }
}
