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
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: session.createdAt))
                        .font(DesignSystem.Fonts.subheadline)
                        .foregroundColor(.secondary)

                    Text(session.summary ?? session.firstUserMessage ?? "会話")
                        .font(DesignSystem.Fonts.body)
                        .lineLimit(1)

                    if let emotion = session.emotionLabel {
                        Text(emotion)
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
}
