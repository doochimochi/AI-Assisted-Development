import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject var store: TranscriptStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(store.segments) { segment in
                        Text(segment.text)
                            .font(.system(size: 12))
                            .foregroundColor(segment.isPartial ? .white.opacity(0.5) : .white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: store.segments.count) { _ in
                if let last = store.segments.last {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
