import AppIntents
import Foundation

/// The single intent behind the lock screen widget button and the lock screen / Control Center toggle.
///
/// It conforms to `AudioRecordingIntent`, so iOS runs it in the app's process and allows the app to
/// start the microphone from the background (as long as it starts a Live Activity, which we do).
struct ToggleListeningIntent: SetValueIntent, AudioRecordingIntent {
    static let title: LocalizedStringResource = "Turn Hive Listening On or Off"

    @Parameter(title: "Listening")
    var value: Bool

    init() {}
    init(value: Bool) { self.value = value }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if HIVE_APP
        try await ListeningController.shared.setListening(value)
        #else
        SharedState.isListening = value
        SharedState.reloadWidgets()
        #endif
        return .result()
    }
}
