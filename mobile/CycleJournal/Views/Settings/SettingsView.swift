//
//  SettingsView.swift
//  CycleJournal
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var diaryStore: DiaryStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coachStore: CoachStore

    @State private var notificationEnabled = true
    @State private var taskReminderEnabled = true
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingDataExport = false
    @State private var showingSignOutAlert = false
    @State private var showingClearDataAlert = false
    @State private var showingSampleDataAdded = false

    var body: some View {
        NavigationStack {
            List {
                // アカウントセクション
                Section("アカウント") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            if let user = authStore.currentUser {
                                Text(user.fullName ?? user.email ?? "ユーザー")
                                    .font(.headline)
                                if let email = user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("ログイン済み")
                                    .font(.headline)
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
                    Button(action: addSampleData) {
                        HStack {
                            Image(systemName: "plus.square.on.square")
                            Text("サンプルデータを追加")
                        }
                    }

                    Button(role: .destructive, action: { showingClearDataAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("全データを削除")
                        }
                    }

                    HStack {
                        Text("日記")
                        Spacer()
                        Text("\(diaryStore.entries.count)件")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("タスク")
                        Spacer()
                        Text("\(taskStore.tasks.count)件")
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
            .alert("全データを削除", isPresented: $showingClearDataAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("日記、タスク、コーチ会話の全データを削除します。この操作は取り消せません。")
            }
            .alert("サンプルデータ追加完了", isPresented: $showingSampleDataAdded) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("サンプルの日記とタスクを追加しました。")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func addSampleData() {
        // サンプル日記を追加
        let sampleDiaries = [
            DiaryEntry(
                content: "今日は朝から気持ちのいい天気だった。久しぶりにランニングをして、心がすっきりした。小さなことでも体を動かすと気分が変わるなと実感。",
                createdAt: Date().addingTimeInterval(-86400 * 2),
                tags: ["運動", "気づき"]
            ),
            DiaryEntry(
                content: "仕事でミスをしてしまった。落ち込んだけど、上司が「失敗は成長のチャンス」と言ってくれた。その言葉に救われた。",
                createdAt: Date().addingTimeInterval(-86400),
                tags: ["仕事", "感謝"]
            ),
            DiaryEntry(
                content: "週末に友達と久しぶりに会えた。笑い合える人がいることのありがたさを感じた一日。",
                createdAt: Date(),
                tags: ["友人", "幸せ"]
            ),
        ]

        for diary in sampleDiaries {
            diaryStore.addEntry(diary)
        }

        // サンプルタグを追加
        diaryStore.createTag("運動")
        diaryStore.createTag("仕事")
        diaryStore.createTag("感謝")
        diaryStore.createTag("気づき")
        diaryStore.createTag("友人")
        diaryStore.createTag("幸せ")

        // サンプルタスクを追加
        let sampleTasks = [
            ActionTask(
                title: "朝10分の瞑想を試す",
                description: "心を落ち着ける時間を作ってみる",
                dueDate: Date().addingTimeInterval(86400 * 3)
            ),
            ActionTask(
                title: "感謝日記を1週間続ける",
                description: "毎日3つ、感謝することを書き出す"
            ),
            ActionTask(
                title: "週末に散歩する",
                description: "近くの公園を30分歩く",
                dueDate: Date().addingTimeInterval(86400 * 5)
            ),
        ]

        for task in sampleTasks {
            taskStore.addTask(task)
        }

        showingSampleDataAdded = true
    }

    private func clearAllData() {
        // 日記を全削除
        for entry in diaryStore.entries {
            diaryStore.deleteEntry(entry)
        }

        // タスクを全削除
        for task in taskStore.tasks {
            taskStore.deleteTask(task)
        }

        // コーチ会話を全削除
        for session in coachStore.sessions {
            coachStore.deleteSession(session)
        }
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
                // TODO: WKWebView で実際のURLを表示
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
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("データエクスポート")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("日記、会話履歴、タスクのデータを\nJSON形式でエクスポートします")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if exportComplete {
                    Label("エクスポート完了", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                } else {
                    Button(action: exportData) {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("エクスポートする")
                        }
                    }
                    .font(.headline)
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
