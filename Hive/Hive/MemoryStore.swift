import Foundation

/// Everything Hive remembers, persisted as one JSON file on the device. Audio is never stored.
@MainActor
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var facts: [Fact] = []
    @Published private(set) var recaps: [DailyRecap] = []

    private struct Snapshot: Codable {
        var conversations: [Conversation]
        var todos: [TodoItem]
        var facts: [Fact]
        var recaps: [DailyRecap]
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hive-memory.json")
    }()

    private init() { load() }

    // MARK: Conversations
    func add(_ c: Conversation) { conversations.insert(c, at: 0); save() }
    func update(_ c: Conversation) {
        guard let i = conversations.firstIndex(where: { $0.id == c.id }) else { return }
        conversations[i] = c; save()
    }
    func conversation(_ id: UUID) -> Conversation? { conversations.first { $0.id == id } }
    func deleteConversation(_ id: UUID) { conversations.removeAll { $0.id == id }; save() }

    // MARK: To-dos
    func addTodo(_ t: TodoItem) { todos.insert(t, at: 0); save() }
    func toggleTodo(_ id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].isDone.toggle(); save()
    }
    func deleteTodo(_ id: UUID) { todos.removeAll { $0.id == id }; save() }
    var openTodos: [TodoItem] { todos.filter { !$0.isDone } }

    // MARK: Facts
    func addFacts(_ new: [Fact]) {
        let existing = Set(facts.map { $0.text.lowercased() })
        facts.insert(contentsOf: new.filter { !existing.contains($0.text.lowercased()) }, at: 0)
        save()
    }
    func confirmFact(_ id: UUID) {
        guard let i = facts.firstIndex(where: { $0.id == id }) else { return }
        facts[i].isConfirmed = true; save()
    }
    func deleteFact(_ id: UUID) { facts.removeAll { $0.id == id }; save() }

    // MARK: Recaps
    func setRecap(_ r: DailyRecap) { recaps.removeAll { $0.id == r.id }; recaps.insert(r, at: 0); save() }
    func recap(for day: String) -> DailyRecap? { recaps.first { $0.id == day } }

    func eraseEverything() { conversations = []; todos = []; facts = []; recaps = []; save() }

    // MARK: Persistence
    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        conversations = s.conversations; todos = s.todos; facts = s.facts; recaps = s.recaps
        // Anything that was mid-processing when the app died gets retried.
        for i in conversations.indices where conversations[i].status == .processing {
            conversations[i].status = .pending
        }
    }

    private func save() {
        let s = Snapshot(conversations: conversations, todos: todos, facts: facts, recaps: recaps)
        guard let data = try? JSONEncoder().encode(s) else { return }
        // Readable after first unlock so Hive can keep saving while the phone is locked.
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        SharedState.openTodoCount = openTodos.count
    }
}
