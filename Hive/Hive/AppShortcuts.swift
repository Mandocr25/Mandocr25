import AppIntents

struct StartListeningIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Hive"
    @MainActor func perform() async throws -> some IntentResult {
        try await ListeningController.shared.setListening(true)
        return .result()
    }
}

struct StopListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Hive"
    @MainActor func perform() async throws -> some IntentResult {
        try await ListeningController.shared.setListening(false)
        return .result()
    }
}

/// "Hey Siri, start Hive" — also usable from Shortcuts, Back Tap and Focus automations.
struct HiveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartListeningIntent(),
                    phrases: ["Start \(.applicationName)", "Start listening with \(.applicationName)"],
                    shortTitle: "Start Hive", systemImageName: "waveform")
        AppShortcut(intent: StopListeningIntent(),
                    phrases: ["Stop \(.applicationName)", "Stop listening with \(.applicationName)"],
                    shortTitle: "Stop Hive", systemImageName: "mic.slash")
    }
}
