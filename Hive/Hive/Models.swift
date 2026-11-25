import Foundation

struct Utterance: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var text: String
}

enum ProcessingStatus: String, Codable {
    case pending, processing, done, failed, skipped
}

struct Conversation: Identifiable, Codable, Hashable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var transcript: [Utterance]
    var title: String?
    var summary: String?
    var keyPoints: [String] = []
    var status: ProcessingStatus = .pending
    var errorMessage: String?

    var transcriptText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return transcript.map { "[\(f.string(from: $0.date))] \($0.text)" }.joined(separator: "\n")
    }
    var wordCount: Int { transcript.reduce(0) { $0 + $1.text.split(separator: " ").count } }
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var due: String?
    var isDone = false
    var createdAt = Date()
    var sourceConversationID: UUID?
}

enum FactCategory: String, Codable, CaseIterable {
    case personal, people, work, preferences, health, plans, other
    var symbol: String {
        switch self {
        case .personal: "person"
        case .people: "person.2"
        case .work: "briefcase"
        case .preferences: "heart"
        case .health: "cross.case"
        case .plans: "calendar"
        case .other: "sparkles"
        }
    }
}

/// Something Hive learned about you. New facts start unconfirmed until you accept them.
struct Fact: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var category: FactCategory
    var isConfirmed = false
    var createdAt = Date()
    var sourceConversationID: UUID?
}

struct DailyRecap: Identifiable, Codable, Hashable {
    var id: String           // yyyy-MM-dd
    var text: String
    var generatedAt = Date()
}

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
}

extension Date {
    var dayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}
