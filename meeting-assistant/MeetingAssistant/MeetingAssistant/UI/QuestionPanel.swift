import SwiftUI

/// Panel showing suggested questions the user can ask.
struct QuestionPanel: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Ask Next", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    coordinator.questionGenerator.generateOnce(scenario: coordinator.scenario)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.isRunning)
            }

            if coordinator.questionGenerator.suggestions.isEmpty {
                Text("Suggested questions appear here during the meeting")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(coordinator.questionGenerator.suggestions) { suggestion in
                    PanelCard {
                        HStack(alignment: .top) {
                            Text(suggestion.text)
                                .font(.caption)
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(suggestion.text, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
