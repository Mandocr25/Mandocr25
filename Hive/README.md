# Hive — an ambient personal assistant for iPhone

Hive is an "always-listening" personal assistant inspired by wearables like **Bee** (bought by Amazon in 2025).
It turns your **iPhone 13** into the device: it listens to your conversations, transcribes them **on the phone**,
and uses **Claude** to turn them into summaries, to-dos, memories about your life and a daily recap.
You can ask it questions about anything it heard. You can turn it on and off from the **lock screen**.

## What Bee does, and what Hive does

| Bee (Pioneer wristband/clip + app) | Hive on iPhone 13 |
|---|---|
| Always-on mics in a wristband or clip, with a button to mute | iPhone mic (or AirPods), toggled from the lock screen widget, the lock screen control, Siri or Back Tap |
| Transcribes, doesn't keep audio | On-device Apple speech recognition. **Audio is never saved**, only text |
| Splits your day into conversations and summarizes each one | Splits after a pause (2 min by default), Claude writes the title, summary and key points |
| Picks up to-dos ("I'll send you the deck tomorrow") | Action items become to-dos automatically |
| Learns "facts" about you that you confirm or reject | **Memory** tab: new facts wait for ✓ / ✕ |
| Daily summary / journal | **Today's recap** |
| Chat with your memories | **Ask** tab ("What did Ana recommend yesterday?") |
| Email, calendar and location integrations | *Not yet*. See roadmap |

### About hardware
You don't need any extra hardware. The iPhone mic picks up conversations well when the phone is on a table or
in a shirt pocket, and worse in a pants pocket. Paired AirPods are also used as the mic if they're connected.
A custom wearable (a BLE mic like Bee's) is possible later but needs hardware design work. See roadmap.

## Lock screen controls (activate / deactivate)
Hive gives you three ways to switch it from the lock screen without unlocking:

1. **Lock screen widget**: long-press the lock screen → *Customize* → *Lock Screen* → tap the widget row →
   add **Hive Listening**. The circle or rectangle version is a button: tap it to start or stop.
2. **Lock screen control (iOS 18+)**: in the same customize screen, replace the flashlight or camera button
   at the bottom with the **Hive** control. You can also add it to Control Center.
3. **Live Activity**: while Hive is listening, a "Hive is listening · 12:34" banner stays on the lock screen
   with a ■ stop button. iOS requires it whenever recording starts from a widget.

You can also say **"Hey Siri, start Hive"** / **"stop Hive"**, or map *Start Hive* to
*Settings → Accessibility → Touch → Back Tap* (double-tap the back of the phone).

## What you need
- A **Mac with Xcode 16 or newer** (iOS apps can only be built on macOS)
- An **Apple ID**. A free one works for installing on your own phone, but the app expires after 7 days and must
  be re-run from Xcode. The paid Apple Developer Program ($99/yr) removes that limit. If Xcode refuses the
  *App Groups* capability with a free account, you'll need the paid program.
- An iPhone running **iOS 18 or newer**. The iPhone 13 supports iOS 18 and iOS 26.
- An **Anthropic API key** from <https://console.anthropic.com> (pay-per-use, see Costs)

## Build & install
```bash
brew install xcodegen
cd Hive
# 1. Replace "com.yourname" with something unique in project.yml AND the App Group in Shared/SharedState.swift
xcodegen generate
open Hive.xcodeproj
```
2. In Xcode, select the **Hive** target → *Signing & Capabilities* → choose your Team. Do the same for **HiveWidgets**.
3. Connect the iPhone. On the phone, turn on *Settings → Privacy & Security → Developer Mode*. Then press ▶︎ Run.
4. On first launch, open ⚙️ Settings in Hive, paste your API key and enter your name.
5. Tap the big mic button once in the app to grant Microphone + Speech Recognition permissions.
6. Add the lock screen widget or control (see above).

## Project layout
```
Hive/
├── project.yml                 XcodeGen spec (app + widget extension, App Group, background audio)
├── Shared/                     Compiled into both targets
│   ├── SharedState.swift          on/off state shared with widgets via App Group
│   ├── ToggleListeningIntent.swift  the App Intent behind every toggle (AudioRecordingIntent)
│   └── ListeningActivityAttributes.swift  Live Activity data
├── Hive/                       The app
│   ├── ListeningController.swift  start/stop, splitting speech into conversations
│   ├── LiveTranscriber.swift      AVAudioEngine + on-device SFSpeechRecognizer, runs in the background
│   ├── AssistantBrain.swift       Claude prompts: analysis (structured JSON), daily recap, Ask
│   ├── ClaudeClient.swift         Claude Messages API over HTTPS
│   ├── MemoryStore.swift          local JSON storage (conversations, to-dos, facts, recaps)
│   ├── LiveActivityManager.swift, Keychain.swift, Settings.swift, AppShortcuts.swift
│   └── Views/                     Today, Conversations, To-dos, Memory, Ask, Settings
└── HiveWidgets/                Lock screen widget, iOS 18 control, Live Activity
```

## How it works
1. **Listening**: `AVAudioEngine` feeds mic audio into Apple's on-device speech recognizer. The app keeps running
   while locked because of the `audio` background mode. Recognition restarts every ~50 s so it can run for hours.
2. **Splitting**: when nobody has spoken for the silence gap, or after 45 minutes, the text so far becomes one
   *conversation*. Fragments under ~12 words are dropped as noise.
3. **Thinking**: the transcript and the facts Hive already knows go to Claude, which returns JSON that matches
   a fixed schema: `title, summary, key_points, action_items, facts, is_meaningful`. Background TV and noise are
   marked `is_meaningful: false` and hidden. If there is no signal, the conversation is retried later.
4. **Everything stays on your phone** except the transcript text sent to Claude for analysis.

## Costs and battery
- **Claude**: the default model is Claude Opus 5.5 (best quality). A typical 10-minute conversation is a few
  thousand tokens, roughly a cent or two with Opus. You can switch to **Sonnet 5.5** or **Haiku 5.5** in Settings
  to cut costs a lot. Ask questions use low effort and prompt caching.
- **Battery**: continuous recognition uses battery. Expect several hours of listening, not all day. Toggle it from
  the lock screen for the parts of the day that matter (meetings, classes, dinners).

## Privacy & legal ⚠️
Recording conversations without consent is **illegal in many places**. Several US states and many countries require
everyone's consent. Tell people when Hive is on. Hive never stores audio, keeps transcripts only on your
phone, and sends text to the Anthropic API for analysis. Use *Settings → Erase all memories* to wipe everything.

## Known limitations
- No speaker identification (Apple's recognizer has none), so Claude infers who said what from context.
- iOS may stop listening during phone calls or when another app takes the mic exclusively. Hive tries to resume.
- The very first start must happen in the app so iOS can show the permission prompts.
- Not built or tested here: this code was written without a Mac, so expect some small Xcode fixes on first build.

## Roadmap ideas
- Calendar & Reminders integration (EventKit): create real reminders/events from to-dos
- Apple Watch app as a wearable mic + toggle
- iOS 26 `SpeechAnalyzer` for better long-form transcription
- Location tagging ("conversation at the office")
- Weekly insights and "people" pages
- A custom BLE wearable mic (ESP32 + I2S mic) streaming to the app, which is the closest thing to Bee's hardware
