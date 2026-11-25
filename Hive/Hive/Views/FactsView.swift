import SwiftUI

/// What Hive has learned about you. New memories wait here until you confirm or discard them.
struct FactsView: View {
    @EnvironmentObject private var store: MemoryStore

    var body: some View {
        NavigationStack {
            List {
                let pending = store.facts.filter { !$0.isConfirmed }
                if !pending.isEmpty {
                    Section {
                        ForEach(pending) { f in
                            HStack {
                                Label(f.text, systemImage: f.category.symbol)
                                Spacer()
                                Button { store.deleteFact(f.id) } label: { Image(systemName: "xmark.circle") }
                                    .buttonStyle(.borderless).tint(.secondary)
                                Button { store.confirmFact(f.id) } label: { Image(systemName: "checkmark.circle.fill") }
                                    .buttonStyle(.borderless)
                            }
                        }
                    } header: { Text("New — is this right?") }
                }
                ForEach(FactCategory.allCases, id: \.self) { cat in
                    let facts = store.facts.filter { $0.isConfirmed && $0.category == cat }
                    if !facts.isEmpty {
                        Section(cat.rawValue.capitalized) {
                            ForEach(facts) { Text($0.text) }
                                .onDelete { $0.map { facts[$0].id }.forEach(store.deleteFact) }
                        }
                    }
                }
                if store.facts.isEmpty {
                    ContentUnavailableView("No memories yet", systemImage: "brain",
                                           description: Text("Hive learns facts about you from your conversations — people, plans, preferences."))
                }
            }
            .navigationTitle("Memory")
        }
    }
}
