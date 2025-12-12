import SwiftUI

struct TagManagementView: View {
    @ObservedObject var diaryStore: DiaryStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var newTagName: String = ""
    @State private var editingTag: String? = nil
    @State private var editingTagName: String = ""
    @State private var showingDeleteAlert = false
    @State private var tagToDelete: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // 新しいタグ作成セクション
                VStack(alignment: .leading, spacing: 8) {
                    Text("新しいタグを作成")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("タグ名を入力", text: $newTagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("作成") {
                            createTag()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                
                // 既存タグ一覧
                List {
                    Section(header: Text("既存のタグ")) {
                        ForEach(diaryStore.allTags, id: \.self) { tag in
                            HStack {
                                if editingTag == tag {
                                    TextField("タグ名", text: $editingTagName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button("保存") {
                                        saveEditedTag(originalTag: tag)
                                    }
                                    .disabled(editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                             (editingTagName.trimmingCharacters(in: .whitespacesAndNewlines) != tag && 
                                              diaryStore.allTags.contains(editingTagName.trimmingCharacters(in: .whitespacesAndNewlines))))
                                    
                                    Button("キャンセル") {
                                        cancelEdit()
                                    }
                                } else {
                                    Text(tag)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("\(tagUsageCount(tag))件")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        startEditing(tag: tag)
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Button(action: {
                                        tagToDelete = tag
                                        showingDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("タグを削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    if let tag = tagToDelete {
                        deleteTag(tag)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                if let tag = tagToDelete {
                    Text("「\(tag)」を削除しますか？このタグが付いている日記からもタグが削除されます。")
                }
            }
        }
    }
    
    func createTag() {
        let trimmedTag = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !diaryStore.allTags.contains(trimmedTag) {
            diaryStore.createTag(trimmedTag)
            newTagName = ""
        }
    }
    
    func startEditing(tag: String) {
        editingTag = tag
        editingTagName = tag
        showingDeleteAlert = false
        tagToDelete = nil
    }
    
    func cancelEdit() {
        editingTag = nil
        editingTagName = ""
        showingDeleteAlert = false
        tagToDelete = nil
    }
    
    func saveEditedTag(originalTag: String) {
        let trimmedTag = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && trimmedTag != originalTag && !diaryStore.allTags.contains(trimmedTag) {
            diaryStore.renameTag(from: originalTag, to: trimmedTag)
        }
        cancelEdit()
    }
    
    func deleteTag(_ tag: String) {
        diaryStore.deleteTag(tag)
        tagToDelete = nil
    }
    
    func tagUsageCount(_ tag: String) -> Int {
        diaryStore.entries.filter { $0.tags.contains(tag) }.count
    }
}

struct TagManagementView_Previews: PreviewProvider {
    static var previews: some View {
        TagManagementView(diaryStore: DiaryStore())
    }
}