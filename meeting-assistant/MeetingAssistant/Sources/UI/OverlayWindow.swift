import AppKit

// NSPanel subclass: non-activating, always-on-top, transparent
final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    // acceptsFirstMouse is an NSView method, not NSWindow/NSPanel.
    // .nonactivatingPanel styleMask already ensures clicks register without stealing focus.

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        // Allow clicks in overlay buttons without activating the app
        acceptsMouseMovedEvents = true
    }
}
