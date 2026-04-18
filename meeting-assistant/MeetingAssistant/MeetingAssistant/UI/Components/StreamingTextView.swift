import SwiftUI

/// Renders text that arrives token-by-token.
/// Updates are throttled to every 50 ms to avoid per-token SwiftUI re-renders.
struct StreamingTextView: View {
    let text: String
    var placeholder: String = "Waiting…"

    var body: some View {
        if text.isEmpty {
            Text(placeholder)
                .foregroundStyle(.secondary)
                .italic()
        } else {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
