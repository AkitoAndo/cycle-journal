//
//  RecordsView.swift
//  Cycle
//
//  「記録」タブ（U-04）。日記と一歩を日付で見る画面。
//  いまは暫定で、上の切り替えで既存の日記一覧とタスク一覧を出し分ける。
//  U-04 の実装単位2で、1画面に「日記」と「一歩」の2つのリストを並べる形に置き換える。
//

import SwiftUI

struct RecordsView: View {
    private enum Kind: String, CaseIterable, Identifiable {
        case journal = "日記"
        case steps = "一歩"
        var id: Self { self }
    }

    @State private var kind: Kind = .journal

    var body: some View {
        VStack(spacing: 0) {
            Picker("記録の種類", selection: $kind) {
                ForEach(Kind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)

            switch kind {
            case .journal:
                JournalListView()
            case .steps:
                TaskListView()
            }
        }
        .background(DesignSystem.Colors.backgroundGradient)
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack { RecordsView() }
        .environmentObject(JournalViewModel())
        .environmentObject(TaskViewModel())
        .environmentObject(CoachStore())
}
