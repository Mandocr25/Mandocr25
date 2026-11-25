import AppIntents
import SwiftUI
import WidgetKit

struct ListeningEntry: TimelineEntry {
    let date: Date
    let isListening: Bool
    let since: Date?
    let openTodos: Int
}

struct ListeningProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListeningEntry {
        ListeningEntry(date: .now, isListening: false, since: nil, openTodos: 0)
    }
    func getSnapshot(in context: Context, completion: @escaping (ListeningEntry) -> Void) {
        completion(current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ListeningEntry>) -> Void) {
        // The app reloads this timeline whenever listening state changes.
        completion(Timeline(entries: [current()], policy: .never))
    }
    private func current() -> ListeningEntry {
        ListeningEntry(date: .now,
                       isListening: SharedState.isListening,
                       since: SharedState.listeningSince,
                       openTodos: SharedState.openTodoCount)
    }
}

/// Lock screen widget: tap it to turn Hive on or off without unlocking.
struct LockScreenToggleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedState.lockScreenWidgetKind, provider: ListeningProvider()) { entry in
            LockScreenToggleView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hive Listening")
        .description("Tap to turn your assistant on or off.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

struct LockScreenToggleView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ListeningEntry

    private var symbol: String { entry.isListening ? "waveform.circle.fill" : "mic.slash.circle" }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: ToggleListeningIntent(value: !entry.isListening)) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: entry.isListening ? "waveform" : "mic.slash")
                        .font(.title2.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .widgetAccentable()

        case .accessoryRectangular:
            Button(intent: ToggleListeningIntent(value: !entry.isListening)) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Hive").font(.headline)
                        if entry.isListening, let since = entry.since {
                            Text("Listening · \(since, style: .timer)").font(.caption)
                        } else {
                            Text("Paused · tap to start").font(.caption)
                        }
                        if entry.openTodos > 0 {
                            Text("\(entry.openTodos) to-dos").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

        case .accessoryInline:
            // Inline widgets can't host buttons; tapping opens the app.
            Label(entry.isListening ? "Hive listening" : "Hive paused", systemImage: symbol)

        default:
            Button(intent: ToggleListeningIntent(value: !entry.isListening)) {
                VStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(entry.isListening ? .orange : .secondary)
                    Text(entry.isListening ? "Listening" : "Paused").font(.headline)
                    Text(entry.isListening ? "Tap to stop" : "Tap to start")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
    }
}
