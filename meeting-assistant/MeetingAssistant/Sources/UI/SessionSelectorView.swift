import SwiftUI

struct SessionSelectorView: View {
    @EnvironmentObject var coordinator: MeetingCoordinator
    @EnvironmentObject var memoryManager: SessionMemoryManager

    @Binding var selectedScenario: MeetingScenario
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Scenario")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            // Scenario picker
            HStack(spacing: 8) {
                ForEach(MeetingScenario.allCases) { scenario in
                    ScenarioButton(
                        scenario: scenario,
                        isSelected: selectedScenario == scenario
                    ) {
                        selectedScenario = scenario
                    }
                }
            }

            // Related previous sessions
            let related = memoryManager.relatedSessions(for: selectedScenario)
            if !related.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous \(selectedScenario.displayName) sessions")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(related) { session in
                        PanelCard {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.formattedDate)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Text(session.formattedDuration)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                if !session.summary.isEmpty {
                                    Text(session.summary)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            Button(action: onStart) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start \(selectedScenario.displayName)")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(!AppSettings.shared.isConfigured)

            if !AppSettings.shared.isConfigured {
                Text("⚠ Add API keys in Settings first")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
    }
}

private struct ScenarioButton: View {
    let scenario: MeetingScenario
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(scenario.emoji)
                    .font(.system(size: 18))
                Text(scenario.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.cyan : Color.white.opacity(0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
