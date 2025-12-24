//
//  JournalListView.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/09.
//

import SwiftUI

/// ジャーナルのメインビュー
/// 日付選択、エントリ一覧表示、新規作成を担当
struct JournalListView: View {
    @StateObject private var vm = JournalViewModel()
    @State private var showDatePicker = false
    @State private var showNewEntry = false
    @State private var editingEntry: JournalEntry?
    @State private var showTagManagement = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // カスタムヘッダー（年月とメニュー）
                HStack(alignment: .center) {
                    Text(vm.selectedDate.formatted(.dateTime.year().month(.wide)))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Menu {
                        Button(action: { vm.isSearching = true }) {
                            Label("検索", systemImage: "magnifyingglass")
                        }

                        Button(action: { showDatePicker = true }) {
                            Label("日付選択", systemImage: "calendar")
                        }

                        Button(action: { showTagManagement = true }) {
                            Label("タグ管理", systemImage: "tag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.background)

                // 週カレンダー
                WeekCalendarView(vm: vm)
                    .padding(.bottom, DesignSystem.Spacing.lg)

                // エントリ一覧
                entriesListView
            }
            .background(DesignSystem.Colors.background)

            // 新規作成ボタン（オーバーレイ）
            FloatingActionButton(icon: "plus") {
                showNewEntry = true
            }
            .padding(.trailing, DesignSystem.Spacing.xl + 2)
            .padding(.bottom, DesignSystem.Spacing.xl - 2)
        }
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
    }

    // MARK: - Subviews

    /// エントリ一覧表示
    private var entriesListView: some View {
        List {
            ForEach(vm.todays) { entry in
                JournalEntryRow(
                    entry: entry,
                    onEdit: { editingEntry = entry },
                    onDelete: {
                        withAnimation {
                            vm.deleteEntry(entry)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
    }

}
