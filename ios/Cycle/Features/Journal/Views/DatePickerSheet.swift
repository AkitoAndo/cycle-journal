//
//  DatePickerSheet.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// 日付選択用のシートビュー
/// [0710] 標準の graphical DatePicker から、ホームと共通の
/// CycleCalendarSheet（選択日/今日/記録のある日を区別表示）に変更。
/// 日付タップで即確定してシートが閉じる。
struct DatePickerSheet: View {
    @ObservedObject var vm: JournalViewModel
    @Binding var isPresented: Bool
    @State private var selectedDate = Date()

    /// 記録のある日 = 未削除のジャーナルエントリがある日
    private var recordedDays: Set<DateComponents> {
        let calendar = Calendar.current
        return Set(
            vm.entries
                .filter { $0.deletedAt == nil }
                .map { calendar.dateComponents([.year, .month, .day], from: $0.date) }
        )
    }

    var body: some View {
        CycleCalendarSheet(
            selectedDate: $selectedDate,
            recordedDays: recordedDays,
            onSelect: { date in
                vm.jumpToDate(date)
                isPresented = false
            }
        )
        .presentationDetents([.medium])
        .presentationBackground(DesignSystem.Colors.background)
        .onAppear {
            selectedDate = vm.selectedDate
        }
    }
}
