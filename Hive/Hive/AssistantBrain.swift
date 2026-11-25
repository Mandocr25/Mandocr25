import Foundation

/// Turns raw transcripts into summaries, to-dos and memories using Claude.
@MainActor
final class AssistantBrain {
    static let shared = AssistantBrain()
    private var inFlight = Set<UUID>()

    private var ownerLine: String {
        Settings.userName.isEmpty ? "the owner of this iPhone" : "\(Settings.userName), the owner of this iPhone"
    }

    // MARK: Conversation analysis

    private static let analysisSchema: [String: Any] = {
        let categories = FactCategory.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ",")
        let json = """
        {
          "type": "object",
          "properties": {
            "is_meaningful": {"type": "boolean", "description": "false if this is just noise, TV/music/video audio, or too fragmentary to be useful"},
            "title": {"type": "string"},
            "summary": {"type": "string"},
            "key_points": {"type": "array", "items": {"type": "string"}},
            "action_items": {"type": "array", "items": {
              "type": "object",
              "properties": {
                "text": {"type": "string"},
                "due": {"type": "string", "description": "when it is due, in words, or empty string"}
              },
              "required": ["text", "due"],
              "additionalProperties": false
            }},
            "facts": {"type": "array", "items": {
              "type": "object",
              "properties": {
                "text": {"type": "string"},
                "category": {"type": "string", "enum": [\(categories)]}
              },
              "required": ["text", "category"],
              "additionalProperties": false
            }}
          },
          "required": ["is_meaningful", "title", "summary", "key_points", "action_items", "facts"],
          "additionalProperties": false
        }
        """
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }()

    private struct Analysis: Decodable {
        struct Action: Decodable { let text: String; let due: String }
        struct NewFact: Decodable { let text: String; let category: String }
        let is_meaningful: Bool
        let title: String
        let summary: String
        let key_points: [String]
        let action_items: [Action]
        let facts: [NewFact]
    }

    func process(_ id: UUID) async {
        let store = MemoryStore.shared
        guard !inFlight.contains(id), var convo = store.conversation(id) else { return }
        inFlight.insert(id); defer { inFlight.remove(id) }

        convo.status = .processing; convo.errorMessage = nil
        store.update(convo)

        do {
            let client = try ClaudeClient.fromSettings()
            let known = store.facts.prefix(150).map { "- \($0.text)" }.joined(separator: "\n")
            let system = """
            You are Hive, an ambient personal assistant that runs on \(ownerLine). The phone's microphone \
            captured the transcript below with on-device speech recognition. There are no speaker labels and \
            the recognition contains mistakes, so infer meaning from context. Assume first-person statements \
            ("I", "yo") are usually the owner.

            Produce:
            - title: a short, specific title (max 8 words).
            - summary: 2-4 sentences on what happened and what was decided.
            - key_points: the few points worth remembering.
            - action_items: concrete things the owner committed to, was asked to do, or clearly needs to do. \
            Do not invent tasks. Use an empty array if there are none.
            - facts: durable facts about the owner's life worth remembering for weeks (people they know and how, \
            preferences, routines, work, plans, important dates). Skip trivia, one-off chatter, and anything \
            already in the known facts. Do not record sensitive details about other people beyond what the owner \
            needs (a name and relationship is fine).
            - is_meaningful: false for background media, noise or meaningless fragments (then keep other fields brief).

            Write every field in the same language the conversation was mostly spoken in.

            Known facts about the owner:
            \(known.isEmpty ? "(none yet)" : known)
            """
            let user = """
            Conversation from \(convo.startedAt.formatted(date: .complete, time: .shortened)) \
            to \(convo.endedAt.formatted(date: .omitted, time: .shortened)):

            \(convo.transcriptText)
            """
            let text = try await client.send(system: [["type": "text", "text": system]],
                                             messages: [["role": "user", "content": user]],
                                             effort: "medium",
                                             schema: Self.analysisSchema)
            let a = try JSONDecoder().decode(Analysis.self, from: Data(text.utf8))

            convo.title = a.title
            convo.summary = a.summary
            convo.keyPoints = a.key_points
            convo.status = a.is_meaningful ? .done : .skipped
            store.update(convo)

            guard a.is_meaningful else { return }
            for item in a.action_items {
                store.addTodo(TodoItem(text: item.text, due: item.due.isEmpty ? nil : item.due,
                                       sourceConversationID: convo.id))
            }
            store.addFacts(a.facts.map {
                Fact(text: $0.text, category: FactCategory(rawValue: $0.category) ?? .other,
                     sourceConversationID: convo.id)
            })
        } catch {
            convo.status = .failed
            convo.errorMessage = error.localizedDescription
            store.update(convo)
        }
    }

    /// Retries anything that failed (e.g. no signal at the time).
    func processPending() async {
        let ids = MemoryStore.shared.conversations
            .filter { $0.status == .pending || $0.status == .failed }
            .map(\.id)
        for id in ids { await process(id) }
    }

    // MARK: Daily recap

    func makeRecap(for day: Date) async throws -> DailyRecap {
        let key = day.dayKey
        let convos = MemoryStore.shared.conversations
            .filter { $0.startedAt.dayKey == key && $0.status == .done }
            .sorted { $0.startedAt < $1.startedAt }
        guard !convos.isEmpty else {
            return DailyRecap(id: key, text: "No conversations were captured on this day.")
        }
        let digest = convos.map {
            "\($0.startedAt.formatted(date: .omitted, time: .shortened)) — \($0.title ?? "Untitled"): \($0.summary ?? "")"
        }.joined(separator: "\n")
        let todos = MemoryStore.shared.todos.filter { $0.createdAt.dayKey == key }
            .map { "- [\($0.isDone ? "x" : " ")] \($0.text)" }.joined(separator: "\n")

        let client = try ClaudeClient.fromSettings()
        let text = try await client.send(
            system: [["type": "text", "text": """
            You are Hive, a warm, concise personal assistant for \(ownerLine). Write their end-of-day recap: \
            a one-line headline, then short sections for highlights, people they talked with, decisions, and \
            what to follow up on tomorrow. Plain text with simple "•" bullets, no markdown headers. \
            Use the language the summaries are written in.
            """]],
            messages: [["role": "user", "content": "Conversations on \(day.formatted(date: .complete, time: .omitted)):\n\(digest)\n\nTo-dos created that day:\n\(todos.isEmpty ? "(none)" : todos)"]],
            effort: "medium")
        let recap = DailyRecap(id: key, text: text)
        MemoryStore.shared.setRecap(recap)
        return recap
    }

    // MARK: Ask Hive (chat over your memory)

    func answer(_ history: [ChatMessage]) async throws -> String {
        let store = MemoryStore.shared
        let facts = store.facts.filter(\.isConfirmed).map { "- \($0.text)" }.joined(separator: "\n")
        let pendingFacts = store.facts.filter { !$0.isConfirmed }.prefix(50).map { "- \($0.text)" }.joined(separator: "\n")
        let convos = store.conversations.filter { $0.status == .done }.prefix(60).map {
            "• \($0.startedAt.formatted(date: .abbreviated, time: .shortened)) — \($0.title ?? ""): \($0.summary ?? "") \($0.keyPoints.joined(separator: "; "))"
        }.joined(separator: "\n")
        let todos = store.openTodos.map { "- \($0.text)\($0.due.map { " (due \($0))" } ?? "")" }.joined(separator: "\n")

        let instructions = """
        You are Hive, the personal assistant of \(ownerLine). You answer questions using what you remember \
        from their past conversations, listed below. Be concise and specific, cite when something happened \
        ("on Tuesday afternoon you…"), and say plainly when your memory doesn't contain the answer instead of \
        guessing. Reply in the language the user writes in.
        """
        let memory = """
        Confirmed facts:
        \(facts.isEmpty ? "(none)" : facts)

        Unconfirmed facts (may be wrong):
        \(pendingFacts.isEmpty ? "(none)" : pendingFacts)

        Open to-dos:
        \(todos.isEmpty ? "(none)" : todos)

        Recent conversations (newest first):
        \(convos.isEmpty ? "(none)" : convos)

        Current time: \(Date().formatted(date: .complete, time: .shortened))
        """
        let client = try ClaudeClient.fromSettings()
        return try await client.send(
            system: [["type": "text", "text": instructions, "cache_control": ["type": "ephemeral"]],
                     ["type": "text", "text": memory]],
            messages: history.map { m -> [String: Any] in ["role": m.role.rawValue, "content": m.text] },
            effort: "low")
    }
}
