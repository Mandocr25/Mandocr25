import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var listening: ListeningController
    @EnvironmentObject private var store: MemoryStore
    @State private var showSettings = false
    @State private var recap: DailyRecap?
    @State private var recapLoading = false
    @State private var recapError: String?
    @State private var hasAPIKey = Keychain.apiKey != nil

    private var today: [Conversation] {
        store.conversations.filter { Calendar.current.isDateInToday($0.startedAt) && $0.status != .skipped }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !hasAPIKey {
                        notice("Add your Anthropic API key in Settings so Hive can summarize conversations.",
                               systemImage: "key") { showSettings = true }
                    }
                    listenCard
                    if let err = listening.lastError {
                        notice(err, systemImage: "exclamationmark.triangle") { listening.lastError = nil }
                    }
                    recapCard
                    statsRow
                    if !store.openTodos.isEmpty { todoPreview }
                }
                .padding()
            }
            .navigationTitle("Hive")
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showSettings, onDismiss: { hasAPIKey = Keychain.apiKey != nil }) { SettingsView() }
            .onAppear { recap = store.recap(for: Date().dayKey) }
        }
    }

    private var listenCard: some View {
        VStack(spacing: 14) {
            Button { Task { await listening.toggle() } } label: {
                ZStack {
                    Circle()
                        .fill(listening.isListening ? Color.orange : Color.secondary.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .shadow(color: listening.isListening ? .orange.opacity(0.5) : .clear, radius: 20)
                    Image(systemName: listening.isListening ? "waveform" : "mic.slash")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(listening.isListening ? .white : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: listening.isListening)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(listening.isListening ? "Stop listening" : "Start listening")

            if listening.isListening, let since = listening.listeningSince {
                Text("Listening for \(since, style: .timer)").font(.headline)
            } else {
                Text("Paused").font(.headline)
            }
            Text(listening.isListening
                 ? (listening.partialText.isEmpty ? "Waiting for conversation…" : listening.partialText)
                 : "Tap to start, or use the lock screen widget.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(.background.secondary))
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today's recap", systemImage: "text.book.closed").font(.headline)
                Spacer()
                Button(recap == nil ? "Generate" : "Refresh") {
                    recapLoading = true; recapError = nil
                    Task {
                        do { recap = try await AssistantBrain.shared.makeRecap(for: Date()) }
                        catch { recapError = error.localizedDescription }
                        recapLoading = false
                    }
                }
                .disabled(recapLoading)
            }
            if recapLoading { ProgressView().frame(maxWidth: .infinity) }
            else if let recapError { Text(recapError).font(.footnote).foregroundStyle(.red) }
            else if let recap { Text(recap.text).font(.callout).textSelection(.enabled) }
            else { Text("A summary of your day, built from today's conversations.").font(.footnote).foregroundStyle(.secondary) }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.background.secondary))
    }

    private var statsRow: some View {
        HStack {
            stat("\(today.count)", "conversations")
            stat("\(store.openTodos.count)", "open to-dos")
            stat("\(store.facts.filter { !$0.isConfirmed }.count)", "new memories")
        }
    }

    private var todoPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Up next", systemImage: "checklist").font(.headline)
            ForEach(store.openTodos.prefix(4)) { t in
                Button { store.toggleTodo(t.id) } label: {
                    HStack(alignment: .top) {
                        Image(systemName: "circle")
                        Text(t.text).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.background.secondary))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background.secondary))
    }

    private func notice(_ text: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(text, systemImage: systemImage)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}
