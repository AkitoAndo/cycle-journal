//
//  TaskReflectionView.swift
//  CycleJournal
//

import SwiftUI

struct TaskReflectionView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) var dismiss

    let task: ActionTask
    var isEditMode: Bool = false  // 編集モードかどうか

    @State private var fact = ""        // 事実の確認
    @State private var emotion = ""     // 感情の観察
    @State private var learning = ""    // 学びの抽出
    @State private var nextStep = ""    // 次への調整
    @State private var currentStep = 0
    @State private var showingCompletion = false

    private let steps = [
        ReflectionStep(
            number: 1,
            title: "事実の確認",
            question: "何をした？",
            placeholder: "今回、どんな行動を試したか教えてね",
            icon: "eye"
        ),
        ReflectionStep(
            number: 2,
            title: "感情の観察",
            question: "どう感じた？",
            placeholder: "その最中や終わった後、どんな気持ちだった？",
            icon: "heart"
        ),
        ReflectionStep(
            number: 3,
            title: "学びの抽出",
            question: "何に気づいた？",
            placeholder: "この体験から、どんなことに気づいた？",
            icon: "lightbulb"
        ),
        ReflectionStep(
            number: 4,
            title: "次への調整",
            question: "次はどうする？",
            placeholder: "次にもう一度試すとしたら、どこを変えてみたい？",
            icon: "arrow.right.circle"
        )
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // プログレスバー
                progressBar

                // コンテンツ
                ScrollView {
                    VStack(spacing: 24) {
                        // タスク情報
                        taskInfo

                        // 現在のステップ
                        currentStepView
                    }
                    .padding()
                }

                // ナビゲーションボタン
                navigationButtons
            }
            .navigationTitle(isEditMode ? "ふりかえりを編集" : "ふりかえり")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                if !isEditMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("スキップ") {
                            skipReflection()
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingCompletion) {
                ReflectionCompletionView(task: task, isEditMode: isEditMode, onDismiss: {
                    dismiss()
                })
            }
            .onAppear {
                // 編集モードの場合、既存データを読み込む
                if isEditMode, let reflection = task.reflection {
                    fact = reflection.fact
                    emotion = reflection.emotion
                    learning = reflection.learning
                    nextStep = reflection.nextStep
                }
            }
        }
    }

    // MARK: - Components

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(index <= currentStep ? Color.green : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var taskInfo: some View {
        VStack(spacing: 8) {
            Image(systemName: isEditMode ? "pencil.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(isEditMode ? .orange : .green)

            Text(task.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(isEditMode ? "ふりかえりを編集しよう" : "お疲れさま。ふりかえりを始めよう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var currentStepView: some View {
        let step = steps[currentStep]

        return VStack(alignment: .leading, spacing: 16) {
            // ステップヘッダー
            HStack {
                Image(systemName: step.icon)
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading) {
                    Text("Step \(step.number)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(step.title)
                        .font(.headline)
                }
            }

            // 質問
            Text(step.question)
                .font(.title3)
                .fontWeight(.medium)

            // 入力フィールド
            TextEditor(text: bindingForStep(currentStep))
                .frame(minHeight: 120)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if textForStep(currentStep).isEmpty {
                            Text(step.placeholder)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }
                    },
                    alignment: .topLeading
                )

            // ヒント
            if !step.placeholder.isEmpty {
                Text("浮かんでこなければ、そのままで大丈夫だよ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // 戻るボタン
            if currentStep > 0 {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            // 次へ/保存ボタン
            Button(action: nextStepOrSave) {
                HStack {
                    Text(currentStep < 3 ? "次へ" : "保存する")
                    if currentStep < 3 {
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func bindingForStep(_ step: Int) -> Binding<String> {
        switch step {
        case 0: return $fact
        case 1: return $emotion
        case 2: return $learning
        case 3: return $nextStep
        default: return $fact
        }
    }

    private func textForStep(_ step: Int) -> String {
        switch step {
        case 0: return fact
        case 1: return emotion
        case 2: return learning
        case 3: return nextStep
        default: return ""
        }
    }

    private func previousStep() {
        withAnimation {
            currentStep = max(0, currentStep - 1)
        }
    }

    private func nextStepOrSave() {
        if currentStep < 3 {
            withAnimation {
                currentStep += 1
            }
        } else {
            saveReflection()
        }
    }

    private func saveReflection() {
        let reflection = TaskReflection(
            fact: fact,
            emotion: emotion,
            learning: learning,
            nextStep: nextStep
        )

        taskStore.addReflection(to: task, reflection: reflection)
        showingCompletion = true
    }

    private func skipReflection() {
        // 振り返りなしでタスクを完了状態にする
        taskStore.updateTaskStatus(task, to: .completed)
        dismiss()
    }
}

// MARK: - Reflection Step Model

struct ReflectionStep {
    let number: Int
    let title: String
    let question: String
    let placeholder: String
    let icon: String
}

// MARK: - Reflection Completion View

struct ReflectionCompletionView: View {
    let task: ActionTask
    var isEditMode: Bool = false
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 完了イメージ
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }

            // メッセージ
            VStack(spacing: 8) {
                Text(isEditMode ? "更新完了" : "ふりかえり完了")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isEditMode
                     ? "気づきを更新したね。\n振り返りを深めることで成長が加速するよ"
                     : "よくここまで来たね。\nこの気づきが、次の一歩への養分になるよ")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // 閉じるボタン
            Button(action: onDismiss) {
                Text("完了")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    TaskReflectionView(task: ActionTask(title: "朝5分の自分時間をとる"))
        .environmentObject(TaskStore())
}
