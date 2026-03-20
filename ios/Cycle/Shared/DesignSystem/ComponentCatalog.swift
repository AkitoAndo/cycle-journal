//
//  ComponentCatalog.swift
//  Cycle
//
//  Storybook的なUIコンポーネントカタログ
//  Atomic Design: Tokens → Atoms → Molecules → Organisms
//

import SwiftUI

// MARK: - Catalog Models

/// コンポーネントの引数（Props）定義
struct CatalogProp: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let required: Bool
    let defaultValue: String?
    let description: String

    init(_ name: String, _ type: String, required: Bool = true, default defaultValue: String? = nil, _ description: String = "") {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
    }
}

/// カタログに表示するコンポーネントの定義
struct CatalogItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: CatalogCategory
    let props: [CatalogProp]
    let preview: AnyView
}

enum CatalogCategory: String, CaseIterable {
    case tokens = "Tokens"
    case atoms = "Atoms"
    case molecules = "Molecules"
    case organisms = "Organisms"
    case layouts = "Layouts"

    var icon: String {
        switch self {
        case .tokens: return "paintpalette"
        case .atoms: return "atom"
        case .molecules: return "circle.hexagongrid"
        case .organisms: return "square.stack.3d.up"
        case .layouts: return "rectangle.3.group"
        }
    }
}

// MARK: - Catalog Registry

enum CatalogRegistry {
    static var items: [CatalogItem] {
        tokens + atoms + molecules + organisms + layouts
    }

    // MARK: - Tokens

    static var tokens: [CatalogItem] {
        [
            CatalogItem(
                name: "Colors",
                description: "アプリ全体のカラーパレット",
                category: .tokens,
                props: [],
                preview: AnyView(ColorTokensPreview())
            ),
            CatalogItem(
                name: "Spacing",
                description: "余白・間隔の定数",
                category: .tokens,
                props: [],
                preview: AnyView(SpacingTokensPreview())
            ),
            CatalogItem(
                name: "Typography",
                description: "フォントサイズの一覧",
                category: .tokens,
                props: [],
                preview: AnyView(TypographyTokensPreview())
            ),
        ]
    }

    // MARK: - Atoms

