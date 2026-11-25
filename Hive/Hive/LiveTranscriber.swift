import AVFoundation
import Speech

/// Continuous, on-device speech-to-text from the microphone.
///
/// Apple's recognizer works best on short stretches, so we rotate to a fresh recognition request
/// every ~50 seconds while the audio engine keeps running; each finished request yields one utterance.
final class LiveTranscriber: NSObject {
    var onPartial: ((String) -> Void)?
    var onUtterance: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var rotateTimer: Timer?
    private(set) var isRunning = false

    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        return speech && mic
    }

    static var hasPermissions: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    func start(locale: Locale) throws {
        guard !isRunning else { return }
        guard let rec = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(), rec.isAvailable else {
            throw NSError(domain: "Hive", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognition isn't available for this language."])
        }
        recognizer = rec

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.lock(); let req = self.request; self.lock.unlock()
            req?.append(buffer)
        }
        engine.prepare()
        try engine.start()

        isRunning = true
        startRecognition()
        rotateTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { [weak self] _ in
            self?.rotate()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification, object: session)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        rotateTimer?.invalidate(); rotateTimer = nil
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); let req = request; request = nil; lock.unlock()
        req?.endAudio()   // flushes the last utterance through the result handler
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Private

    private func startRecognition() {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        req.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true   // private, free, works offline
        }
        lock.lock(); request = req; lock.unlock()

        var latest = ""
        var emitted = false
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                latest = result.bestTranscription.formattedString
                if !latest.isEmpty { DispatchQueue.main.async { self.onPartial?(latest) } }
            }
            let finished = (result?.isFinal ?? false) || error != nil
            if finished && !emitted {
                emitted = true
                let text = latest.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { DispatchQueue.main.async { self.onUtterance?(text) } }
                // If the task ended on its own (timeout/error) while we're still running, start another.
                DispatchQueue.main.async {
                    self.lock.lock(); let current = self.request; self.lock.unlock()
                    if self.isRunning && current === req { self.startRecognition() }
                }
            }
        }
    }

    private func rotate() {
        guard isRunning else { return }
        lock.lock(); let old = request; lock.unlock()
        startRecognition()
        old?.endAudio()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // e.g. a phone call. The engine is paused by the system.
            lock.lock(); let req = request; lock.unlock()
            req?.endAudio()
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                if !engine.isRunning { try engine.start() }
                startRecognition()
            } catch {
                DispatchQueue.main.async { self.onFailure?("Listening stopped after an interruption.") }
            }
        @unknown default: break
        }
    }
}
