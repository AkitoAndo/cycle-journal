import SwiftUI

struct DiaryDetailView: View {
    let entry: DiaryEntry
    @ObservedObject var diaryStore: DiaryStore
    @State private var showingEditView = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                if !entry.tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.bottom, 16)
                }
                
                Text(entry.content)
                    .font(.body)
                    .lineSpacing(4)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("編集") {
                    showingEditView = true
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            DiaryEditView(diaryStore: diaryStore, entry: entry)
        }
    }
}

struct DiaryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = DiaryEntry(
            content: "今日は素晴らしい一日でした。新しいことを学び、友人と楽しい時間を過ごしました。",
            createdAt: Date(),
            tags: ["日常", "楽しい", "学習"]
        )
        
        NavigationView {
            DiaryDetailView(entry: sampleEntry, diaryStore: DiaryStore())
        }
    }
}