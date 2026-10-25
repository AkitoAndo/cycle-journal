//
//  SessionClosingTests.swift
//  CycleTests
//
//  対話の終わりの「まとめ」と、次の一歩をタスクにする流れ（U-03 対話→一歩）
//

import Testing
import Foundation
@testable import Cycle

@Suite(.serialized)
@MainActor
struct SessionClosingTests {
    init() {
        UserDefaults.standard.removeObject(forKey: UserDataScope.scopedDefaultsKey("CoachSessions"))
        _ = JSONFileStore.save([TaskItem](), to: "tasks.json")
    }

    @Test func endingKeepsInsightAndNextStep() {
        let store = CoachStore()
        let session = store.startNewSession()
        store.addUserMessage("今日は少し疲れた")

        store.endCurrentSession(insight: "  休むのも前進  ", nextStep: "今夜は早く寝る")

        let saved = store.session(id: session.id)
        #expect(saved?.isActive == false)
        #expect(saved?.insight == "休むのも前進")
        #expect(saved?.nextStep == "今夜は早く寝る")
        #expect(saved?.nextStepTaskId == nil)
    }

    @Test func endingWithBlankFieldsLeavesThemNil() {
        let store = CoachStore()
        let session = store.startNewSession()
        store.addUserMessage("話したいことがある")

        store.endCurrentSession(insight: "   ", nextStep: "")

        let saved = store.session(id: session.id)
        #expect(saved?.insight == nil)
        #expect(saved?.nextStep == nil)
    }

    @Test func nextStepBecomesTodayTaskLinkedToSession() {
        let store = CoachStore()
        let vm = TaskViewModel()
        let session = store.startNewSession()
        store.addUserMessage("明日から朝に歩きたい")
        store.endCurrentSession(insight: nil, nextStep: "朝10分歩く")

        let taskId = vm.addStep(from: session.id, title: "朝10分歩く")
        #expect(taskId != nil)
        if let taskId {
            store.markNextStepAdded(sessionId: session.id, taskId: taskId)
        }

        let task = vm.tasks.first { $0.sourceSessionId == session.id }
        #expect(task?.title == "朝10分歩く")
        #expect(task.map { Calendar.current.isDateInToday($0.displayDate) } == true)
        #expect(store.session(id: session.id)?.nextStepTaskId == taskId)
    }

    @Test func blankStepIsNotAdded() {
        let vm = TaskViewModel()
        let before = vm.tasks.count
        #expect(vm.addStep(from: UUID(), title: "   ") == nil)
        #expect(vm.tasks.count == before)
    }

    @Test func weeklyReviewSessionIsFoundByItsWeek() {
        let store = CoachStore()
        var session = store.startNewSession()
        session.weeklyReviewWeekStart = WeeklyReviewWeek(containing: Date()).start
        store.updateSession(session)
        store.currentSession = session
        store.addUserMessage("今週は静かだった")
        #expect(store.isCurrentSessionWeeklyReview)

        store.endCurrentSession(insight: "急がなくても進んでいた", nextStep: "月曜に5分書く")

        let thisWeek = WeeklyReviewWeek(containing: Date())
        let found = store.weeklyReview(for: thisWeek)
        #expect(found?.id == session.id)
        #expect(found?.insight == "急がなくても進んでいた")
        #expect(found?.nextStep == "月曜に5分書く")

        let lastWeekDay = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        #expect(store.weeklyReview(for: WeeklyReviewWeek(containing: lastWeekDay)) == nil)
    }

    @Test func weeklyReviewWithoutSentenceOrStepIsNotCounted() {
        let store = CoachStore()
        var session = store.startNewSession()
        session.weeklyReviewWeekStart = WeeklyReviewWeek(containing: Date()).start
        store.updateSession(session)
        store.currentSession = session
        store.addUserMessage("話した")
        store.endCurrentSession(insight: "", nextStep: "")
        #expect(store.weeklyReview(for: WeeklyReviewWeek(containing: Date())) == nil)
    }

    @Test func hasUserMessagesDistinguishesOpenedOnlySessions() {
        var session = CoachSession()
        #expect(session.hasUserMessages == false)
        session.messages.append(CoachMessage(role: .coach, content: "こんにちは"))
        #expect(session.hasUserMessages == false)
        session.messages.append(CoachMessage(role: .user, content: "こんにちは"))
        #expect(session.hasUserMessages == true)
    }
}
