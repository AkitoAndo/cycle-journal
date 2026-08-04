//
//  JournalListView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// ジャーナルのメインビュー
///
/// 日付選択、エントリ一覧表示、新規作成を担当します。
/// - 週カレンダーで日付を選択
/// - 選択された日のエントリを表示
/// - エントリの追加、編集、削除、検索機能
struct JournalListView: View {
    // MARK: - Properties

    @EnvironmentObject private var vm: JournalViewModel
    @State private var showDatePicker = false
    @State private var showNewEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var showTagManagement = false
    @State private var showDeleted = false

    // MARK: - Body

    var body: some View {
        content
            .navigationBarHidden(true)
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(vm: vm, isPresented: $showDatePicker)
                    .softSheet()
            }
            .sheet(isPresented: $showNewEntry) {
                JournalNewEntryView(vm: vm)
                    .softSheet()
            }
            .sheet(isPresented: $vm.isSearching) {
                JournalSearchView(vm: vm)
                    .softSheet()
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditView(vm: vm, entry: entry)
                    .softSheet()
            }
            .sheet(isPresented: $showTagManagement) {
                TagManagementView(vm: vm)
                    .softSheet()
            }
            .sheet(isPresented: $showDeleted) {
                JournalDeletedView(vm: vm)
                    .softSheet()
            }
    }

    // MARK: - Content

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            floatingActionButton
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if vm.todays.isEmpty {
                // タスク画面と同じ位置に空表示を出すため、週カレンダーの高さに
                // 影響されないようヘッダー直下の全域に中央寄せする
                ZStack {
                    VStack(spacing: 0) {
                        weekCalendar
                        Spacer()
                    }
                    emptyStateMessage
                }
            } else {
                weekCalendar
                entriesList
            }
        }
        .background(DesignSystem.Colors.backgroundGradient)
    }

    private var emptyStateMessage: some View {
        EmptyStateView(
            icon: "leaf",
            title: "この日の記録はありません",
            titleColor: DesignSystem.Colors.textTertiary
        )
    }

    // MARK: - Components

    private var header: some View {
        JournalHeader(
            selectedDate: vm.selectedDate,
            streakDays: vm.streakDays,
            onToday: {
                withAnimation(DesignSystem.Timing.bouncySpring) {
                    vm.selectedDate = Date()
                    vm.currentWeekOffset = 0
                }
            },
            onShowSearch: {
                vm.isSearching = true
            },
            onShowDatePicker: {
                showDatePicker = true
            },
            onShowTagManagement: {
                showTagManagement = true
            },
            onShowDeleted: {
                showDeleted = true
            }
        )
    }

    private var weekCalendar: some View {
        WeekCalendarView(vm: vm)
            .padding(.bottom, DesignSystem.Spacing.sm)
    }

    // 非空時のみ使用（空表示は mainContent 側で中央寄せする）
    private var entriesList: some View {
        JournalEntriesList(
            entries: vm.todays,
            onEdit: { entry in
                editingEntry = entry
            },
            onDelete: { entry in
                vm.deleteEntry(entry)
            }
        )
    }

    private var floatingActionButton: some View {
        FloatingActionButton(icon: "plus", accessibilityIdentifier: "journal_fab_plus") {
            showNewEntry = true
        }
        .padding(.trailing, 40)
        .padding(.bottom, 40)
    }
}
