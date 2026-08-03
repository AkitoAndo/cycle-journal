//
//  BreathingCycle.swift
//  CycleJournal
//

import Foundation

enum BreathingPhase: Equatable {
    case inhale
    case holdAfterInhale
    case exhale
    case holdAfterExhale

    var title: String {
        switch self {
        case .inhale:
            return "息を吸う"
        case .holdAfterInhale, .holdAfterExhale:
            return "そのまま"
        case .exhale:
            return "息を吐く"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .inhale:
            return "息を吸います"
        case .holdAfterInhale, .holdAfterExhale:
            return "息を止めます"
        case .exhale:
            return "息を吐きます"
        }
    }
}

struct BreathingCycle {
    // 4-7-8呼吸法（吸う4秒・止める7秒・吐く8秒、吐き切り後の停止なし）。
    // 吐く:吸う = 2:1 の吐き強調 + 長い保持で副交感神経を最大限に高める、
    // リラクゼーション効果を最優先したテンポ。初心者にはきついが瞑想効果重視。
    static let inhaleDuration: TimeInterval = 4
    static let holdAfterInhaleDuration: TimeInterval = 7
    static let exhaleDuration: TimeInterval = 8
    static let holdAfterExhaleDuration: TimeInterval = 0
    static let totalDuration: TimeInterval = 19

    static func phase(at elapsedSeconds: TimeInterval) -> BreathingPhase {
        let position = normalizedPosition(for: elapsedSeconds)

        if position < inhaleDuration {
            return .inhale
        }
        if position < inhaleDuration + holdAfterInhaleDuration {
            return .holdAfterInhale
        }
        if position < inhaleDuration + holdAfterInhaleDuration + exhaleDuration {
            return .exhale
        }
        return .holdAfterExhale
    }

    static func phaseProgress(at elapsedSeconds: TimeInterval) -> Double {
        let position = normalizedPosition(for: elapsedSeconds)

        switch phase(at: elapsedSeconds) {
        case .inhale:
            return clamped(position / inhaleDuration)
        case .holdAfterInhale:
            let phaseElapsed = position - inhaleDuration
            return clamped(phaseElapsed / holdAfterInhaleDuration)
        case .exhale:
            let phaseElapsed = position - inhaleDuration - holdAfterInhaleDuration
            return clamped(phaseElapsed / exhaleDuration)
        case .holdAfterExhale:
            let phaseElapsed = position - inhaleDuration - holdAfterInhaleDuration - exhaleDuration
            return clamped(phaseElapsed / holdAfterExhaleDuration)
        }
    }

    static func circleScale(at elapsedSeconds: TimeInterval) -> Double {
        let minScale = 0.82
        let maxScale = 1.18
        let progress = phaseProgress(at: elapsedSeconds)

        switch phase(at: elapsedSeconds) {
        case .inhale:
            return minScale + (maxScale - minScale) * progress
        case .holdAfterInhale:
            return maxScale
        case .exhale:
            return maxScale - (maxScale - minScale) * progress
        case .holdAfterExhale:
            return minScale
        }
    }

    private static func normalizedPosition(for elapsedSeconds: TimeInterval) -> TimeInterval {
        let remainder = elapsedSeconds.truncatingRemainder(dividingBy: totalDuration)
        return remainder >= 0 ? remainder : remainder + totalDuration
    }

    private static func clamped(_ value: TimeInterval) -> Double {
        min(max(Double(value), 0), 1)
    }
}
