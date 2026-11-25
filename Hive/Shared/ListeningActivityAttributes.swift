import ActivityKit
import Foundation

/// Live Activity shown on the lock screen while Hive is listening.
/// iOS requires an on-screen indicator when recording is started from a widget or control.
struct ListeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var utteranceCount: Int
        var lastSnippet: String
    }
    var startedAt: Date
}
