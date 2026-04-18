import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject var store: TranscriptStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.segments) { segment in
                        VStack(alignment: .leading, spacing: 2) {
                            // Original text
                            HStack(spacing: 4) {
                                if segment.isKorean {
                                    Text("🇰🇷").font(.system(size: 10))
                                }
                                Text(segment.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(segment.isPartial ? .white.opacity(0.45) : .white.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            // English translation (if available)
                            if let translation = segment.translatedText {
                                HStack(spacing: 4) {
                                    Text("🇺🇸").font(.system(size: 10))
                                    Text(translation)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.95))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .id(segment.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: store.segments.count) { _, _ in
                if let last = store.segments.last {
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
