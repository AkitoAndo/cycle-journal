//
//  SheetAppearance.swift
//  Cycle
//
//  シート（モーダル）の共通外観
//

import SwiftUI

extension View {
    /// アプリ共通のシート外観（大きめの角丸 + ドラッグインジケーター）
    ///
    /// 使用例:
    /// ```swift
    /// .sheet(isPresented: $showSheet) {
    ///     SomeSheetView()
    ///         .softSheet()
    /// }
    /// ```
    func softSheet() -> some View {
        self
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
    }
}
