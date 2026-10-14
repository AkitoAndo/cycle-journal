//
//  TaskSearchView.swift
//  Cycle
//
//  タスクのワード検索（旧アーカイブ画面の検索を、タスクリストの右上メニューへ移したもの）。
//  全期間の未完了・完了タスクを対象にし、結果をタップするとその日付へ移動する。
//

import SwiftUI

struct TaskSearchView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    /// 検索結果1件分（表示する日付はタスクの日付）
    private struct Result: Identifiable {
        let task: TaskItem
        let status: TaskStatusRow.Status
        let date: Date

        var id: UUID { task.id }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 日付の新しい順に、日ごとにまとめた検索結果
    private var groupedResults: [(day: Date, results: [Result])] {
        guard !query.isEmpty else { return [] }

        let activeResults = vm.tasks
            .filter { $0.deletedAt == nil && $0.matches(query) }
            .map { Result(task: $0, status: $0.isCompleted ? .completed : .incomplete, date: $0.displayDate) }
        let archivedResults = vm.archives
            .flatMap(\.completedTasks)
            .filter { $0.matches(query) }
            .map { Result(task: $0, status: .completed, date: $0.displayDate) }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activeResults + archivedResults) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped
            .map { (day: $0.key, results: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear { isSearchFocused = true }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    // ジャーナル検索と同じ見た目のワード検索バー
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            TextField("ワードで検索", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .tint(DesignSystem.Colors.accent)
                .focused($isSearchFocused)
                .accessibilityIdentifier("task_search_field")
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .modifier(SearchBarStyle())
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        if query.isEmpty {
            EmptyStateView(icon: "magnifyingglass", title: "タイトルや振り返りの言葉で探せます")
        } else if groupedResults.isEmpty {
            EmptyStateView(icon: "magnifyingglass", title: "「\(query)」に一致するタスクはありません")
        } else {
            resultList
        }
    }

    private var resultList: some View {
        List {
            ForEach(groupedResults, id: \.day) { group in
                Section {
                    ForEach(group.results) { result in
                        TaskStatusRow(task: result.task, status: result.status)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                vm.jumpToDate(group.day)
                                dismiss()
                            }
                    }
                } header: {
                    Text(group.day.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ja_JP"))))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: DesignSystem.Spacing.lg,
                            bottom: DesignSystem.Spacing.xs,
                            trailing: DesignSystem.Spacing.lg
                        ))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Search Bar Style（ジャーナル検索と同じ）

private struct SearchBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.surfaceTinted, in: .rect(cornerRadius: DesignSystem.Spacing.md))
        } else {
            content
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.md))
        }
    }
}
