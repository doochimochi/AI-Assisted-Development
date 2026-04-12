import AppKit

/// Non-activating floating panel that sits above all normal windows.
///
/// Key properties:
/// - `.floating` level: above normal apps, below full-screen spaces
/// - `.nonactivatingPanel`: clicks do not steal focus from Zoom/Teams
/// - `acceptsFirstMouse`: buttons respond on first click without activating
final class OverlayWindow: NSPanel {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 360, height: 620),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true  // drag anywhere on the frosted background
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
    }
}
