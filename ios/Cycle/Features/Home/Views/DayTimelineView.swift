//
//  DayTimelineView.swift
//  Cycle
//
//  1日のスケジュールを時間軸で表示するタイムラインビュー
//  （iPhoneカレンダーの「日」表示のような見た目）
//

import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var store: ScheduleStore
    let date: Date
    @Environment(\.dismiss) private var dismiss

    @State private var editTarget: ScheduleEditTarget?

    /// 1時間あたりの高さ
    private let hourHeight: CGFloat = 56
    /// 時刻ラベル列の幅
    private let labelWidth: CGFloat = 52

    private var calendar: Calendar { Calendar.current }
    private var dayEvents: [ScheduleEvent] { store.events(on: date) }
    private var timedEvents: [ScheduleEvent] { dayEvents.filter { !$0.isAllDay } }
    private var allDayEvents: [ScheduleEvent] { dayEvents.filter { $0.isAllDay } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !allDayEvents.isEmpty {
                    allDaySection
                    Divider().overlay(DesignSystem.Colors.grey.opacity(0.4))
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        timeline
                    }
                    .onAppear {
                        // 朝8時あたりが見えるようスクロール
                        proxy.scrollTo("hour-8", anchor: .top)
                    }
                }
            }
            .background(DesignSystem.Colors.backgroundGradient)
            .navigationTitle(date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))))
            .navigationBarTitleDisplayMode(.inline)
            .modifier(GlassNavBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { editTarget = .new }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("予定を追加")
                }
            }
            .sheet(item: $editTarget) { target in
                ScheduleEditView(store: store, editing: target.event, defaultDate: date)
            }
        }
        .presentationBackground(DesignSystem.Colors.background)
    }

    // MARK: - 終日

    private var allDaySection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(allDayEvents) { event in
                Button(action: { editTarget = .edit(event) }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("終日")
                            .font(DesignSystem.Fonts.caption2)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .frame(width: labelWidth - DesignSystem.Spacing.sm, alignment: .trailing)
                        eventChrome(event)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - 時間軸

    private var timeline: some View {
        ZStack(alignment: .topLeading) {
            // 時間の目盛り（各行の上端に線）
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    hourRow(hour)
                        .frame(height: hourHeight, alignment: .top)
                        .id("hour-\(hour)")
                }
            }

            // 予定ブロック（開始時刻の位置に、所要時間ぶんの高さで重ねる）
            // 時間帯が重なる予定は iPhone カレンダーのようにカラム分割して横並びにする
            GeometryReader { geo in
                let contentWidth = geo.size.width - labelWidth - DesignSystem.Spacing.md
                ForEach(positionedEvents) { item in
                    let columnGap: CGFloat = 2
                    let columns = CGFloat(item.columnCount)
                    let columnWidth = max(0, (contentWidth - columnGap * (columns - 1)) / columns)
                    eventBlock(item.event)
                        .frame(width: columnWidth, height: blockHeight(for: item.event), alignment: .top)
                        .offset(x: labelWidth + (columnWidth + columnGap) * CGFloat(item.column),
                                y: yOffset(for: item.event.startDate))
                }
            }

            // 現在時刻ライン（今日を表示中のみ。1分ごとに位置を自動更新）
            if calendar.isDateInToday(date) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    nowLine(at: context.date)
                }
            }
        }
        .frame(height: hourHeight * 24, alignment: .top)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    /// 現在時刻のライン（iPhoneカレンダーの「日」表示と同様の左端ドット付き。
    /// 色はアプリのアクセントと同じ茶色）
    private func nowLine(at now: Date) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(DesignSystem.Colors.accent)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(DesignSystem.Colors.accent)
                .frame(height: 1)
        }
        .padding(.leading, labelWidth)
        // 円の中心がちょうど現在時刻の高さに来るよう半径ぶん上へずらす
        .offset(y: yOffset(for: now) - 3.5)
        .allowsHitTesting(false)
    }

    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(String(format: "%d:00", hour))
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: labelWidth - DesignSystem.Spacing.sm, alignment: .trailing)
                .offset(y: -6)

            // 目盛り線
            Rectangle()
                .fill(DesignSystem.Colors.grey.opacity(0.4))
                .frame(height: 0.5)
                .padding(.leading, DesignSystem.Spacing.sm)
        }
    }

    // MARK: - 予定ブロック

    private func eventBlock(_ event: ScheduleEvent) -> some View {
        Button(action: { editTarget = .edit(event) }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Text(event.timeText)
                        .font(DesignSystem.Fonts.caption2)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignSystem.Colors.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 終日行の見た目（コンパクト）
    private func eventChrome(_ event: ScheduleEvent) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // 高さを固定しないと縦に伸びて行が巨大化するため 14pt に固定
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.Colors.accent)
                .frame(width: 3, height: 14)
            Text(event.title)
                .font(DesignSystem.Fonts.caption)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(DesignSystem.Colors.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Spacing.xs, style: .continuous))
    }

    // MARK: - 重なりレイアウト

    /// カラム割り当て済みの予定
    private struct PositionedEvent: Identifiable {
        let event: ScheduleEvent
        let column: Int
        let columnCount: Int
        var id: UUID { event.id }
    }

    /// 時間帯が重なる予定同士をグループ化し、グループ内で列を割り当てる。
    /// 表示上の高さ（最低30分ぶん）で重なりを判定するため、見た目の重なりと一致する。
    private var positionedEvents: [PositionedEvent] {
        let sorted = timedEvents.sorted { $0.startDate < $1.startDate }
        var result: [PositionedEvent] = []

        var cluster: [(event: ScheduleEvent, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd: Date?

        func displayedEnd(of event: ScheduleEvent) -> Date {
            // ブロックは最低30分ぶんの高さで描画されるため、判定もそれに合わせる
            max(event.endDate, event.startDate.addingTimeInterval(30 * 60))
        }

        func flushCluster() {
            let count = max(1, columnEnds.count)
            result.append(contentsOf: cluster.map {
                PositionedEvent(event: $0.event, column: $0.column, columnCount: count)
            })
            cluster.removeAll()
            columnEnds.removeAll()
            clusterEnd = nil
        }

        for event in sorted {
            let start = event.startDate
            let end = displayedEnd(of: event)

            if let currentEnd = clusterEnd, start >= currentEnd {
                flushCluster()
            }

            // 空いている一番左の列に入れる
            if let column = columnEnds.firstIndex(where: { $0 <= start }) {
                columnEnds[column] = end
                cluster.append((event, column))
            } else {
                columnEnds.append(end)
                cluster.append((event, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd ?? end, end)
        }
        flushCluster()

        return result
    }

    // MARK: - 位置計算

    /// 0時からの経過分に応じた y オフセット（グリッド上端＝0時）
    private func yOffset(for date: Date) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
        return minutes / 60 * hourHeight
    }

    private func blockHeight(for event: ScheduleEvent) -> CGFloat {
        let minutes = event.endDate.timeIntervalSince(event.startDate) / 60
        return max(hourHeight * 0.5, CGFloat(minutes) / 60 * hourHeight)
    }
}
