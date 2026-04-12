import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindowController: OverlayWindowController?
    var statusItem: NSStatusItem?
    let coordinator = MeetingCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock (overlay-style app)
        NSApp.setActivationPolicy(.accessory)

        // Request Screen Recording permission
        AudioPermissionManager.shared.startObservingPermissionChanges()

        // Set up status bar menu
        setupStatusBar()

        // Show overlay window
        overlayWindowController = OverlayWindowController(coordinator: coordinator)

        // Global keyboard shortcut: Cmd+Shift+M to toggle
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 { // M
                Task { @MainActor in
                    self?.overlayWindowController?.toggle()
                }
            }
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Meeting Assistant")
            button.action = #selector(statusBarClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Meeting Assistant", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func statusBarClicked() {}
    @objc private func toggleOverlay() {
        overlayWindowController?.toggle()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running in status bar even if overlay is closed
    }
}
