import Foundation
import WidgetKit

/// State shared between the app and the widget extension through an App Group.
enum SharedState {
    /// Must match the App Group in project.yml (both targets).
    static let appGroupID = "group.com.yourname.hive"

    static let lockScreenWidgetKind = "HiveLockScreenToggle"
    static let controlKind = "com.hive.listening.control"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var isListening: Bool {
        get { defaults.bool(forKey: "isListening") }
        set { defaults.set(newValue, forKey: "isListening") }
    }

    static var listeningSince: Date? {
        get { defaults.object(forKey: "listeningSince") as? Date }
        set { defaults.set(newValue, forKey: "listeningSince") }
    }

    static var openTodoCount: Int {
        get { defaults.integer(forKey: "openTodoCount") }
        set { defaults.set(newValue, forKey: "openTodoCount") }
    }

    /// Ask the lock screen widget and the Control Center / lock screen control to redraw.
    static func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: lockScreenWidgetKind)
        ControlCenter.shared.reloadControls(ofKind: controlKind)
    }
}
