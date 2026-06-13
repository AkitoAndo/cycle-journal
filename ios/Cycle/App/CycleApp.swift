//
//  CycleApp.swift
//  Cycle
//
//  Created by Takeshi Ogata on 2025/11/08.
//

import GoogleSignIn
import SwiftUI
import UserNotifications

/// フォアグラウンドでの通知表示を制御するAppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        APNsDeviceTokenRegistry.save(token)
        Task {
            try? await SubscriptionService().registerAPNsDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard userInfo["cycle_event"] as? String == "cancel_trial_notifications" else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            TrialNotificationScheduler.shared.cancelAllTrialNotifications()
            completionHandler(.newData)
        }
    }

    /// フォアグラウンドで通知を受信した場合にバナーとサウンドで表示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct CycleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Google Sign-In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "1031235624127-6fgcbv1khltu4snpktpdd0cab025coab.apps.googleusercontent.com"
        )

        let backgroundColor = DesignSystem.Colors.backgroundUIColor
        let titleColor = DesignSystem.Colors.textPrimaryUIColor

        // iOS 26+: 透明ナビバー（Liquid Glass はSwiftUI側で適用）
        if #available(iOS 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: titleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        } else {
            // iOS 25以下: ソリッド背景
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.foregroundColor: titleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }

        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = DesignSystem.Colors.accentUIColor

        UITableView.appearance().backgroundColor = backgroundColor
        UICollectionView.appearance().backgroundColor = backgroundColor
    }

    // true にすると起動時に Component Catalog を直接表示（開発確認用）
    private let showCatalog = false

    @StateObject private var journalViewModel = JournalViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var coachStore = CoachStore()
    @StateObject private var meditationStore = MeditationStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            if showCatalog {
                NavigationStack {
                    ComponentCatalogView()
                }
            } else {
                ContentView()
                    .environmentObject(journalViewModel)
                    .environmentObject(taskViewModel)
                    .environmentObject(coachStore)
                    .environmentObject(meditationStore)
                    .environmentObject(authStore)
                    .environmentObject(subscriptionStore)
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
                    .task {
                        TestDataProvider.setupIfNeeded()
                        TestDataProvider.setupSync()
                        journalViewModel.reloadData()
                        taskViewModel.reloadData()
                    }
            }
        }
    }
}
