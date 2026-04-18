import SwiftUI

/// Live scrolling transcript panel.
struct TranscriptView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(coordinator.transcriptStore.segments.suffix(20)) { segment in
                        Text(segment.text)
                            .font(.system(size: 11))
                            .foregroundStyle(segment.isFinal ? .primary : .secondary)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: coordinator.transcriptStore.segments.count) { _ in
                if let last = coordinator.transcriptStore.segments.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(height: 80)
    }
}
