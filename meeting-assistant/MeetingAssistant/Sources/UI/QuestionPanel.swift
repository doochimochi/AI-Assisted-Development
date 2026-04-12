import SwiftUI

struct QuestionPanel: View {
    @EnvironmentObject var generator: QuestionGenerator
    @EnvironmentObject var coordinator: MeetingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Suggested Questions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button {
                    Task {
                        let transcript = coordinator.transcriptStore.recentText()
                        await generator.generate(
                            transcript: transcript,
                            scenario: coordinator.scenario,
                            previousContext: coordinator.previousContext
                        )
                    }
                } label: {
                    Image(systemName: generator.isGenerating ? "arrow.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(generator.isGenerating ? .degrees(360) : .zero)
                        .animation(generator.isGenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: generator.isGenerating)
                }
                .buttonStyle(.plain)
                .disabled(generator.isGenerating || !coordinator.isRunning)
            }

            if generator.suggestions.isEmpty && !generator.isGenerating {
                Text("Questions will be suggested after ~30s of conversation")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            } else {
                ForEach(generator.suggestions) { suggestion in
                    QuestionCard(suggestion: suggestion) {
                        generator.markCopied(id: suggestion.id)
                    }
                }
            }
        }
    }
}

private struct QuestionCard: View {
    let suggestion: QuestionSuggestion
    let onCopy: () -> Void

    var body: some View {
        PanelCard {
            HStack(alignment: .top, spacing: 8) {
                Text(suggestion.text)
                    .font(.system(size: 13))
                    .foregroundColor(suggestion.isCopied ? .white.opacity(0.4) : .white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(suggestion.text, forType: .string)
                    onCopy()
                } label: {
                    Image(systemName: suggestion.isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(suggestion.isCopied ? .green : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