    static var atoms: [CatalogItem] {
        [
            CatalogItem(
                name: "TagChip",
                description: "タグ表示用の小さなチップ",
                category: .atoms,
                props: [
                    CatalogProp("text", "String", "表示するテキスト"),
                    CatalogProp("isInteractive", "Bool", required: false, default: "false", "タップ可能にするか"),
                    CatalogProp("onTap", "(() -> Void)?", required: false, default: "nil", "タップ時のコールバック"),
                ],
                preview: AnyView(TagChipPreview())
            ),
            CatalogItem(
                name: "FloatingActionButton",
                description: "フローティングアクションボタン（触覚フィードバック付き）",
                category: .atoms,
                props: [
                    CatalogProp("icon", "String", "SF Symbolsのアイコン名"),
                    CatalogProp("action", "() -> Void", "タップ時のアクション"),
                ],
                preview: AnyView(FABPreview())
            ),
            CatalogItem(
                name: "EmptyStateView",
                description: "コンテンツが空の時の表示",
                category: .atoms,
                props: [
                    CatalogProp("icon", "String", "SF Symbolsのアイコン名"),
                    CatalogProp("title", "String", "メインメッセージ"),
                    CatalogProp("subtitle", "String?", required: false, default: "nil", "補足メッセージ"),
                ],
                preview: AnyView(EmptyStatePreview())
            ),
            CatalogItem(
                name: "SurfaceCard",
                description: "カード型コンテナ（surface背景 + 角丸 + ボーダー + シャドウ）",
                category: .atoms,
                props: [
                    CatalogProp("content", "ViewBuilder", "カード内のコンテンツ"),
                ],
                preview: AnyView(SurfaceCardPreview())
            ),
            CatalogItem(
                name: "PrimaryButton",
                description: "全幅のプライマリボタン",
                category: .atoms,
                props: [
                    CatalogProp("title", "String", "ボタンテキスト"),
                    CatalogProp("icon", "String?", required: false, default: "nil", "SF Symbolsアイコン"),
                    CatalogProp("color", "Color", required: false, default: "accent", "背景色"),
                    CatalogProp("action", "() -> Void", "タップ時のアクション"),
                ],
                preview: AnyView(PrimaryButtonPreview())
            ),
            CatalogItem(
                name: "SecondaryButton",
                description: "全幅のセカンダリボタン（枠線スタイル）",
                category: .atoms,
                props: [
                    CatalogProp("title", "String", "ボタンテキスト"),
                    CatalogProp("icon", "String?", required: false, default: "nil", "SF Symbolsアイコン"),
                    CatalogProp("color", "Color", required: false, default: "accent", "枠線・テキスト色"),
                    CatalogProp("action", "() -> Void", "タップ時のアクション"),
                ],
                preview: AnyView(SecondaryButtonPreview())
            ),
            CatalogItem(
                name: "FormTextField",
                description: "ラベル付き1行テキストフィールド",
                category: .atoms,
                props: [
                    CatalogProp("label", "String", "ラベルテキスト"),
                    CatalogProp("text", "Binding<String>", "入力値のバインディング"),
                    CatalogProp("placeholder", "String", required: false, default: "\"\"", "プレースホルダー"),
                ],
                preview: AnyView(FormTextFieldPreview())
            ),
            CatalogItem(
                name: "FormTextEditor",
                description: "ラベル付き複数行テキストエディタ",
                category: .atoms,
                props: [
                    CatalogProp("label", "String", "ラベルテキスト"),
                    CatalogProp("text", "Binding<String>", "入力値のバインディング"),
                    CatalogProp("placeholder", "String", required: false, default: "\"\"", "プレースホルダー"),
                    CatalogProp("minHeight", "CGFloat", required: false, default: "120", "最小高さ"),
                ],
                preview: AnyView(FormTextEditorPreview())
            ),
            CatalogItem(
                name: "SectionLabel",
                description: "セクション見出しラベル",
                category: .atoms,
                props: [
                    CatalogProp("title", "String", "見出しテキスト"),
                    CatalogProp("icon", "String?", required: false, default: "nil", "SF Symbolsアイコン"),
                ],
                preview: AnyView(SectionLabelPreview())
            ),
            CatalogItem(
                name: "IconCircle",
                description: "円形アイコン（グラデーション背景付き）",
                category: .atoms,
                props: [
                    CatalogProp("icon", "String", "SF Symbolsアイコン"),
                    CatalogProp("size", "CGFloat", required: false, default: "80", "円のサイズ"),
                    CatalogProp("iconScale", "CGFloat", required: false, default: "0.42", "アイコンサイズの倍率"),
                    CatalogProp("color", "Color", required: false, default: "accent", "テーマ色"),
                ],
                preview: AnyView(IconCirclePreview())
            ),
        ]
    }

    // MARK: - Molecules

    static var molecules: [CatalogItem] {
        [
            CatalogItem(
                name: "TaskRow",
                description: "タスク行（チェックボックス + タイトル + スワイプアクション）",
                category: .molecules,
                props: [
                    CatalogProp("task", "TaskItem", "タスクデータ"),
                    CatalogProp("isReorderMode", "Bool", "並び替えモードか"),
                    CatalogProp("onToggleCompletion", "() -> Void", "完了切り替え"),
                    CatalogProp("onEdit", "() -> Void", "編集"),
                    CatalogProp("onDelete", "() -> Void", "削除"),
                    CatalogProp("onPreview", "() -> Void", "プレビュー"),
                    CatalogProp("onArchive", "(() -> Void)?", required: false, default: "nil", "アーカイブ（完了時のみ）"),
                ],
                preview: AnyView(TaskRowPreview())
            ),
            CatalogItem(
                name: "TaskHeader",
                description: "タスク画面のヘッダー（タイトル + メニュー）",
                category: .molecules,
                props: [
                    CatalogProp("isReorderMode", "Bool", "並び替えモード表示"),
                    CatalogProp("onToggleReorderMode", "() -> Void", "並び替え切り替え"),
                    CatalogProp("onShowArchive", "() -> Void", "アーカイブ表示"),
                    CatalogProp("onShowDeleted", "() -> Void", "削除済み表示"),
                ],
                preview: AnyView(TaskHeaderPreview())
            ),
            CatalogItem(
                name: "TaskFieldTabs",
                description: "タスクフォームのフィールド切り替えタブ",
                category: .molecules,
                props: [
                    CatalogProp("selectedTab", "Binding<FieldTab>", "選択中のタブ"),
                ],
                preview: AnyView(TaskFieldTabsPreview())
            ),
            CatalogItem(
                name: "SessionRowView",
                description: "コーチセッション行（日付 + サマリー + 感情ラベル）",
                category: .molecules,
                props: [
                    CatalogProp("session", "CoachSession", "セッションデータ"),
                ],
                preview: AnyView(SessionRowPreview())
            ),
            CatalogItem(
                name: "JournalHeader",
                description: "日記画面のヘッダー（月表示 + メニュー）",
                category: .molecules,
                props: [
                    CatalogProp("currentMonth", "String", "表示中の月（例: 3月）"),
                    CatalogProp("currentYear", "String", "表示中の年（例: 2026）"),
                    CatalogProp("onShowSearch", "() -> Void", "検索表示"),
                    CatalogProp("onShowTrash", "() -> Void", "ゴミ箱表示"),
                    CatalogProp("onShowTagManager", "() -> Void", "タグ管理表示"),
                ],
                preview: AnyView(JournalHeaderPreview())
            ),
        ]
    }

