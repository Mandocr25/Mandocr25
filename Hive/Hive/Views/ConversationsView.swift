import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject private var store: MemoryStore
    @State private var showSkipped = false

    private var grouped: [(day: String, items: [Conversation])] {
        let visible = store.conversations.filter { showSkipped || $0.status != .skipped }
        let groups = Dictionary(grouping: visible) { $0.startedAt.dayKey }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.startedAt > $1.startedAt }) }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.conversations.isEmpty {
                    ContentUnavailableView("No conversations yet", systemImage: "waveform",
                                           description: Text("Turn on listening and Hive will capture and summarize your conversations."))
                }
                ForEach(grouped, id: \.day) { group in
                    Section(header(for: group.items.first!.startedAt)) {
                        ForEach(group.items) { c in
                            NavigationLink(value: c.id) { ConversationRow(convo: c) }
                        }
                        .onDelete { idx in idx.map { group.items[$0].id }.forEach(store.deleteConversation) }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationDestination(for: UUID.self) { ConversationDetailView(id: $0) }
            .toolbar {
                Toggle(isOn: $showSkipped) { Image(systemName: "line.3.horizontal.decrease.circle") }
                    .toggleStyle(.button)
                    .accessibilityLabel("Show background noise")
            }
        }
    }

    private func header(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .complete, time: .omitted)
    }
}

struct ConversationRow: View {
    let convo: Conversation
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(convo.title ?? "New conversation").font(.headline).lineLimit(1)
                Spacer()
                statusIcon
            }
            Text(convo.summary ?? convo.transcript.first?.text ?? "")
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            Text("\(convo.startedAt.formatted(date: .omitted, time: .shortened)) – \(convo.endedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var statusIcon: some View {
        switch convo.status {
        case .pending, .processing: ProgressView().controlSize(.small)
        case .failed: Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
        case .skipped: Image(systemName: "speaker.slash").foregroundStyle(.secondary)
        case .done: EmptyView()
        }
    }
}

struct ConversationDetailView: View {
    @EnvironmentObject private var store: MemoryStore
    let id: UUID

    var body: some View {
        if let c = store.conversation(id) {
            List {
                if let summary = c.summary {
                    Section("Summary") { Text(summary).textSelection(.enabled) }
                }
                if !c.keyPoints.isEmpty {
                    Section("Key points") { ForEach(c.keyPoints, id: \.self) { Label($0, systemImage: "smallcircle.filled.circle") } }
                }
                let todos = store.todos.filter { $0.sourceConversationID == c.id }
                if !todos.isEmpty {
                    Section("To-dos") { ForEach(todos) { Label($0.text, systemImage: $0.isDone ? "checkmark.circle.fill" : "circle") } }
                }
                let facts = store.facts.filter { $0.sourceConversationID == c.id }
                if !facts.isEmpty {
                    Section("Learned") { ForEach(facts) { Label($0.text, systemImage: $0.category.symbol) } }
                }
                if let err = c.errorMessage {
                    Section { Text(err).foregroundStyle(.red) }
                }
                Section {
                    Button("Summarize again") { Task { await AssistantBrain.shared.process(c.id) } }
                        .disabled(c.status == .processing)
                }
                Section("Transcript") {
                    ForEach(c.transcript) { u in
                        VStack(alignment: .leading) {
                            Text(u.date.formatted(date: .omitted, time: .standard)).font(.caption2).foregroundStyle(.secondary)
                            Text(u.text).textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle(c.title ?? "Conversation")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Deleted", systemImage: "trash")
        }
    }
}
