//
//  DatePickerSheet.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/29.
//

import SwiftUI

/// 日付選択用のシートビュー
struct DatePickerSheet: View {
    @ObservedObject var vm: JournalViewModel
    @Binding var isPresented: Bool
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "年月を選択",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(DesignSystem.Colors.accent)
                .padding()

                Spacer()
            }
            .navigationTitle("年月を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        vm.jumpToDate(selectedDate)
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selectedDate = vm.selectedDate
        }
    }
}
