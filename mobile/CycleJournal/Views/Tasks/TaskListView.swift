//
//  TaskListView.swift
//  CycleJournal
//

import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coachStore: CoachStore

    @State private var showingAddTask = false
    @State private var taskForReflection: ActionTask?
    @State private var taskForDetail: ActionTask?
    @State private var taskForEdit: ActionTask?

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // 未完了タスク
                    if !taskStore.pendingTasks.isEmpty {
                        Section("未完了") {
                            ForEach(taskStore.pendingTasks) { task in
                                TaskRowView(task: task, onComplete: {
                                    taskForReflection = task
                                })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    taskForReflection = task
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        taskForEdit = task
                                    } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        taskStore.deleteTask(task)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // 完了済みタスク
                    if !taskStore.completedTasks.isEmpty {
                        Section("完了済み") {
                            ForEach(taskStore.completedTasks) { task in
                                CompletedTaskRowView(task: task)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        taskForDetail = task
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            taskForEdit = task
                                        } label: {
                                            Label("編集", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            taskStore.deleteTask(task)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    // タスクがない場合
                    if taskStore.tasks.isEmpty {
                        ContentUnavailableView(
                            "タスクがありません",
                            systemImage: "checkmark.circle",
                            description: Text("コーチとの会話で提案されたタスクがここに表示されます")
                        )
                    }
                }

                // 右下フローティング+ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddTask = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("行動タスク")
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(editingTask: nil)
                    .environmentObject(taskStore)
            }
            .sheet(item: $taskForEdit) { task in
                AddTaskView(editingTask: task)
                    .environmentObject(taskStore)
            }
            .sheet(item: $taskForReflection) { task in
                TaskReflectionView(task: task)
                    .environmentObject(taskStore)
            }
            .sheet(item: $taskForDetail) { task in
                TaskDetailView(task: task)
                    .environmentObject(taskStore)
            }
        }
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: ActionTask
    let onComplete: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            // 完了ボタン
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)

                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("期限: \(dateFormatter.string(from: dueDate))")
                            .font(.caption)
                    }
                    .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                }

                if let description = task.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Date()
    }
}

// MARK: - Completed Task Row View

struct CompletedTaskRowView: View {
    let task: ActionTask

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough()
                    .foregroundColor(.secondary)

                if let completedAt = task.completedAt {
                    Text("完了: \(dateFormatter.string(from: completedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if task.reflection != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                        Text("ふりかえり済み")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Task View

struct AddTaskView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss

    let editingTask: ActionTask?

    @State private var title = ""
    @State private var description = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    private var isEditing: Bool {
        editingTask != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク内容") {
                    TextField("タイトル", text: $title)

                    TextField("詳細（任意）", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section {
                    Toggle("期限を設定", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("期限", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(isEditing ? "タスクを編集" : "タスクを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "追加") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let task = editingTask {
                    title = task.title
                    description = task.description ?? ""
                    hasDueDate = task.dueDate != nil
                    dueDate = task.dueDate ?? Date()
                }
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingTask = editingTask {
            taskStore.updateTask(
                existingTask,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                dueDate: hasDueDate ? dueDate : nil
            )
        } else {
            taskStore.addTask(
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                dueDate: hasDueDate ? dueDate : nil
            )
        }

        dismiss()
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss
    let task: ActionTask

    @State private var showingReflectionEdit = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    // taskStoreから最新のタスクを取得
    private var currentTask: ActionTask {
        taskStore.tasks.first { $0.id == task.id } ?? task
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // タスク情報
                    taskInfoSection

                    // ふりかえり
                    if let reflection = currentTask.reflection {
                        reflectionSection(reflection)
                    } else {
                        noReflectionSection
                    }
                }
                .padding()
            }
            .navigationTitle("タスク詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReflectionEdit) {
                TaskReflectionView(task: currentTask, isEditMode: true)
                    .environmentObject(taskStore)
            }
        }
    }

    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)

                    if let completedAt = task.completedAt {
                        Text("完了: \(dateFormatter.string(from: completedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let description = task.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func reflectionSection(_ reflection: TaskReflection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("ふりかえり")
                    .font(.headline)

                Spacer()

                Button(action: {
                    showingReflectionEdit = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("編集")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                reflectionItem(title: "事実の確認", icon: "eye", content: reflection.fact)
                reflectionItem(title: "感情の観察", icon: "heart", content: reflection.emotion)
                reflectionItem(title: "学びの抽出", icon: "lightbulb", content: reflection.learning)
                reflectionItem(title: "次への調整", icon: "arrow.right.circle", content: reflection.nextStep)
            }
        }
    }

    private func reflectionItem(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.green)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Text(content.isEmpty ? "（未入力）" : content)
                .font(.body)
                .foregroundColor(content.isEmpty ? .secondary : .primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var noReflectionSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("ふりかえりはまだありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    TaskListView()
        .environmentObject(TaskStore())
        .environmentObject(CoachStore())
}
