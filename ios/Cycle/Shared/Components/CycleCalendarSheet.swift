//
//  CycleCalendarSheet.swift
//  Cycle
//
//  カレンダー（ホーム埋め込み / ジャーナル日付選択シート 共通）
//  - 月表示と週表示を切り替え可能（supportsWeekMode 有効時）
//  - 前月/次月（週表示時は前週/次週）へ移動可
//  - 「選択日（アクセント塗り）」「今日（アクセント枠線）」
//    「記録のある日（ドット）」を区別して表示する
//

import SwiftUI

/// カレンダー本体（画面への埋め込み用）
/// 日付タップで selectedDate を更新し、onSelect を呼ぶ。
struct CycleCalendarView: View {
    @Binding var selectedDate: Date
    /// ドットを表示する日（year/month/day の DateComponents）
    let recordedDays: Set<DateComponents>
    /// 日付選択時の追加処理（選択日の反映は selectedDate バインディングで行われる）
    var onSelect: ((Date) -> Void)? = nil
    /// 週表示⇔月表示の切替トグルを表示するか
    var supportsWeekMode: Bool = false
    /// 「今日」ボタンを表示するか（今日以外を選択中に出る）
    var showsTodayButton: Bool = false
    /// 前へ/次への矢印（< >）を表示するか。false のときは年月タップで移動する
    var showsMonthArrows: Bool = true

    /// 表示中の月（1日固定）
    @State private var displayedMonth: Date = Date()
    /// 表示中の週の開始日（週表示用）
    @State private var displayedWeekStart: Date = Date()
    /// 週表示中か（supportsWeekMode 有効時の既定は週表示）
    @State private var isWeekMode: Bool
    /// 年月ホイールピッカーの表示
    @State private var showingMonthPicker = false
    @State private var pickerYear = 2026
    @State private var pickerMonth = 1

    init(
        selectedDate: Binding<Date>,
        recordedDays: Set<DateComponents>,
        onSelect: ((Date) -> Void)? = nil,
        supportsWeekMode: Bool = false,
        showsTodayButton: Bool = false,
        showsMonthArrows: Bool = true
    ) {
        self._selectedDate = selectedDate
        self.recordedDays = recordedDays
        self.onSelect = onSelect
        self.supportsWeekMode = supportsWeekMode
        self.showsTodayButton = showsTodayButton
        self.showsMonthArrows = showsMonthArrows
        self._isWeekMode = State(initialValue: supportsWeekMode)
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            monthHeader
            weekdayHeader

            if isWeekMode {
                weekRow
            } else {
                dayGrid
            }

            if supportsWeekMode {
                modeToggle
            }
        }
        .onAppear {
            syncDisplayed(to: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            // 外部から日付が変わった場合も表示月/週を追従させる
            syncDisplayed(to: newValue)
        }
        .sheet(isPresented: $showingMonthPicker) {
            monthPickerSheet
        }
    }

    // MARK: 年月ホイールピッカー

    private func presentMonthPicker() {
        let comps = calendar.dateComponents([.year, .month], from: titleDate)
        pickerYear = comps.year ?? 2026
        pickerMonth = comps.month ?? 1
        showingMonthPicker = true
    }

    /// 選択可能な年の範囲（今日を中心に前後）
    private var yearRange: [Int] {
        let thisYear = calendar.component(.year, from: Date())
        return Array((thisYear - 10)...(thisYear + 10))
    }

