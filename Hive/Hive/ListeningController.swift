import Foundation
import UIKit

enum ListeningError: Error, CustomLocalizedStringResourceConvertible {
    case permissionsMissing
    var localizedStringResource: LocalizedStringResource {
        "Open Hive once and allow Microphone and Speech Recognition."
    }
}

/// Owns the on/off state. Called from the app UI, the lock screen widget, the control, Siri and Shortcuts.
@MainActor
final class ListeningController: ObservableObject {
    static let shared = ListeningController()

    @Published private(set) var isListening = false
    @Published private(set) var partialText = ""
    @Published private(set) var currentUtterances: [Utterance] = []
    @Published private(set) var listeningSince: Date?
    @Published var lastError: String?

    private let transcriber = LiveTranscriber()
    private var segmentStartedAt: Date?
    private var lastSpeechAt = Date()
    private var segmentTimer: Timer?
    private let maxSegment: TimeInterval = 45 * 60

    private init() {
        // Nothing is listening when the process starts; make the widgets agree.
        SharedState.isListening = false
        SharedState.listeningSince = nil
        SharedState.reloadWidgets()

        transcriber.onPartial = { [weak self] text in
            guard let self else { return }
            self.partialText = text
            self.lastSpeechAt = Date()
        }
        transcriber.onUtterance = { [weak self] text in self?.append(text) }
        transcriber.onFailure = { [weak self] msg in
            self?.lastError = msg
            Task { try? await self?.setListening(false) }
        }
    }

    func setListening(_ on: Bool) async throws {
        if on == isListening { SharedState.isListening = on; SharedState.reloadWidgets(); return }
        on ? try await start() : await stop()
    }

    func toggle() async {
        do { try await setListening(!isListening) } catch { lastError = error.localizedDescription }
    }

    private func start() async throws {
        if !LiveTranscriber.hasPermissions {
            // Permission prompts only work while the app is on screen.
            guard UIApplication.shared.applicationState == .active,
                  await LiveTranscriber.requestPermissions() else { throw ListeningError.permissionsMissing }
        }
        try transcriber.start(locale: Settings.speechLocale)
        let now = Date()
        isListening = true
        listeningSince = now
        lastError = nil
        lastSpeechAt = now
        SharedState.isListening = true
        SharedState.listeningSince = now
        SharedState.reloadWidgets()
        LiveActivityManager.start(since: now)

        segmentTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSegment() }
        }
    }

    private func stop() async {
        segmentTimer?.invalidate(); segmentTimer = nil
        transcriber.stop()
        // Give the recognizer a moment to deliver the final words.
        try? await Task.sleep(for: .seconds(1.5))
        finalizeSegment()
        isListening = false
        listeningSince = nil
        partialText = ""
        SharedState.isListening = false
        SharedState.listeningSince = nil
        SharedState.reloadWidgets()
        LiveActivityManager.stop()
    }

    private func append(_ text: String) {
        let now = Date()
        if segmentStartedAt == nil { segmentStartedAt = now }
        currentUtterances.append(Utterance(date: now, text: text))
        partialText = ""
        lastSpeechAt = now
        LiveActivityManager.update(count: currentUtterances.count, snippet: text)
    }

    /// A conversation ends after a long pause (default 2 min) or after 45 minutes.
    private func checkSegment() {
        guard let start = segmentStartedAt, !currentUtterances.isEmpty else { return }
        let now = Date()
        if now.timeIntervalSince(lastSpeechAt) > Settings.silenceGap || now.timeIntervalSince(start) > maxSegment {
            finalizeSegment()
        }
    }

    private func finalizeSegment() {
        defer { currentUtterances = []; segmentStartedAt = nil }
        guard let first = currentUtterances.first else { return }
        let convo = Conversation(startedAt: segmentStartedAt ?? first.date,
                                 endedAt: currentUtterances.last?.date ?? Date(),
                                 transcript: currentUtterances)
        guard convo.wordCount >= Settings.minWords else { return }   // ignore tiny fragments / noise
        MemoryStore.shared.add(convo)
        Task { await AssistantBrain.shared.process(convo.id) }
    }
}
