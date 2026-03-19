//
//  CycleApp.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import SwiftUI

@main
struct CycleApp: App {
    init() {
        // 背景色
        let backgroundColor = UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1.0)

        // ナビゲーションバーの設定
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowColor = .clear

        // タイトルの色を設定
        let titleColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        // 全てのナビゲーションバーに適用
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // シートの背景色を設定
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1.0)

        // リストの背景色を設定
        UITableView.appearance().backgroundColor = backgroundColor
        UICollectionView.appearance().backgroundColor = backgroundColor
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    TestDataProvider.setupIfNeeded()
                }
        }
    }
}
