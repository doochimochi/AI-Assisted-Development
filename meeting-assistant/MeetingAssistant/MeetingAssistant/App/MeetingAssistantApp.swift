import SwiftUI
import AppKit

@main
struct MeetingAssistantApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The overlay window is managed entirely by AppDelegate / OverlayWindowController.
        // We use an empty Settings scene only so Xcode doesn't complain about no scenes.
        Settings { EmptyView() }
    }
}
