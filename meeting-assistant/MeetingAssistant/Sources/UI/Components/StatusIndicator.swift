import SwiftUI

struct StatusIndicator: View {
    let isActive: Bool
    let audioLevel: Float

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                        .onDisappear { pulse = false }
                }
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
            }

            if isActive {
                AudioLevelBar(level: CGFloat(audioLevel))
                    .frame(width: 40, height: 8)
            }
        }
    }
}

private struct AudioLevelBar: View {
    let level: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(levelColor)
                    .frame(width: geo.size.width * min(level, 1.0))
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
    }

    private var levelColor: Color {
        if level > 0.8 { return .red }
        if level > 0.5 { return .yellow }
        return .green
    }
}
