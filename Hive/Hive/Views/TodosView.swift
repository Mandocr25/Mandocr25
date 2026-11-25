import SwiftUI

struct TodosView: View {
    @EnvironmentObject private var store: MemoryStore
    @State private var newText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add a to-do", text: $newText).onSubmit(add)
                        Button(action: add) { Image(systemName: "plus.circle.fill") }
                            .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Open") {
                    if store.openTodos.isEmpty { Text("Nothing pending 🎉").foregroundStyle(.secondary) }
                    ForEach(store.openTodos) { row($0) }
                        .onDelete { $0.map { store.openTodos[$0].id }.forEach(store.deleteTodo) }
                }
                let done = store.todos.filter(\.isDone)
                if !done.isEmpty {
                    Section("Done") {
                        ForEach(done) { row($0) }
                            .onDelete { $0.map { done[$0].id }.forEach(store.deleteTodo) }
                    }
                }
            }
            .navigationTitle("To-dos")
        }
    }

    private func row(_ t: TodoItem) -> some View {
        Button { store.toggleTodo(t.id) } label: {
            HStack(alignment: .top) {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(t.isDone ? Color.orange : Color.secondary)
                VStack(alignment: .leading) {
                    Text(t.text).strikethrough(t.isDone).foregroundStyle(t.isDone ? .secondary : .primary)
                    if let due = t.due { Text(due).font(.caption).foregroundStyle(.orange) }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        store.addTodo(TodoItem(text: text))
        newText = ""
    }
}
