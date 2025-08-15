import SwiftUI

struct DiaryListView: View {
    @StateObject private var diaryStore = DiaryStore()
    @State private var showingTagManagement = false
    @State private var showingSearch = false
    @State private var showingCalendar = false
    @State private var messageText = ""
    @State private var selectedTags: [String] = []
    @State private var showingTagSelection = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var currentEditingEntryId: UUID? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 週表示カレンダー
                WeeklyCalendarView(diaryStore: diaryStore)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // カレンダー領域をタップした時にフォーカスを外す
                        dismissKeyboard()
                    }
                
                // 検索バーまたはフィルター表示
                if !diaryStore.searchText.isEmpty || !diaryStore.selectedTags.isEmpty {
                    VStack(spacing: 8) {
                        if !diaryStore.searchText.isEmpty {
                            HStack {
                                Text("検索: \(diaryStore.searchText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    diaryStore.searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        if !diaryStore.selectedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(diaryStore.selectedTags), id: \.self) { tag in
                                        HStack {
                                            Text(tag)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                            Button(action: {
                                                diaryStore.toggleTag(tag)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.caption)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // フィルター領域をタップした時にフォーカスを外す
                        dismissKeyboard()
                    }
                }
                
                // メッセージリスト
                ScrollViewReader { proxy in
                    List {
                        ForEach(diaryStore.filteredEntries.reversed()) { entry in
                            DiaryRowView(
                                entry: entry, 
                                diaryStore: diaryStore,
                                currentEditingEntryId: $currentEditingEntryId,
                                editingMessageText: $messageText,
                                isMainTextFieldFocused: $isTextFieldFocused
                            )
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                                .id(entry.id)
                        }
                        .onDelete(perform: deleteEntries)
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
                
                // チャット入力フィールド
                VStack(spacing: 0) {
                    Divider()
                    
                    // 編集中の表示
                    if currentEditingEntryId != nil {
                        HStack {
                            Text("メッセージを編集中")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("キャンセル") {
                                cancelEditing()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    HStack(spacing: 8) {
                        // タグボタン
                        Button(action: {
                            showingTagSelection = true
                        }) {
                            Image(systemName: "tag")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        
                        // メッセージ入力フィールド
                        HStack {
                            TextField(currentEditingEntryId != nil ? "メッセージを編集..." : "メッセージを入力...", text: $messageText, axis: .vertical)
                                .focused($isTextFieldFocused)
                                .lineLimit(1...5)
                                .onSubmit {
                                    if currentEditingEntryId != nil {
                                        saveEditedMessage()
                                    } else {
                                        sendMessage()
                                    }
                                }
                            
                            if !messageText.isEmpty {
                                Button(action: {
                                    if currentEditingEntryId != nil {
                                        saveEditedMessage()
                                    } else {
                                        sendMessage()
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onChange(of: isTextFieldFocused) { oldValue, newValue in
                        if !newValue && currentEditingEntryId != nil {
                            // 編集中にフォーカスが外れた場合はキャンセル
                            cancelEditing()
                        }
                    }
                    
                    // 選択中のタグ表示
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(selectedTags, id: \.self) { tag in
                                    HStack {
                                        Text(tag)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Button(action: {
                                            selectedTags.removeAll { $0 == tag }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                    }
                }
                .background(Color(.systemBackground))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // 背景をタップした時にフォーカスを外す
                dismissKeyboard()
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
            .sheet(isPresented: $showingTagSelection) {
                TagSelectionSheetView(selectedTags: $selectedTags, diaryStore: diaryStore)
            }
        }
    }
    
    func deleteEntries(offsets: IndexSet) {
        let reversedEntries = diaryStore.filteredEntries.reversed()
        for index in offsets {
            let entryIndex = Array(reversedEntries).indices.contains(index) ? index : 0
            let entry = Array(reversedEntries)[entryIndex]
            diaryStore.deleteEntry(entry)
        }
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newEntry = DiaryEntry(content: messageText, tags: selectedTags)
        diaryStore.addEntry(newEntry)
        
        messageText = ""
        selectedTags = []
        isTextFieldFocused = false
    }
    
    func saveEditedMessage() {
        guard let editingId = currentEditingEntryId,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            cancelEditing()
            return 
        }
        
        if let entryIndex = diaryStore.entries.firstIndex(where: { $0.id == editingId }) {
            let originalEntry = diaryStore.entries[entryIndex]
            let updatedEntry = DiaryEntry(
                id: originalEntry.id,
                content: messageText,
                createdAt: originalEntry.createdAt,
                tags: originalEntry.tags,
                isEdited: true
            )
            diaryStore.updateEntry(updatedEntry)
        }
        
        cancelEditing()
    }
    
    func cancelEditing() {
        currentEditingEntryId = nil
        messageText = ""
        isTextFieldFocused = false
    }
    
    func dismissKeyboard() {
        if isTextFieldFocused {
            if currentEditingEntryId != nil {
                // 編集中の場合はキャンセル
                cancelEditing()
            } else {
                // 通常入力中の場合はフォーカスを外すだけ
                isTextFieldFocused = false
            }
        }
    }
    
}

struct DiaryRowView: View {
    let entry: DiaryEntry
    @ObservedObject var diaryStore: DiaryStore
    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Binding var currentEditingEntryId: UUID?
    @Binding var editingMessageText: String
    @FocusState.Binding var isMainTextFieldFocused: Bool
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        // 通常表示モード（編集時もこのままで表示）
        HStack(alignment: .bottom, spacing: 0) {
            Spacer()
            
            // メッセージバブルと時間を密着させたコンテナ
            HStack(alignment: .bottom, spacing: 2) {
                // 時間表示と編集済み表示
                VStack(alignment: .trailing, spacing: 1) {
                    // 編集済み表示
                    if entry.isEdited {
                        Text("編集済み")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 時間表示
                    Text(timeFormatter.string(from: entry.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // メッセージバブル
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // タグ表示（バブル内）
                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            if entry.tags.count > 3 {
                                Text("+\(entry.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(currentEditingEntryId == entry.id ? Color.orange : Color.blue)
                .cornerRadius(18)
                .layoutPriority(1)
                .onTapGesture {
                    startEditing()
                }
                .contentShape(Rectangle())
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(Color.clear)
        .onTapGesture {
            // メッセージ行の空白部分をタップした時にキーボードを閉じる
            if currentEditingEntryId != nil {
                currentEditingEntryId = nil
                editingMessageText = ""
                isMainTextFieldFocused = false
            } else if isMainTextFieldFocused {
                isMainTextFieldFocused = false
            }
        }
    }
    
    private func startEditing() {
        currentEditingEntryId = entry.id
        editingMessageText = entry.content
        isMainTextFieldFocused = true
    }
}

struct SearchView: View {
    @ObservedObject var diaryStore: DiaryStore
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("キーワードを入力", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("検索") {
                        diaryStore.searchText = searchText
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding()
                
                // タグでの検索も可能
                if !diaryStore.allTags.isEmpty {
                    List {
                        Section(header: Text("タグから検索")) {
                            ForEach(diaryStore.allTags, id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                    Spacer()
                                    if diaryStore.selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    diaryStore.toggleTag(tag)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            searchText = diaryStore.searchText
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

struct DiaryListView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryListView()
    }
}
