import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MemoryStore
    @AppStorage(Settings.modelKey) private var model = ClaudeClient.defaultModel
    @AppStorage(Settings.localeKey) private var locale = ""
    @AppStorage(Settings.silenceGapKey) private var silenceGap = 120.0
    @AppStorage(Settings.userNameKey) private var userName = ""
    @State private var apiKey = Keychain.apiKey ?? ""
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $userName)
                } header: { Text("You") } footer: { Text("Helps Hive tell you apart from other people in conversations.") }

                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Model", selection: $model) {
                        ForEach(ClaudeClient.models, id: \.id) { Text($0.label).tag($0.id) }
                    }
                } header: { Text("Claude") } footer: {
                    Text("Get a key at console.anthropic.com. It's stored in the iOS Keychain. Only transcripts (never audio) are sent to Claude for summaries.")
                }

                Section {
                    Picker("Language", selection: $locale) {
                        ForEach(Settings.speechLocales, id: \.id) { Text($0.label).tag($0.id) }
                    }
                    Stepper("New conversation after \(Int(silenceGap / 60)) min of silence",
                            value: $silenceGap, in: 60...900, step: 60)
                } header: { Text("Listening") } footer: {
                    Text("Speech is transcribed on your iPhone. Changes apply the next time listening starts.")
                }

                Section("Lock screen") {
                    Label("Long-press the lock screen → Customize → Lock Screen → tap the widget area → add “Hive Listening”.", systemImage: "lock.iphone")
                    Label("Or replace the flashlight/camera button at the bottom with the “Hive” control.", systemImage: "switch.2")
                    Label("Say “Hey Siri, start Hive”, or set Settings → Accessibility → Touch → Back Tap → Start Hive.", systemImage: "hand.tap")
                }

                Section {
                    Button("Erase all memories", role: .destructive) { confirmErase = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { Keychain.apiKey = apiKey; dismiss() }
            }
            .confirmationDialog("Erase every conversation, to-do and memory?", isPresented: $confirmErase,
                                titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) { store.eraseEverything() }
            }
        }
    }
}
