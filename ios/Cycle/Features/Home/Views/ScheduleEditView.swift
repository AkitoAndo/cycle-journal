//
//  ScheduleEditView.swift
//  Cycle
//
//  アプリ独自の予定の追加・編集フォーム（Liquid Glass のカード型入力欄）
//

import SwiftUI

/// 予定編集シートの対象（.sheet(item:) 用）
enum ScheduleEditTarget: Identifiable {
    case new
    case edit(ScheduleEvent)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let event): return event.id.uuidString
        }
    }

    /// 編集対象の予定（新規は nil）
    var event: ScheduleEvent? {
        switch self {
        case .new: return nil
        case .edit(let event): return event
        }
    }
}

struct ScheduleEditView: View {
    @ObservedObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    /// 編集対象。新規追加時は nil
    let editing: ScheduleEvent?
    /// 新規追加時の初期日
    let defaultDate: Date

    @State private var title: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false

    private var isEditing: Bool { editing != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // タイトル
                    SurfaceCard {
                        TextField("タイトル", text: $title)
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .tint(DesignSystem.Colors.accent)
                    }

                    // 日時
                    SurfaceCard {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Toggle("終日", isOn: $isAllDay)
                                .tint(DesignSystem.Colors.accent)

                            Divider().overlay(DesignSystem.Colors.grey.opacity(0.4))

                            DatePicker(
                                "開始",
                                selection: $startDate,
                                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                            )

                            if !isAllDay {
                                DatePicker(
                                    "終了",
                                    selection: $endDate,
                                    in: startDate...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                            }
                        }
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .tint(DesignSystem.Colors.accent)
                    }

                    // メモ
                    SurfaceCard {
                        TextField("メモ", text: $notes, axis: .vertical)
                            .font(DesignSystem.Fonts.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .tint(DesignSystem.Colors.accent)
                            .lineLimit(3...6)
                    }

                    if isEditing {
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Text("この予定を削除")
                                .font(DesignSystem.Fonts.body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.backgroundGradient)
            .navigationTitle(isEditing ? "予定を編集" : "予定を追加")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .alert("この予定を削除しますか？", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    if let editing { store.delete(editing) }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .onAppear(perform: setup)
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    private func setup() {
        if let editing {
            title = editing.title
            isAllDay = editing.isAllDay
            startDate = editing.startDate
            endDate = editing.endDate
            notes = editing.notes
        } else {
            let calendar = Calendar.current
            let base: Date
            if calendar.isDateInToday(defaultDate) {
                base = Date()
            } else {
                base = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
            }
            startDate = base
            endDate = calendar.date(byAdding: .hour, value: 1, to: base) ?? base
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let fixedEnd = endDate < startDate ? startDate : endDate

        if var editing {
            editing.title = trimmed
            editing.isAllDay = isAllDay
            editing.startDate = startDate
            editing.endDate = fixedEnd
            editing.notes = notes
            store.update(editing)
        } else {
            let event = ScheduleEvent(
                title: trimmed,
                startDate: startDate,
                endDate: fixedEnd,
                isAllDay: isAllDay,
                notes: notes
            )
            store.add(event)
        }
        dismiss()
    }
}
