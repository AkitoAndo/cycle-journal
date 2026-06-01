//
//  BreathingSessionView.swift
//  CycleJournal
//

import SwiftUI
import UIKit

struct BreathingSessionView: View {
    @EnvironmentObject var meditationStore: MeditationStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDuration = 300
    @State private var isRunning = false
    @State private var isCompleted = false
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var startedAt: Date?
    @State private var timer: Timer?

    private let durationOptions = [60, 180, 300]
    private let timerInterval: TimeInterval = 0.1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: DesignSystem.Spacing.xxl)

                if isCompleted {
                    completedView
                } else {
                    breathingView
                }

                Spacer(minLength: DesignSystem.Spacing.xxl)

                controls
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl * 2)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isRunning {
                        Button("閉じる") {
                            dismiss()
                        }
                        .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
            }
            .onDisappear {
                stopTimer()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: isRunning) { _, running in
                UIApplication.shared.isIdleTimerDisabled = running
            }
            .interactiveDismissDisabled(isRunning)
        }
    }

    private var breathingView: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.greyLight.opacity(0.7), lineWidth: 1)
                    .frame(width: 230, height: 230)

                Circle()
                    .stroke(DesignSystem.Colors.greyLight.opacity(0.9), lineWidth: 1)
                    .frame(width: 170, height: 170)

                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.08))
                    .frame(width: 156, height: 156)
                    .scaleEffect(circleScale)

                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.32), lineWidth: 2)
                    .frame(width: 156, height: 156)
                    .scaleEffect(circleScale)

                Image("CycleIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .opacity(0.92)
            }
            .animation(.linear(duration: timerInterval), value: circleScale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("呼吸フェーズ")
            .accessibilityValue("\(currentPhase.accessibilityDescription)、残り\(remainingTimeString)")

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(currentPhase.title)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(remainingTimeString)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(currentPhase.accessibilityDescription)、残り\(remainingTimeString)")
        }
    }

    private var completedView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("\(completedDurationString)の呼吸を記録しました")
                .font(DesignSystem.Fonts.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    @ViewBuilder
    private var controls: some View {
        if isCompleted {
            PrimaryButton("完了") {
                dismiss()
            }
        } else {
            VStack(spacing: DesignSystem.Spacing.lg) {
                if !isRunning {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("セッション時間")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Spacer()

                            Text(durationLabel(for: selectedDuration))
                                .font(DesignSystem.Fonts.caption)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }

                        Picker("セッション時間", selection: $selectedDuration) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Text(durationLabel(for: duration)).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if isRunning {
                    SecondaryButton("終わる") {
                        finishSession()
                    }
                } else {
                    PrimaryButton("はじめる") {
                        startSession()
                    }
                }
            }
        }
    }

    private var currentPhase: BreathingPhase {
        BreathingCycle.phase(at: elapsedSeconds)
    }

    private var circleScale: Double {
        BreathingCycle.circleScale(at: elapsedSeconds)
    }

    private var remainingSeconds: Int {
        max(Int(ceil(TimeInterval(selectedDuration) - elapsedSeconds)), 0)
    }

    private var remainingTimeString: String {
        formatDuration(remainingSeconds)
    }

    private var completedDurationString: String {
        formatDuration(max(Int(elapsedSeconds), 0))
    }

    private func startSession() {
        elapsedSeconds = 0
        startedAt = Date()
        isRunning = true
        isCompleted = false

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            updateElapsedTime()
        }
    }

    private func updateElapsedTime() {
        refreshElapsedTime()

        if elapsedSeconds >= TimeInterval(selectedDuration) {
            hapticFeedback()
            finishSession()
        }
    }

    private func refreshElapsedTime() {
        guard let startedAt else { return }
        elapsedSeconds = min(Date().timeIntervalSince(startedAt), TimeInterval(selectedDuration))
    }

    private func finishSession() {
        refreshElapsedTime()
        stopTimer()

        let elapsed = elapsedSeconds > 0 ? max(Int(ceil(elapsedSeconds)), 1) : 0
        elapsedSeconds = TimeInterval(elapsed)
        if elapsed > 0 {
            meditationStore.addLog(duration: elapsed)
        }
        isCompleted = true
        isRunning = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func durationLabel(for seconds: Int) -> String {
        formatDuration(seconds)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes > 0 && remainingSeconds > 0 {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(remainingSeconds)秒"
    }

    private func hapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    BreathingSessionView()
        .environmentObject(MeditationStore())
}
