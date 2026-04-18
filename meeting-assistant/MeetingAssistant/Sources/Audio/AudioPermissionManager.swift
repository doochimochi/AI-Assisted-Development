import AppKit  // CGPreflightScreenCaptureAccess, CGRequestScreenCaptureAccess are CoreGraphics, available via AppKit

@MainActor
final class AudioPermissionManager: ObservableObject {
    @Published var screenRecordingGranted: Bool = false

    static let shared = AudioPermissionManager()
    private init() {}

    func checkPermissions() {
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermission() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        // After request, the user must re-grant in System Settings.
        // We observe NSApplication.didBecomeActiveNotification to re-check.
    }

    func startObservingPermissionChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
        checkPermissions()
    }
}
