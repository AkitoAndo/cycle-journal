//
//  OnboardingFlowTests.swift
//  CycleTests
//
//  Issue #37 C-1 決定: オンボーディング再設計 (Welcome → Cycle → Goal →
//  Sign In → 初ジャーナル誘導 → 通知 opt-in → Done) の state machine テスト
//

import Foundation
import Testing

@testable import Cycle

struct OnboardingStepTests {
    @Test func startsAtWelcome() {
        #expect(OnboardingStep.initial == .welcome)
    }

    @Test func progressesFromWelcomeToCycleConcept() {
        #expect(OnboardingStep.welcome.next() == .cycleConcept)
    }

    @Test func progressesFromCycleConceptToGoal() {
        #expect(OnboardingStep.cycleConcept.next() == .goal)
    }

    @Test func progressesFromGoalToSignIn() {
        #expect(OnboardingStep.goal.next() == .signIn)
    }

    @Test func progressesFromSignInToFirstJournal() {
        #expect(OnboardingStep.signIn.next() == .firstJournal)
    }

    @Test func progressesFromFirstJournalToNotificationPermission() {
        // C-2 業界ベストプラクティス: 通知 opt-in は最初のジャーナル直後
        #expect(OnboardingStep.firstJournal.next() == .notificationPermission)
    }

    @Test func progressesFromNotificationPermissionToDone() {
        #expect(OnboardingStep.notificationPermission.next() == .done)
    }

    @Test func paywallNextIsDone() {
        // Paywall step は課金再開時の復帰用に残す。
        #expect(OnboardingStep.paywall.next() == .done)
    }

    @Test func doneIsTerminal() {
        #expect(OnboardingStep.done.next() == .done)
    }

    @Test func displayOrderIsMonotonic() {
        let steps: [OnboardingStep] = [
            .welcome, .cycleConcept, .goal, .signIn,
            .firstJournal, .notificationPermission, .paywall, .done,
        ]
        let orders = steps.map(\.displayOrder)
        #expect(orders == orders.sorted())
    }
}

@MainActor
struct OnboardingFlowTests {
    @Test func initialStepIsWelcome() {
        let flow = OnboardingFlow()
        #expect(flow.step == .welcome)
        #expect(flow.isComplete == false)
    }

    @Test func advanceMovesToNextStep() {
        let flow = OnboardingFlow()
        flow.advance()
        #expect(flow.step == .cycleConcept)
    }

    @Test func goalSelectionPersists() {
        let flow = OnboardingFlow()
        flow.selectGoal(.selfAwareness)
        #expect(flow.selectedGoal == .selfAwareness)
    }

    @Test func firstJournalTextPersists() {
        let flow = OnboardingFlow()
        flow.setFirstJournalText("今日の気分は穏やか")
        #expect(flow.firstJournalText == "今日の気分は穏やか")
    }

    @Test func cannotAdvanceFromGoalWithoutSelection() {
        // Goal 選択は必須 (パーソナライズに利用)
        let flow = OnboardingFlow()
        flow.step = .goal
        flow.advance()
        // Goal 未選択なら同じ step に留まる
        #expect(flow.step == .goal)
    }

    @Test func canAdvanceFromGoalAfterSelection() {
        let flow = OnboardingFlow()
        flow.step = .goal
        flow.selectGoal(.dailyHabits)
        flow.advance()
        #expect(flow.step == .signIn)
    }

    @Test func cannotAdvanceFromFirstJournalWithoutText() {
        // 初ジャーナルは少なくとも 1 文字以上必須 (アクティベーション完了条件)
        let flow = OnboardingFlow()
        flow.step = .firstJournal
        flow.advance()
        #expect(flow.step == .firstJournal)
    }

    @Test func canAdvanceFromFirstJournalWithText() {
        let flow = OnboardingFlow()
        flow.step = .firstJournal
        flow.setFirstJournalText("はじめの一歩")
        flow.advance()
        #expect(flow.step == .notificationPermission)
    }

    @Test func reachingDoneMarksComplete() {
        let flow = OnboardingFlow()
        flow.step = .paywall
        flow.advance()
        #expect(flow.step == .done)
        #expect(flow.isComplete == true)
    }
}
