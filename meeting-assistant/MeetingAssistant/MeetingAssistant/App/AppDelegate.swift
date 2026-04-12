import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var overlayWindowController: OverlayWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon — status bar only

        setupStatusBarItem()
        showOverlay()
    }

    // MARK: - Status Bar

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "mic.badge.plus", accessibilityDescription: "Meeting Assistant")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Overlay",  action: #selector(showOverlay),  keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Overlay",  action: #selector(hideOverlay),  keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit",          action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - Overlay

    @objc func showOverlay() {
        if overlayWindowController == nil {
            overlayWindowController = OverlayWindowController()
        }
        overlayWindowController?.showWindow(nil)
    }

    @objc func hideOverlay() {
        overlayWindowController?.close()
    }

    // MARK: - Global keyboard shortcut (Cmd+Shift+M)

    func applicationDidBecomeActive(_ notification: Notification) { }

    func applicationWillTerminate(_ notification: Notification) {
        // Trigger session end-save if a session is active
        Task { @MainActor in
            await MeetingCoordinator.shared.endSession()
        }
    }
}
