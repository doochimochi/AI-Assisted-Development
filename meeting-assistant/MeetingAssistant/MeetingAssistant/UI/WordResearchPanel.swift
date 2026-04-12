import SwiftUI

/// Panel displaying the most recent word definitions.
struct WordResearchPanel: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Terms", systemImage: "magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if coordinator.wordResearcher.entries.isEmpty {
                Text("Technical terms will appear here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(coordinator.wordResearcher.entries.prefix(3)) { entry in
                    PanelCard {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.term)
                                    .font(.caption.weight(.bold))
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.definition, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .opacity(entry.definition.isEmpty ? 0 : 1)
                            }
                            StreamingTextView(text: entry.definition, placeholder: "Looking up…")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}
