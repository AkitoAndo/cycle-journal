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
            }
            .sheet(isPresented: $showNewEntry) {
                JournalNewEntryView(vm: vm)
            }
            .sheet(isPresented: $vm.isSearching) {
                JournalSearchView(vm: vm)
            }
            .sheet(item: $editingEntry) { entry in
                JournalEditView(vm: vm, entry: entry)
            }
            .sheet(isPresented: $showTagManagement) {
                TagManagementView(vm: vm)
            }
            .sheet(isPresented: $showDeleted) {
                JournalDeletedView(vm: vm)
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
            weekCalendar
            entriesList
        }
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Components

    private var header: some View {
        JournalHeader(
            selectedDate: vm.selectedDate,
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
        FloatingActionButton(icon: "plus") {
            showNewEntry = true
        }
        .padding(.trailing, DesignSystem.Spacing.xl + 2)
        .padding(.bottom, DesignSystem.Spacing.xl - 2)
    }
}
