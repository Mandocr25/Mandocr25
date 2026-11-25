import AppIntents
import SwiftUI
import WidgetKit

/// iOS 18 control. Add it to the lock screen (long-press lock screen → Customize → replace the
/// flashlight/camera button) or to Control Center.
struct ListeningControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SharedState.controlKind, provider: Provider()) { isOn in
            ControlWidgetToggle("Hive", isOn: isOn, action: ToggleListeningIntent()) { on in
                Label(on ? "Listening" : "Paused", systemImage: on ? "waveform" : "mic.slash")
            }
            .tint(.orange)
        }
        .displayName("Hive Listening")
        .description("Turn your ambient assistant on or off.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { SharedState.isListening }
    }
}
