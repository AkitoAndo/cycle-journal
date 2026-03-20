//
//  SessionRowView.swift
//  CycleJournal
//

import SwiftUI

struct SessionRowView: View {
    let session: CoachSession

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        SurfaceCard {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(dateFormatter.string(from: session.createdAt))
                        .font(DesignSystem.Fonts.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text(session.summary ?? session.firstUserMessage ?? "会話")
                        .font(DesignSystem.Fonts.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    if let emotion = session.emotionLabel {
                        Text(emotion)
                            .font(DesignSystem.Fonts.caption)
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }
}
