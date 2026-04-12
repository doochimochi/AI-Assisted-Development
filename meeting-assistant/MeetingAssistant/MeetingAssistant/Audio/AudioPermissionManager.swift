import Foundation
import ScreenSaver    // CGPreflightScreenCaptureAccess lives in CoreGraphics
import CoreGraphics

/// Checks and requests Screen Recording permission required by ScreenCaptureKit.
@MainActor
final class AudioPermissionManager: ObservableObject {

    @Published private(set) var isGranted: Bool = false

    func checkAndRequest() async {
        isGranted = CGPreflightScreenCaptureAccess()
        guard !isGranted else { return }

        // Opens System Settings > Privacy & Security > Screen Recording
        CGRequestScreenCaptureAccess()

        // Poll until the user grants or 30 s passes
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if CGPreflightScreenCaptureAccess() {
                isGranted = true
                return
            }
        }
    }
}
