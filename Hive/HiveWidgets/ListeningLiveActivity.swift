import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct ListeningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title)
                    .foregroundStyle(.orange)
                    .symbolEffect(.variableColor.iterative)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Hive is listening").font(.headline)
                        Text(context.attributes.startedAt, style: .timer)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(context.state.lastSnippet.isEmpty ? "Waiting for conversation…" : context.state.lastSnippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(intent: ToggleListeningIntent(value: false)) {
                    Image(systemName: "stop.fill")
                        .padding(10)
                        .background(Circle().fill(.orange.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
        } dynamicIsland: { context in
            // iPhone 13 has no Dynamic Island, but the configuration is required.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "waveform").foregroundStyle(.orange) }
                DynamicIslandExpandedRegion(.center) { Text("Hive is listening") }
                DynamicIslandExpandedRegion(.trailing) { Text(context.attributes.startedAt, style: .timer).monospacedDigit() }
            } compactLeading: {
                Image(systemName: "waveform").foregroundStyle(.orange)
            } compactTrailing: {
                Text("\(context.state.utteranceCount)")
            } minimal: {
                Image(systemName: "waveform").foregroundStyle(.orange)
            }
        }
    }
}
