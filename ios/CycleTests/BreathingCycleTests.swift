//
//  BreathingCycleTests.swift
//  CycleTests
//

import Testing

@testable import Cycle

struct BreathingCycleTests {
    @Test func totalDurationIsNineteenSeconds() {
        #expect(BreathingCycle.totalDuration == 19)
    }

    @Test func phaseBoundariesFollowFourSevenEightPattern() {
        #expect(BreathingCycle.phase(at: 0) == .inhale)
        #expect(BreathingCycle.phase(at: 3.99) == .inhale)
        #expect(BreathingCycle.phase(at: 4) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 10.99) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 11) == .exhale)
        #expect(BreathingCycle.phase(at: 18.99) == .exhale)
    }

    @Test func phaseWrapsAcrossCycles() {
        #expect(BreathingCycle.phase(at: 19) == .inhale)
        #expect(BreathingCycle.phase(at: 24) == .holdAfterInhale)
        #expect(BreathingCycle.phase(at: 31) == .exhale)
        #expect(BreathingCycle.phase(at: 38) == .inhale)
    }

    @Test func circleScaleExpandsAndContractsByPhase() {
        #expect(BreathingCycle.circleScale(at: 0) == 0.82)
        #expect(BreathingCycle.circleScale(at: 4) == 1.18)
        #expect(BreathingCycle.circleScale(at: 10) == 1.18)
        #expect(BreathingCycle.circleScale(at: 15) < BreathingCycle.circleScale(at: 12))
        #expect(BreathingCycle.circleScale(at: 18.99) < 0.83)
    }

    @Test func titlesAreUserFacingBreathingLabels() {
        #expect(BreathingPhase.inhale.title == "息を吸う")
        #expect(BreathingPhase.holdAfterInhale.title == "そのまま")
        #expect(BreathingPhase.exhale.title == "息を吐く")
        #expect(BreathingPhase.holdAfterExhale.title == "そのまま")
    }
}
