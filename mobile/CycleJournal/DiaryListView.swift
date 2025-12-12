import SwiftUI

struct DiaryListView: View {
    @EnvironmentObject var diaryStore: DiaryStore
    @State private var showingTagManagement = false
    @State private var showingSearch = false
    @State private var showingCalendar = false
    @State private var showingComposer = false
    @State private var editingEntry: DiaryEntry? = nil

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // 週表示カレンダー
                    WeeklyCalendarView(diaryStore: diaryStore)

                    // 検索バーまたはフィルター表示
                    if !diaryStore.searchText.isEmpty || !diaryStore.selectedTags.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if !diaryStore.searchText.isEmpty {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\"\(diaryStore.searchText)\"")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if !diaryStore.selectedTags.isEmpty {
                                    HStack {
                                        Image(systemName: "tag")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(diaryStore.selectedTags.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }

                            Spacer()

                            Button(action: {
                                diaryStore.clearAllFilters()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingSearch = true
                        }
                    }

                    // メッセージリスト
                    ScrollViewReader { proxy in
                        List {
                            ForEach(diaryStore.filteredEntries.reversed()) { entry in
                                DiaryRowView(entry: entry, diaryStore: diaryStore)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets())
                                    .id(entry.id)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            editingEntry = entry
                                            showingComposer = true
                                        } label: {
                                            Label("編集", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            diaryStore.deleteEntry(entry)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .onAppear {
                            DispatchQueue.main.async {
                                if let lastEntry = diaryStore.filteredEntries.first {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: diaryStore.filteredEntries.count) { oldValue, newValue in
                            DispatchQueue.main.async {
                                if let lastEntry = diaryStore.filteredEntries.first {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }

                // 右下フローティング+ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            editingEntry = nil
                            showingComposer = true
                        }) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let selectedDate = diaryStore.selectedDate {
                        Text(selectedDate, style: .date)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingCalendar = true
                        }) {
                            Image(systemName: "calendar")
                        }

                        Button(action: {
                            showingTagManagement = true
                        }) {
                            Image(systemName: "tag")
                        }

                        Button(action: {
                            showingSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTagManagement) {
                TagManagementView(diaryStore: diaryStore)
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(diaryStore: diaryStore)
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarView(diaryStore: diaryStore)
            }
            .sheet(isPresented: $showingComposer) {
                JournalComposerView(
                    diaryStore: diaryStore,
                    editingEntry: editingEntry
                )
            }
        }
    }
}

struct DiaryRowView: View {
    let entry: DiaryEntry
    @ObservedObject var diaryStore: DiaryStore

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        // センター寄せレイアウト
        VStack(alignment: .leading, spacing: 4) {
            // メッセージカード
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true)

                // 左下に時刻とタグを表示
                HStack(spacing: 8) {
                    // 時刻表示
                    Text(timeFormatter.string(from: entry.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 編集済み表示
                    if entry.isEdited {
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // タグ表示
                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            if entry.tags.count > 3 {
                                Text("+\(entry.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Journal Composer View (入力ポップアップ)
struct JournalComposerView: View {
    @ObservedObject var diaryStore: DiaryStore
    let editingEntry: DiaryEntry?
    @Environment(\.dismiss) var dismiss

    @State private var messageText: String = ""
    @State private var selectedTags: [String] = []
    @State private var showingTagSelection = false
    @FocusState private var isTextFieldFocused: Bool

    private var isEditing: Bool { editingEntry != nil }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 入力エリア
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $messageText)
                        .font(.body)
                        .focused($isTextFieldFocused)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    // タグ選択ボタン
                    Button(action: {
                        showingTagSelection = true
                    }) {
                        HStack {
                            Image(systemName: "tag")
                            Text("タグを追加")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // 選択中のタグ表示
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Button(action: {
                                            selectedTags.removeAll { $0 == tag }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white.opacity(0.8))
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle(isEditing ? "編集" : "新規ジャーナル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "投稿") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingTagSelection) {
                TagSelectionSheetView(selectedTags: $selectedTags, diaryStore: diaryStore)
            }
            .onAppear {
                if let entry = editingEntry {
                    messageText = entry.content
                    selectedTags = entry.tags
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func saveEntry() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if let entry = editingEntry {
            // 編集モード
            let updatedEntry = DiaryEntry(
                id: entry.id,
                content: trimmedText,
                createdAt: entry.createdAt,
                tags: selectedTags,
                isEdited: true
            )
            diaryStore.updateEntry(updatedEntry)
        } else {
            // 新規作成モード
            let newEntry = DiaryEntry(content: trimmedText, tags: selectedTags)
            diaryStore.addEntry(newEntry)
        }

        dismiss()
    }
}

struct SearchView: View {
    @ObservedObject var diaryStore: DiaryStore
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String = ""
    @State private var showResults = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索入力部分をコンパクトに
                VStack(spacing: 12) {
                    HStack {
                        TextField("キーワードを入力", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("検索") {
                            diaryStore.searchText = searchText
                            showResults = true
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // タグ選択をコンパクトに
                    if !diaryStore.allTags.isEmpty && !showResults {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(diaryStore.allTags, id: \.self) { tag in
                                    Button(action: {
                                        diaryStore.toggleTag(tag)
                                        showResults = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.system(size: 14, weight: .medium))
                                            if diaryStore.selectedTags.contains(tag) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 12))
                                            }
                                        }
                                        .foregroundColor(diaryStore.selectedTags.contains(tag) ? .white : .blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(diaryStore.selectedTags.contains(tag) ? Color.blue : Color.blue.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.blue, lineWidth: diaryStore.selectedTags.contains(tag) ? 0 : 2)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 40)
                    }
                }
                
                // 検索結果表示
                if showResults && (!diaryStore.searchText.isEmpty || !diaryStore.selectedTags.isEmpty) {
                    // 検索条件の表示
                    VStack(spacing: 4) {
                        HStack {
                            Text("\(diaryStore.filteredEntries.count)件の結果")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            if !diaryStore.selectedTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(Array(diaryStore.selectedTags), id: \.self) { tag in
                                            Text(tag)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue)
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                    
                    if diaryStore.filteredEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("検索結果がありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("別のキーワードやタグで検索してみてください")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        List {
                            ForEach(diaryStore.filteredEntries) { entry in
                                Button(action: {
                                    // 日付を選択してメイン画面に戻る
                                    diaryStore.setSelectedDate(entry.createdAt)
                                    diaryStore.clearAllFilters()
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // 日付と時刻
                                        HStack {
                                            Label {
                                                Text(dateFormatter.string(from: entry.createdAt))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                            } icon: {
                                                Image(systemName: "calendar")
                                                    .foregroundColor(.blue)
                                                    .font(.caption)
                                            }
                                            
                                            Text(timeFormatter.string(from: entry.createdAt))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            if entry.isEdited {
                                                Text("編集済み")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // 内容
                                        Text(entry.content)
                                            .font(.body)
                                            .lineLimit(2)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        // タグ
                                        if !entry.tags.isEmpty {
                                            HStack(spacing: 4) {
                                                ForEach(entry.tags, id: \.self) { tag in
                                                    Text(tag)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(Color.blue)
                                                        .cornerRadius(10)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .listStyle(PlainListStyle())
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                } else if !showResults {
                    Spacer()
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showResults && (!diaryStore.searchText.isEmpty || !diaryStore.selectedTags.isEmpty) {
                        Button("クリア") {
                            diaryStore.clearAllFilters()
                            searchText = ""
                            showResults = false
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showResults ? "完了" : "キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            searchText = diaryStore.searchText
            if !diaryStore.searchText.isEmpty || !diaryStore.selectedTags.isEmpty {
                showResults = true
            }
        }
    }
}

struct TagSelectionSheetView: View {
    @Binding var selectedTags: [String]
    @ObservedObject var diaryStore: DiaryStore
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if diaryStore.allTags.isEmpty {
                    Text("タグがありません")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(diaryStore.allTags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            if selectedTags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTags.contains(tag) {
                                selectedTags.removeAll { $0 == tag }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                    }
                }
            }
            .navigationTitle("タグを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DiaryListView()
        .environmentObject(DiaryStore())
}
