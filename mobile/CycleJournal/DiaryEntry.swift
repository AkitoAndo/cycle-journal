import Foundation

struct DiaryEntry: Identifiable, Codable {
    let id: UUID
    var content: String
    var createdAt: Date
    var tags: [String]
    var isEdited: Bool
    
    init(content: String, createdAt: Date = Date(), tags: [String] = [], isEdited: Bool = false) {
        self.id = UUID()
        self.content = content
        self.createdAt = createdAt
        self.tags = tags
        self.isEdited = isEdited
    }
    
    init(id: UUID, content: String, createdAt: Date, tags: [String], isEdited: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.tags = tags
        self.isEdited = isEdited
    }
}