    private var monthPickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("キャンセル") { showingMonthPicker = false }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                Spacer()
                Button("完了") {
                    if let date = calendar.date(from: DateComponents(year: pickerYear, month: pickerMonth, day: 1)) {
                        displayedMonth = date
                        displayedWeekStart = weekStart(of: date)
                    }
                    showingMonthPicker = false
                }
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.accent)
            }
            .padding(DesignSystem.Spacing.lg)

            HStack(spacing: 0) {
                Picker("年", selection: $pickerYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text("\(String(year))年").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("月", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(320)])
        .presentationBackground(DesignSystem.Colors.background)
    }

    // MARK: ヘッダー（前へ/次へ）

    private var monthHeader: some View {
        // 年月タイトルを中央レイヤーに独立させ、ボタン類とは別レイヤーにすることで
        // 「今日」ボタンの有無でタイトルがずれないよう固定する
        ZStack {
            // 年月タップでホイールピッカーを開く（横のマークなし）
            Button(action: { presentMonthPicker() }) {
                Text(titleDate.formatted(.dateTime.year().month().locale(Locale(identifier: "ja_JP"))))
                    .font(DesignSystem.Fonts.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                if showsMonthArrows {
                    Button(action: { movePrevious() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // 今日以外を選択中のみ「今日」ボタンを右端に表示
                if showsTodayButton, !calendar.isDateInToday(selectedDate) {
                    Button(action: {
                        let today = Date()
                        selectedDate = today
                        onSelect?(today)
                    }) {
                        Text("今日")
                            .font(DesignSystem.Fonts.label)
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs + 2)
                            .background(DesignSystem.Colors.accent.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if showsMonthArrows {
                    Button(action: { moveNext() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// タイトルに使う日付（週表示は週の中日で月を判定する）
    private var titleDate: Date {
        if isWeekMode {
            return calendar.date(byAdding: .day, value: 3, to: displayedWeekStart) ?? displayedWeekStart
        }
        return displayedMonth
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                Text(day)
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 週表示（1行）

    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                if let day = calendar.date(byAdding: .day, value: offset, to: displayedWeekStart) {
                    dayCell(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: 月表示（グリッド）

    private var dayGrid: some View {
        let days = daysInDisplayedMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasRecord = recordedDays.contains(calendar.dateComponents([.year, .month, .day], from: day))

        return Button(action: {
            selectedDate = day
            onSelect?(day)
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: DesignSystem.FontSize.body, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? DesignSystem.Colors.background
                            : DesignSystem.Colors.textPrimary
                    )
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            // 選択日: アクセント塗りの円
                            Circle().fill(DesignSystem.Colors.accent)
                        } else if isToday {
                            // 今日: アクセントの枠線
                            Circle().stroke(DesignSystem.Colors.accent, lineWidth: 1.5)
                        }
                    }

                // 記録のある日: ドット
                Circle()
                    .fill(hasRecord ? DesignSystem.Colors.accent.opacity(0.6) : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 週⇔月トグル

    private var modeToggle: some View {
        Button(action: {
            withAnimation(DesignSystem.Timing.spring) { isWeekMode.toggle() }
        }) {
            Image(systemName: isWeekMode ? "chevron.compact.down" : "chevron.compact.up")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isWeekMode ? "月表示に切り替え" : "週表示に切り替え")
    }

    // MARK: Helpers

    private func syncDisplayed(to date: Date) {
        displayedMonth = firstDay(of: date)
        displayedWeekStart = weekStart(of: date)
    }

    private func firstDay(of date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func weekStart(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func movePrevious() {
        if isWeekMode {
            if let moved = calendar.date(byAdding: .weekOfYear, value: -1, to: displayedWeekStart) {
                displayedWeekStart = moved
            }
        } else if let moved = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = firstDay(of: moved)
        }
    }

    private func moveNext() {
        if isWeekMode {
            if let moved = calendar.date(byAdding: .weekOfYear, value: 1, to: displayedWeekStart) {
                displayedWeekStart = moved
            }
        } else if let moved = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = firstDay(of: moved)
        }
    }

    /// 表示月の日配列（先頭は曜日合わせのため nil 埋め）
    private func daysInDisplayedMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth) // 日曜=1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        return days
    }
}

/// 月カレンダーのシート版（日付タップで確定してシートを閉じる）
struct CycleCalendarSheet: View {
    @Binding var selectedDate: Date
    let recordedDays: Set<DateComponents>
    var onSelect: ((Date) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CycleCalendarView(
                selectedDate: $selectedDate,
                recordedDays: recordedDays,
                onSelect: { date in
                    onSelect?(date)
                    dismiss()
                }
            )
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
    }
}
