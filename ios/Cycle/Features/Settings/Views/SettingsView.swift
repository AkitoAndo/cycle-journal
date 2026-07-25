//
//  SettingsView.swift
//  CycleJournal
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var journalViewModel: JournalViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @EnvironmentObject var coachStore: CoachStore

    @State private var notificationSettings = NotificationSettingsStore.load()
    /// タスク完了チェック時に事後情報フォームを出すか（TaskListView と共有）
    @AppStorage("isPostActionPromptEnabled") private var isPostActionPromptEnabled = true
    @State private var systemPermissionGranted = false
    @State private var showingDataExport = false
    @State private var showingSignOutAlert = false
    @State private var showingClearDataAlert = false
    @State private var showingComponentCatalog = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false

    private let privacyURL = "https://akitoando.github.io/cycle-journal/legal/PRIVACY_POLICY.html"
    private let termsURL = "https://akitoando.github.io/cycle-journal/legal/TERMS_OF_SERVICE.html"

    var body: some View {
        NavigationStack {
            List {
                // アカウントセクション
                Section("アカウント") {
                    if authStore.state.isAuthenticated {
                        // ログイン済み
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(DesignSystem.Fonts.screenTitle)
                                .foregroundColor(DesignSystem.Colors.accent)

                            VStack(alignment: .leading) {
                                if let user = authStore.currentUser {
                                    Text(user.fullName ?? user.email ?? "ユーザー")
                                        .font(DesignSystem.Fonts.button)
                                    if let email = user.email {
                                        Text(email)
                                            .font(DesignSystem.Fonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("ログイン済み")
                                        .font(DesignSystem.Fonts.button)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive, action: { showingSignOutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("サインアウト")
                            }
                        }

                        Button(role: .destructive, action: { showingDeleteAccountAlert = true }) {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "trash")
                                }
                                Text(isDeletingAccount ? "アカウントを削除中..." : "アカウントを削除")
                            }
                        }
                        .disabled(isDeletingAccount)
                        .accessibilityIdentifier("delete_account_button")
                    } else {
                        // 未ログイン
                        HStack {
                            Image(systemName: "person.circle")
                                .font(DesignSystem.Fonts.screenTitle)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading) {
                                Text("未ログイン")
                                    .font(DesignSystem.Fonts.button)
                                Text("サインインするとコーチ機能が使えます")
                                    .font(DesignSystem.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button(action: { authStore.signInWithApple() }) {
                            HStack {
                                Image(systemName: "apple.logo")
                                Text("Appleでサインイン")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .foregroundColor(Color(uiColor: .systemBackground))
                            .cornerRadius(8)
                        }
                        .disabled(authStore.isLoading)

                        if authStore.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("サインイン中...")
                                    .font(DesignSystem.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let error = authStore.error {
                            Text(error)
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(GlassListRowBackground())

                // Premium セクション
                Section("Premium") {
                    premiumRow
                }
                .listRowBackground(GlassListRowBackground())

                // 通知セクション
                Section("通知") {
                    if !systemPermissionGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("通知が許可されていません")
                                .font(DesignSystem.Fonts.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(DesignSystem.Fonts.caption)
                        }
                    }

                    Toggle("リマインダー通知", isOn: $notificationSettings.isReminderEnabled)
                        .onChange(of: notificationSettings.isReminderEnabled) { _, newValue in
                            handleReminderToggle(newValue)
                        }

                    if notificationSettings.isReminderEnabled {
                        DatePicker(
                            "リマインダー時刻",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: notificationSettings.reminderHour) { _, _ in
                            updateReminderSchedule()
                        }
                        .onChange(of: notificationSettings.reminderMinute) { _, _ in
                            updateReminderSchedule()
                        }
                    }
                }
                .listRowBackground(GlassListRowBackground())

                // タスクセクション
                Section("タスク") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Toggle("完了時に事後情報を記入", isOn: $isPostActionPromptEnabled)
                        Text("タスクをチェックした時に、事実・気づき・次の一手の入力フォームを表示します")
                            .font(DesignSystem.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(GlassListRowBackground())

                // データセクション
                Section("データ") {
                    Button(action: { showingDataExport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("データをエクスポート")
                        }
                    }
                }
                .listRowBackground(GlassListRowBackground())

                // サポートセクション
                Section("サポート") {
                    if let url = URL(string: privacyURL) {
                        Link(destination: url) {
                            HStack {
                                Text("プライバシーポリシー")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }

                    if let url = URL(string: termsURL) {
                        Link(destination: url) {
                            HStack {
                                Text("利用規約")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }

                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(GlassListRowBackground())

                // デバッグセクション（開発用）
                #if DEBUG
                Section("開発者オプション") {
                    Button(action: { showingComponentCatalog = true }) {
                        HStack {
                            Image(systemName: "paintpalette")
                            Text("Component Catalog")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    HStack {
                        Text("日記")
                        Spacer()
                        Text("\(journalViewModel.allEntries.count)件")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("タスク")
                        Spacer()
                        Text("\(taskViewModel.tasks.count)件")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("コーチ会話")
                        Spacer()
                        Text("\(coachStore.sessions.count)件")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(GlassListRowBackground())
                #endif
            }
            .navigationTitle("マイページ")
            .modifier(GlassNavBarModifier())
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.backgroundGradient)
            .tint(DesignSystem.Colors.accent)
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
                    .environmentObject(journalViewModel)
                    .environmentObject(taskViewModel)
                    .environmentObject(coachStore)
                    .softSheet()
            }
            .alert("サインアウト", isPresented: $showingSignOutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("サインアウト", role: .destructive) {
                    authStore.signOut()
                }
            } message: {
                Text("本当にサインアウトしますか？\nローカルデータは保持されます。")
            }
            .sheet(isPresented: $showingComponentCatalog) {
                ComponentCatalogView()
                    .softSheet()
            }
            .alert("全データを削除", isPresented: $showingClearDataAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {}
            } message: {
                Text("日記、タスク、コーチ会話の全データを削除します。この操作は取り消せません。")
            }
            .alert("アカウントを削除", isPresented: $showingDeleteAccountAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        await authStore.deleteAccount()
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("アカウントとすべてのデータ（日記・タスク・コーチ会話）がサーバーから完全に削除されます。\nこの操作は取り消せません。")
            }
            .task {
                await checkNotificationPermission()
            }
        }
    }

    // MARK: - Premium Row

    @ViewBuilder
    private var premiumRow: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(DesignSystem.Colors.accent)
            VStack(alignment: .leading) {
                Text("Cycle Premium")
                    .font(DesignSystem.Fonts.button)
                Text("MVP期間中は無料で利用できます")
                    .font(DesignSystem.Fonts.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Notification Helpers

    /// リマインダー時刻のバインディング
    private var reminderTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = notificationSettings.reminderHour
                components.minute = notificationSettings.reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationSettings.reminderHour = components.hour ?? 21
                notificationSettings.reminderMinute = components.minute ?? 0
                NotificationSettingsStore.save(notificationSettings)
            }
        )
    }

    /// 通知権限を確認
    private func checkNotificationPermission() async {
        let status = await NotificationManager.shared.checkPermissionStatus()
        systemPermissionGranted = (status == .authorized)
    }

    /// リマインダートグルのハンドリング
    private func handleReminderToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationManager.shared.requestPermission()
                systemPermissionGranted = granted
                if granted {
                    NotificationManager.shared.scheduleDailyReminder(
                        hour: notificationSettings.reminderHour,
                        minute: notificationSettings.reminderMinute
                    )
                } else {
                    notificationSettings.isReminderEnabled = false
                }
                NotificationSettingsStore.save(notificationSettings)
            }
        } else {
            NotificationManager.shared.cancelDailyReminder()
            NotificationSettingsStore.save(notificationSettings)
        }
    }

    /// リマインダースケジュールを更新
    private func updateReminderSchedule() {
        guard notificationSettings.isReminderEnabled else { return }
        NotificationManager.shared.scheduleDailyReminder(
            hour: notificationSettings.reminderHour,
            minute: notificationSettings.reminderMinute
        )
        NotificationSettingsStore.save(notificationSettings)
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Web Document View

struct WebDocumentView: View {
    let title: String
    let urlString: String

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("ここに\(title)が表示されます")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var journalViewModel: JournalViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @EnvironmentObject var coachStore: CoachStore

    @State private var selectedFormat: ExportFormat = .json
    @State private var showShareSheet = false
    @State private var exportFileURL: URL?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(DesignSystem.Fonts.heroIcon)
                    .foregroundColor(DesignSystem.Colors.accent)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("データエクスポート")
                        .font(DesignSystem.Fonts.title2)
                        .fontWeight(.bold)

                    Text("日記、タスク、振り返り、コーチ会話の\nデータをエクスポートします")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // フォーマット選択
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("エクスポート形式")
                        .font(DesignSystem.Fonts.headline)

                    Picker("形式", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // データ概要
                VStack(spacing: DesignSystem.Spacing.sm) {
                    dataCountRow(label: "ジャーナル", count: journalViewModel.allEntries.filter { $0.deletedAt == nil }.count)
                    dataCountRow(label: "タスク", count: taskViewModel.tasks.filter { $0.deletedAt == nil }.count)
                    dataCountRow(label: "アーカイブ", count: taskViewModel.archives.count)
                    dataCountRow(label: "コーチセッション", count: coachStore.sessions.count)
                }
                .padding(.horizontal)

                Spacer()

                // エクスポートボタン
                Button(action: exportData) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("エクスポートする")
                    }
                }
                .font(DesignSystem.Fonts.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DesignSystem.Colors.accentGradient)
                .cornerRadius(12)
                .disabled(isExporting)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("データエクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Helpers

    private func dataCountRow(label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Fonts.body)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)件")
                .font(DesignSystem.Fonts.body)
                .foregroundColor(.secondary)
        }
    }

    private func exportData() {
        isExporting = true

        let journals = journalViewModel.allEntries
        let tasks = taskViewModel.tasks
        let archives = taskViewModel.archives
        let sessions = coachStore.sessions

        DispatchQueue.global(qos: .userInitiated).async {
            let data: Data
            switch selectedFormat {
            case .json:
                data = DataExportService.exportJSON(
                    journals: journals,
                    tasks: tasks,
                    archives: archives,
                    sessions: sessions
                )
            case .csv:
                data = DataExportService.exportCSV(
                    journals: journals,
                    tasks: tasks,
                    archives: archives,
                    sessions: sessions
                )
            }

            let fileURL = DataExportService.createTemporaryFile(data: data, format: selectedFormat)

            DispatchQueue.main.async {
                isExporting = false
                if let url = fileURL {
                    exportFileURL = url
                    showShareSheet = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