    // MARK: - Organisms

    static var organisms: [CatalogItem] {
        [
            CatalogItem(
                name: "TaskList",
                description: "タスク一覧（未完了 + 完了セクション、並び替え対応）",
                category: .organisms,
                props: [
                    CatalogProp("incompleteTasks", "[TaskItem]", "未完了タスク配列"),
                    CatalogProp("completedTasks", "[TaskItem]", "完了タスク配列"),
                    CatalogProp("isReorderMode", "Bool", "並び替えモード"),
                    CatalogProp("onMove", "(IndexSet, Int) -> Void", "並び替え"),
                    CatalogProp("onToggleCompletion", "(TaskItem) -> Void", "完了切り替え"),
                    CatalogProp("onEdit", "(TaskItem) -> Void", "編集"),
                    CatalogProp("onDelete", "(TaskItem) -> Void", "削除"),
                    CatalogProp("onPreview", "(TaskItem) -> Void", "プレビュー"),
                    CatalogProp("onArchive", "(TaskItem) -> Void", "アーカイブ"),
                ],
                preview: AnyView(TaskListPreview())
            ),
            CatalogItem(
                name: "SessionHistoryView",
                description: "コーチ会話履歴一覧（削除対応）",
                category: .organisms,
                props: [
                    CatalogProp("coachStore", "@EnvironmentObject CoachStore", "コーチストア"),
                ],
                preview: AnyView(
                    Text("SessionHistoryView は CoachStore に依存するため\nカタログでは表示できません")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                )
            ),
        ]
    }

    // MARK: - Layouts

    static var layouts: [CatalogItem] {
        [
            CatalogItem(
                name: "FlowLayout",
                description: "折り返しレイアウト（タグ一覧用）",
                category: .layouts,
                props: [
                    CatalogProp("spacing", "CGFloat", required: false, default: "8", "アイテム間の余白"),
                ],
                preview: AnyView(FlowLayoutPreview())
            ),
            CatalogItem(
                name: ".customListRowStyle()",
                description: "リスト行の共通スタイル（パディング + セパレータ非表示）",
                category: .layouts,
                props: [],
                preview: AnyView(
                    Text("ViewModifier — .customListRowStyle() で適用\nlistRowInsets + listRowSeparator(.hidden) + listRowBackground(.clear)")
                        .font(.caption).foregroundStyle(.secondary)
                )
            ),
        ]
    }
}

// MARK: - Token Previews

private struct ColorTokensPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            colorSection("Background", [
                ("background", DesignSystem.Colors.background),
                ("secondaryBackground", DesignSystem.Colors.secondaryBackground),
                ("surface", DesignSystem.Colors.surface),
            ])
            colorSection("Text", [
                ("textPrimary", DesignSystem.Colors.textPrimary),
                ("textSecondary", DesignSystem.Colors.textSecondary),
                ("textTertiary", DesignSystem.Colors.textTertiary),
            ])
            colorSection("Accent", [
                ("brown", DesignSystem.Colors.brown),
                ("brownLight", DesignSystem.Colors.brownLight),
                ("brownDark", DesignSystem.Colors.brownDark),
            ])
            colorSection("Grey", [
                ("grey", DesignSystem.Colors.grey),
                ("greyLight", DesignSystem.Colors.greyLight),
                ("greyDark", DesignSystem.Colors.greyDark),
            ])
        }
    }

    private func colorSection(_ title: String, _ colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(colors, id: \.0) { name, color in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 40, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                    Text(name)
                        .font(.system(size: 13, design: .monospaced))
                }
            }
        }
    }
}

