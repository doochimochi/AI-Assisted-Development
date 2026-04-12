import SwiftUI

/// Animated dot indicating capture / processing state.
struct StatusIndicator: View {
    let isActive: Bool

    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.gray)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.3 : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { pulse = isActive }
            .onChange(of: isActive) { pulse = $0 }
    }
}
