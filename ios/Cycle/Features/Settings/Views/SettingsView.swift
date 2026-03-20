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

    @State private var notificationEnabled = true
    @State private var taskReminderEnabled = true
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingDataExport = false
    @State private var showingSignOutAlert = false
    @State private var showingClearDataAlert = false
    @State private var showingComponentCatalog = false

    var body: some View {
        NavigationStack {
            List {
                // アカウントセクション
                Section("アカウント") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(DesignSystem.Fonts.screenTitle)
                            .foregroundColor(.green)

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
                }

                // 通知セクション
                Section("通知") {
                    Toggle("リマインダー通知", isOn: $notificationEnabled)
                    Toggle("タスク期限通知", isOn: $taskReminderEnabled)
                }

                // データセクション
                Section("データ") {
                    Button(action: { showingDataExport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("データをエクスポート")
                        }
                    }
                }

                // サポートセクション
                Section("サポート") {
                    Button(action: { showingPrivacyPolicy = true }) {
                        HStack {
                            Text("プライバシーポリシー")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: { showingTerms = true }) {
                        HStack {
                            Text("利用規約")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }

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
                #endif
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showingPrivacyPolicy) {
                WebDocumentView(title: "プライバシーポリシー", urlString: "https://example.com/privacy")
            }
            .sheet(isPresented: $showingTerms) {
                WebDocumentView(title: "利用規約", urlString: "https://example.com/terms")
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
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
            }
            .alert("全データを削除", isPresented: $showingClearDataAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {}
            } message: {
                Text("日記、タスク、コーチ会話の全データを削除します。この操作は取り消せません。")
            }
        }
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
    @State private var isExporting = false
    @State private var exportComplete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(DesignSystem.Fonts.heroIcon)
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("データエクスポート")
                        .font(DesignSystem.Fonts.title2)
                        .fontWeight(.bold)

                    Text("日記、会話履歴、タスクのデータを\nJSON形式でエクスポートします")
                        .font(DesignSystem.Fonts.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if exportComplete {
                    Label("エクスポート完了", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(DesignSystem.Fonts.button)
                } else {
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
                    .background(Color.blue)
                    .cornerRadius(12)
                    .disabled(isExporting)
                }
            }
            .padding()
            .navigationTitle("データエクスポート")
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

    private func exportData() {
        isExporting = true

        // TODO: 実際のエクスポート処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            exportComplete = true
        }
    }
}

#Preview {
    SettingsView()
}
