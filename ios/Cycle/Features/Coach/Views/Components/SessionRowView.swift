//
//  SessionRowView.swift
//  CycleJournal
//

import SwiftUI

struct SessionRowView: View {
    let session: CoachSession

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // アーカイブ画面と同じ「2026年7月11日 土曜日」形式に統一
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(session.summary ?? session.firstUserMessage ?? "会話")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    if let emotion = session.emotionLabel {
                        Text(emotion)
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }

                    Text(dateFormatter.string(from: session.createdAt))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()
            }
        }
    }
}
