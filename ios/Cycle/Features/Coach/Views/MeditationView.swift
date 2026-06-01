//
//  MeditationView.swift
//  CycleJournal
//

import SwiftUI
import UIKit

struct MeditationView: View {
    @EnvironmentObject var meditationStore: MeditationStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedHours = 0
    @State private var selectedMinutes = 5
    @State private var selectedSeconds = 0
    @State private var isRunning = false
    @State private var remainingSeconds = 0
    @State private var timer: Timer?
    @State private var totalSeconds = 0
    @State private var isCompleted = false

    private let hourRange = 0...23
    private let minuteRange = 0...59
    private let secondRange = 0...59

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                if isCompleted {
                    completedView
                } else if isRunning {
                    timerView
                } else {
                    selectionView
                }

                Spacer()

                actionButton
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
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: isRunning) { _, running in
                UIApplication.shared.isIdleTimerDisabled = running
            }
        }
    }

    // MARK: - Selection

    private var selectionView: some View {
        VStack(spacing: 0) {
            TimerPickerView(
                hours: $selectedHours,
                minutes: $selectedMinutes,
                seconds: $selectedSeconds
            )
            .frame(height: 180)
        }
    }

    // MARK: - Timer

    private var timerView: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.greyLight, lineWidth: 4)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DesignSystem.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                Text(timeString)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("\(completedTimeString)の瞑想を完了しました")
                .font(DesignSystem.Fonts.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if isCompleted {
            PrimaryButton("完了") {
                dismiss()
            }
        } else if isRunning {
            SecondaryButton("やめる") {
                stopTimer()
                saveAndComplete()
            }
        } else {
            PrimaryButton("はじめる") {
                if selectedTotalSeconds > 0 {
                    startTimer()
                }
            }
        }
    }

    // MARK: - Timer Logic

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 1.0 }
        return CGFloat(totalSeconds - remainingSeconds) / CGFloat(totalSeconds)
    }

    private var selectedTotalSeconds: Int {
        selectedHours * 3600 + selectedMinutes * 60 + selectedSeconds
    }

    private var timeString: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var completedTimeString: String {
        let elapsed = totalSeconds - remainingSeconds
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)時間") }
        if m > 0 { parts.append("\(m)分") }
        if s > 0 || parts.isEmpty { parts.append("\(s)秒") }
        return parts.joined()
    }

    private func startTimer() {
        totalSeconds = selectedTotalSeconds
        remainingSeconds = totalSeconds
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                stopTimer()
                hapticFeedback()
                saveAndComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func saveAndComplete() {
        let elapsed = totalSeconds - remainingSeconds
        if elapsed > 0 {
            meditationStore.addLog(duration: elapsed)
        }
        isCompleted = true
    }

    private func hapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - UIPickerView Wrapper (時・分・秒を1つのピッカーで統合)

private struct TimerPickerView: UIViewRepresentable {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.selectRow(hours, inComponent: 0, animated: false)
        picker.selectRow(minutes, inComponent: 1, animated: false)
        picker.selectRow(seconds, inComponent: 2, animated: false)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        if picker.selectedRow(inComponent: 0) != hours {
            picker.selectRow(hours, inComponent: 0, animated: false)
        }
        if picker.selectedRow(inComponent: 1) != minutes {
            picker.selectRow(minutes, inComponent: 1, animated: false)
        }
        if picker.selectedRow(inComponent: 2) != seconds {
            picker.selectRow(seconds, inComponent: 2, animated: false)
        }
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        let parent: TimerPickerView
        private let labels = ["時間", "分", "秒"]
        private let counts = [24, 60, 60]

        init(_ parent: TimerPickerView) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            counts[component]
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            component == 0 ? 95 : 75
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 20)

            let value = "\(row)"
            let unit = labels[component]
            let full = "\(value) \(unit)"

            let attr = NSMutableAttributedString(string: full)
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 20), range: NSRange(location: 0, length: value.count))
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: value.count + 1, length: unit.count))
            label.attributedText = attr

            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            switch component {
            case 0: parent.hours = row
            case 1: parent.minutes = row
            case 2: parent.seconds = row
            default: break
            }
        }
    }
}
