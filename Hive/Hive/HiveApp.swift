import SwiftUI

@main
struct HiveApp: App {
    @StateObject private var listening = ListeningController.shared
    @StateObject private var store = MemoryStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(listening)
                .environmentObject(store)
                .tint(.orange)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await AssistantBrain.shared.processPending() } }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Today", systemImage: "sun.max") }
            ConversationsView().tabItem { Label("Conversations", systemImage: "bubble.left.and.bubble.right") }
            TodosView().tabItem { Label("To-dos", systemImage: "checklist") }
            FactsView().tabItem { Label("Memory", systemImage: "brain") }
            AskView().tabItem { Label("Ask", systemImage: "sparkles") }
        }
    }
}
