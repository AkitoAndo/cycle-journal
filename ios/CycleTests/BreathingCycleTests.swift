//
//  BreathingCycleTests.swift
//  CycleTests
//

import Testing

@testable import Cycle

struct BreathingCycleTests {
    @Test func totalDurationIsFourteenSeconds() {
        #expect(BreathingCycle.totalDuration == 14)
    }

    @Test func phaseBoundariesFollowFourTwoSixTwoPattern() {
        #expect(BreathingCycle.phase(at: 0) == .inhale)
        #expect(BreathingCycle.phase(at: 3.99) == .inhale)
        #expect(BreathingCycle.phase(at: 4) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 5.99) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 6) == .exhale)
        #expect(BreathingCycle.phase(at: 11.99) == .exhale)
        #expect(BreathingCycle.phase(at: 12) == .holdAfterExhale)
        #expect(BreathingCycle.phase(at: 13.99) == .holdAfterExhale)
    }

    @Test func phaseWrapsAcrossCycles() {
        #expect(BreathingCycle.phase(at: 14) == .inhale)
        #expect(BreathingCycle.phase(at: 18) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 20) == .exhale)
        #expect(BreathingCycle.phase(at: 26) == .holdAfterExhale)
    }

    @Test func circleScaleExpandsAndContractsByPhase() {
        #expect(BreathingCycle.circleScale(at: 0) == 0.82)
        #expect(BreathingCycle.circleScale(at: 4) == 1.18)
        #expect(BreathingCycle.circleScale(at: 8) < BreathingCycle.circleScale(at: 6))
        #expect(BreathingCycle.circleScale(at: 12) == 0.82)
    }

    @Test func titlesAreUserFacingBreathingLabels() {
        #expect(BreathingPhase.inhale.title == "息を吸う")
        #expect(BreathingPhase.holdAfterInhale.title == "そのまま")
        #expect(BreathingPhase.exhale.title == "息を吐く")
        #expect(BreathingPhase.holdAfterExhale.title == "そのまま")
    }
}