private struct SpacingTokensPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            spacingRow("xs", DesignSystem.Spacing.xs)
            spacingRow("sm", DesignSystem.Spacing.sm)
            spacingRow("md", DesignSystem.Spacing.md)
            spacingRow("lg", DesignSystem.Spacing.lg)
            spacingRow("xl", DesignSystem.Spacing.xl)
            spacingRow("xxl", DesignSystem.Spacing.xxl)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 40, alignment: .leading)
            RoundedRectangle(cornerRadius: 3)
                .fill(DesignSystem.Colors.accent)
                .frame(width: value * 4, height: 16)
            Text("\(Int(value))pt")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TypographyTokensPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            fontRow("largeTitle", "34pt bold", DesignSystem.Fonts.largeTitle)
            fontRow("screenTitle", "28pt bold", DesignSystem.Fonts.screenTitle)
            fontRow("title2", "24pt semi", DesignSystem.Fonts.title2)
            fontRow("sectionTitle", "20pt semi", DesignSystem.Fonts.sectionTitle)
            fontRow("headline", "17pt semi", DesignSystem.Fonts.headline)
            fontRow("button", "17pt semi", DesignSystem.Fonts.button)
            fontRow("body", "16pt", DesignSystem.Fonts.body)
            fontRow("bodyMedium", "16pt med", DesignSystem.Fonts.bodyMedium)
            fontRow("subheadline", "15pt", DesignSystem.Fonts.subheadline)
            fontRow("label", "14pt med", DesignSystem.Fonts.label)
            fontRow("caption", "12pt", DesignSystem.Fonts.caption)
            fontRow("caption2", "10pt", DesignSystem.Fonts.caption2)
        }
    }

    private func fontRow(_ name: String, _ spec: String, _ font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(spec)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .trailing)
            Text(name)
                .font(font)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Atom Previews

private struct TagChipPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            previewSection("Default") {
                HStack(spacing: 8) {
                    TagChip(text: "仕事")
                    TagChip(text: "振り返り")
                    TagChip(text: "気づき")
                }
            }
            previewSection("Interactive") {
                TagChip(text: "タップできる", isInteractive: true, onTap: {})
            }
        }
    }
}

private struct FABPreview: View {
    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 6) {
                FloatingActionButton(icon: "plus") {}
                Text("plus").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                FloatingActionButton(icon: "pencil") {}
                Text("pencil").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyStatePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            previewSection("With subtitle") {
                EmptyStateView(
                    icon: "tray",
                    title: "タスクがありません",
                    subtitle: "＋ボタンから新しいタスクを追加しましょう"
                )
                .frame(height: 200)
            }
            previewSection("Without subtitle") {
                EmptyStateView(icon: "doc.text", title: "日記がありません")
                    .frame(height: 160)
            }
        }
    }
}

// MARK: - Molecule Previews

private struct TaskRowPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("Incomplete") {
                TaskRow(
                    task: TaskItem(title: "APIドキュメントを更新する"),
                    isReorderMode: false,
                    onToggleCompletion: {},
                    onEdit: {},
                    onDelete: {},
                    onPreview: {},
                    onArchive: nil
                )
            }
            previewSection("Completed") {
                let completedTask = {
                    var t = TaskItem(title: "テストを書く")
                    t.isCompleted = true
                    t.completedAt = Date()
                    return t
                }()
                TaskRow(
                    task: completedTask,
                    isReorderMode: false,
                    onToggleCompletion: {},
                    onEdit: {},
                    onDelete: {},
                    onPreview: {},
                    onArchive: {}
                )
            }
        }
    }
}

private struct TaskHeaderPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("Normal") {
                TaskHeader(
                    isReorderMode: false,
                    onToggleReorderMode: {},
                    onShowArchive: {},
                    onShowDeleted: {}
                )
            }
            previewSection("Reorder Mode") {
                TaskHeader(
                    isReorderMode: true,
                    onToggleReorderMode: {},
                    onShowArchive: {},
                    onShowDeleted: {}
                )
            }
        }
    }
}

