import SwiftUI

struct AnswerFinderPanel: View {
    @EnvironmentObject var finder: AnswerFinder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if finder.entries.isEmpty {
                Text("When someone asks a question, answers will appear here")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                ForEach(finder.entries.prefix(3)) { entry in
                    AnswerCard(entry: entry)
                }
            }
        }
    }
}

private struct AnswerCard: View {
    let entry: AnswerEntry

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("Q: \(entry.question)")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    Spacer()
                    CopyButton(text: entry.answer)
                }
                StreamingTextView(
                    text: entry.answer.isEmpty ? "Thinking..." : entry.answer,
                    isStreaming: entry.isStreaming,
                    font: .system(size: 13),
                    color: .white
                )
            }
        }
    }
}
