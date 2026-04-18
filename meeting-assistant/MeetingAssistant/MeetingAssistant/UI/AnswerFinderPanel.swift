import SwiftUI

/// Panel showing AI-generated answers to detected questions.
struct AnswerFinderPanel: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Answers", systemImage: "lightbulb")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if coordinator.answerFinder.entries.isEmpty {
                Text("When someone asks a question, the answer appears here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(coordinator.answerFinder.entries.prefix(2)) { entry in
                    PanelCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.question)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            StreamingTextView(text: entry.answer, placeholder: "Finding answer…")
                                .font(.caption)

                            if !entry.answer.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(entry.answer, forType: .string)
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
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
    }
}