private struct TaskFieldTabsPreview: View {
    @State private var selectedTab = 0
    var body: some View {
        previewSection("Field Tabs") {
            HStack(spacing: 0) {
                ForEach(["基本", "詳細", "振り返り"], id: \.self) { label in
                    let index = ["基本", "詳細", "振り返り"].firstIndex(of: label) ?? 0
                    Button {
                        selectedTab = index
                    } label: {
                        Text(label)
                            .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SessionRowPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("With Summary & Emotion") {
                SessionRowView(session: CoachSession(
                    summary: "仕事のストレスについて話した",
                    emotionLabel: "不安",
                    isActive: false
                ))
            }
            previewSection("Without Emotion") {
                SessionRowView(session: CoachSession(
                    summary: "今日の振り返り",
                    isActive: false
                ))
            }
        }
    }
}

private struct JournalHeaderPreview: View {
    var body: some View {
        previewSection("Journal Header") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("2026")
                        .font(.system(size: DesignSystem.FontSize.caption))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text("3月")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }
                Spacer()
                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                    Image(systemName: "ellipsis.circle")
                }
                .font(.system(size: 22))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Organism Previews

private struct TaskListPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            previewSection("Task List (3 items)") {
                VStack(spacing: 8) {
                    TaskRow(task: TaskItem(title: "企画書を書く"), isReorderMode: false, onToggleCompletion: {}, onEdit: {}, onDelete: {}, onPreview: {}, onArchive: nil)
                    TaskRow(task: TaskItem(title: "レビューを依頼する"), isReorderMode: false, onToggleCompletion: {}, onEdit: {}, onDelete: {}, onPreview: {}, onArchive: nil)
                    let done = { var t = TaskItem(title: "MTG準備"); t.isCompleted = true; t.completedAt = Date(); return t }()
                    TaskRow(task: done, isReorderMode: false, onToggleCompletion: {}, onEdit: {}, onDelete: {}, onPreview: {}, onArchive: {})
                }
            }
        }
    }
}

// MARK: - Layout Previews

private struct FlowLayoutPreview: View {
    let tags = ["SwiftUI", "iOS", "Cycle", "振り返り", "タスク管理", "コーチング", "日記", "Atomic Design"]

    var body: some View {
        previewSection("Tag Wrapping") {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(text: tag)
                }
            }
        }
    }
}

// MARK: - New Atom Previews

private struct SurfaceCardPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("Basic") {
                SurfaceCard {
                    Text("カード内のコンテンツ")
                        .font(DesignSystem.Fonts.body)
                }
            }
            previewSection("With multiple elements") {
                SurfaceCard {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DesignSystem.Colors.accent)
                        Text("タスクを完了する")
                            .font(DesignSystem.Fonts.body)
                        Spacer()
                    }
                }
            }
        }
    }
}

private struct PrimaryButtonPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("Default") {
                PrimaryButton("保存する") {}
            }
            previewSection("With icon") {
                PrimaryButton("話しかける", icon: "bubble.left") {}
            }
            previewSection("Custom color") {
                PrimaryButton("送信", color: .green) {}
            }
        }
    }
}

private struct SecondaryButtonPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            previewSection("Default") {
                SecondaryButton("キャンセル") {}
            }
            previewSection("With icon") {
                SecondaryButton("日記から話す", icon: "book", color: .green) {}
            }
        }
    }
}

private struct FormTextFieldPreview: View {
    @State private var text = ""
    var body: some View {
        FormTextField(label: "タイトル", text: $text, placeholder: "タスク名を入力")
    }
}

private struct FormTextEditorPreview: View {
    @State private var text = ""
    var body: some View {
        FormTextEditor(label: "詳細", text: $text, placeholder: "タスクの詳細を入力", minHeight: 80)
    }
}

private struct SectionLabelPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewSection("Text only") {
                SectionLabel("最近の会話")
            }
            previewSection("With icon") {
                SectionLabel("未完了", icon: "circle")
            }
        }
    }
}

private struct IconCirclePreview: View {
    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 6) {
                IconCircle(icon: "tree", size: 80, color: .green)
                Text("Coach").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                IconCircle(icon: "person.fill", size: 50, color: .blue)
                Text("Profile").font(.caption2).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                IconCircle(icon: "star.fill", size: 40)
                Text("Badge").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview Helper

private func previewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
        content()
    }
}
