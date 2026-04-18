import AppKit
import SwiftUI

/// Owns and manages the single floating overlay NSPanel.
final class OverlayWindowController: NSWindowController {

    convenience init() {
        let hostingController = NSHostingController(
            rootView: ContentView()
                .environmentObject(MeetingCoordinator.shared)
        )
        let panel = OverlayWindow(contentViewController: hostingController)
        self.init(window: panel)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }
}
