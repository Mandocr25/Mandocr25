import SwiftUI
import WidgetKit

@main
struct HiveWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LockScreenToggleWidget()   // Lock screen widget (circular / rectangular / inline) + home screen small
        ListeningControl()         // iOS 18 control: lock screen bottom buttons, Control Center, Action Button
        ListeningLiveActivity()    // "Hive is listening" banner on the lock screen
    }
}
