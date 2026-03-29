//
//  ShareSheet.swift
//  Cycle
//
//  Created for CycleJournal data export feature.
//

import SwiftUI
import UIKit

/// iOS共有シートのSwiftUIラッパー
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
