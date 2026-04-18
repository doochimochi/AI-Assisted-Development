import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: NSWindowController {
    private let coordinator: MeetingCoordinator

    init(coordinator: MeetingCoordinator) {
        self.coordinator = coordinator
        let initialRect = NSRect(x: 100, y: 200, width: 380, height: 680)
        let window = OverlayWindow(contentRect: initialRect)

        super.init(window: window)

        let rootView = ContentView()
            .environmentObject(coordinator)
            .environmentObject(coordinator.transcriptStore)
            .environmentObject(coordinator.wordResearcher)
            .environmentObject(coordinator.answerFinder)
            .environmentObject(coordinator.questionGenerator)
            .environmentObject(AppSettings.shared)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        setupDragTracking(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func toggle() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func setupDragTracking(window: NSWindow) {
        // Drag is handled inside SwiftUI via .gesture on the drag handle view
    }
}
