import SwiftUI

/// Chat with Hive about anything it has heard: "What did Ana recommend yesterday?"
struct AskView: View {
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var thinking = false
    @State private var error: String?

    private let suggestions = [
        "What did I promise to do this week?",
        "Summarize my day so far",
        "¿Qué me recomendaron recientemente?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if messages.isEmpty {
                                Text("Ask about your conversations, people, plans or to-dos.")
                                    .foregroundStyle(.secondary).padding(.top, 40)
                                ForEach(suggestions, id: \.self) { s in
                                    Button(s) { input = s; send() }.buttonStyle(.bordered)
                                }
                            }
                            ForEach(messages) { bubble($0).id($0.id) }
                            if thinking { ProgressView().padding(.leading) }
                            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                Divider()
                HStack {
                    TextField("Ask Hive…", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(send)
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title) }
                        .disabled(thinking || input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Ask Hive")
            .toolbar {
                if !messages.isEmpty { Button("Clear") { messages = []; error = nil } }
            }
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text)
                .textSelection(.enabled)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(m.role == .user ? Color.orange.opacity(0.85) : Color.secondary.opacity(0.15)))
                .foregroundStyle(m.role == .user ? .white : .primary)
            if m.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        input = ""; error = nil
        messages.append(ChatMessage(role: .user, text: text))
        thinking = true
        Task {
            do {
                let reply = try await AssistantBrain.shared.answer(messages)
                messages.append(ChatMessage(role: .assistant, text: reply))
            } catch {
                self.error = error.localizedDescription
            }
            thinking = false
        }
    }
}
