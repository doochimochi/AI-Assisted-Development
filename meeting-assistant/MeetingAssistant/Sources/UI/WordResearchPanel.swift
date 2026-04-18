import SwiftUI

struct WordResearchPanel: View {
    @EnvironmentObject var researcher: WordResearcher

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if researcher.entries.isEmpty {
                Text("Technical terms will appear here automatically")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            } else {
                ForEach(researcher.entries.prefix(5)) { entry in
                    WordEntryCard(entry: entry)
                }
            }
        }
    }
}

private struct WordEntryCard: View {
    let entry: WordEntry

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.term)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                    Spacer()
                    CopyButton(text: "\(entry.term): \(entry.definition)")
                }
                StreamingTextView(
                    text: entry.definition.isEmpty ? "Researching..." : entry.definition,
                    isStreaming: entry.isStreaming,
                    font: .system(size: 12),
                    color: .white.opacity(0.85)
                )
            }
        }
    }
}
