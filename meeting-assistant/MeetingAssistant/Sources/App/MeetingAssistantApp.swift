import SwiftUI

@main
struct MeetingAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window - UI is managed by OverlayWindowController via AppDelegate
        Settings {
            EmptyView()
        }
    }
}
