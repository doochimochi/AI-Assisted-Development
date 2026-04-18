import SwiftUI

// Renders text that arrives token-by-token with a blinking cursor while streaming
struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool
    var font: Font = .system(size: 13)
    var color: Color = .primary

    @State private var showCursor = true
    private let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
            if isStreaming {
                Text(showCursor ? "▋" : " ")
                    .font(font)
                    .foregroundColor(color.opacity(0.7))
                    .onReceive(cursorTimer) { _ in showCursor.toggle() }
            }
        }
    }
}
