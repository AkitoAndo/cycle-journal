//
//  NetworkStatusBanner.swift
//  CycleJournal
//

import SwiftUI

struct NetworkStatusBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(DesignSystem.Fonts.caption)
                Text("オフラインです")
                    .font(DesignSystem.Fonts.caption)
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Colors.surface)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
