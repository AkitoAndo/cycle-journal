import SwiftUI

struct DiaryEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var diaryStore: DiaryStore
    
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var showingTagManagement = false
    
    var entry: DiaryEntry?
    var isEditing: Bool { entry != nil }
    
    init(diaryStore: DiaryStore, entry: DiaryEntry? = nil) {
        self.diaryStore = diaryStore
        self.entry = entry
        if let entry = entry {
            _content = State(initialValue: entry.content)
            _tags = State(initialValue: entry.tags)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("内容")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                Section(header: Text("選択中のタグ")) {
                    if tags.isEmpty {
                        Text("タグが選択されていません")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                HStack {
                                    Text(tag)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                    
                                    Button(action: {
                                        tags.removeAll { $0 == tag }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("既存のタグから選択")) {
                    if diaryStore.allTags.isEmpty {
                        VStack {
                            Text("タグがありません")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            Button("タグ管理画面でタグを作成") {
                                showingTagManagement = true
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(diaryStore.allTags, id: \.self) { tag in
                                Button(action: {
                                    toggleTag(tag)
                                }) {
                                    Text(tag)
                                        .font(.caption)
                                        .foregroundColor(tags.contains(tag) ? .white : .blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(tags.contains(tag) ? Color.blue : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Button("タグ管理") {
                            showingTagManagement = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle(isEditing ? "日記を編集" : "新しい日記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveEntry()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .sheet(isPresented: $showingTagManagement) {
                TagManagementView(diaryStore: diaryStore)
            }
        }
    }
    
    func saveEntry() {
        if let existingEntry = entry {
            let updatedEntry = DiaryEntry(
                id: existingEntry.id,
                content: content,
                createdAt: existingEntry.createdAt,
                tags: tags,
                isEdited: true
            )
            diaryStore.updateEntry(updatedEntry)
        } else {
            let newEntry = DiaryEntry(content: content, tags: tags)
            diaryStore.addEntry(newEntry)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    func toggleTag(_ tag: String) {
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
    }
}

struct DiaryEditView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryEditView(diaryStore: DiaryStore())
    }
}