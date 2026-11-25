import ActivityKit
import Foundation

/// Shows / updates / ends the "Hive is listening" Live Activity on the lock screen.
@MainActor
enum LiveActivityManager {
    private static var activity: Activity<ListeningActivityAttributes>?

    static func start(since: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Clean up leftovers from a previous run.
        for a in Activity<ListeningActivityAttributes>.activities where a.id != activity?.id {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        guard activity == nil else { return }
        let state = ListeningActivityAttributes.ContentState(utteranceCount: 0, lastSnippet: "")
        activity = try? Activity.request(attributes: ListeningActivityAttributes(startedAt: since),
                                         content: ActivityContent(state: state, staleDate: nil))
    }

    static func update(count: Int, snippet: String) {
        guard let activity else { return }
        let state = ListeningActivityAttributes.ContentState(utteranceCount: count,
                                                             lastSnippet: String(snippet.suffix(80)))
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    static func stop() {
        let current = activity
        activity = nil
        Task {
            await current?.end(nil, dismissalPolicy: .immediate)
            for a in Activity<ListeningActivityAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
