import SwiftUI

struct SessionSelectorView: View {
    @EnvironmentObject var coordinator: MeetingCoordinator
    @EnvironmentObject var memoryManager: SessionMemoryManager
    @EnvironmentObject var settings: AppSettings
    @ObservedObject private var permissions = AudioPermissionManager.shared

    @Binding var selectedScenario: MeetingScenario
    let onStart: () -> Void

    private var blockers: [String] {
        var list: [String] = []
        if settings.anthropicApiKey.isEmpty    { list.append("Anthropic API key") }
        if settings.googleSpeechApiKey.isEmpty { list.append("Google Speech API key") }
        if !permissions.screenRecordingGranted { list.append("Screen Recording permission") }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            // Blockers — shown prominently if anything is missing
            if !blockers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(blockers, id: \.self) { blocker in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("Missing: \(blocker)")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    }

                    if !permissions.screenRecordingGranted {
                        Button {
                            permissions.requestScreenRecordingPermission()
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                            )
                        } label: {
                            Text("Open Screen Recording Settings →")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.yellow.opacity(0.25), lineWidth: 0.5)
                )
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

            let canStart = blockers.isEmpty
            Button(action: onStart) {
                HStack {
                    Image(systemName: canStart ? "mic.fill" : "lock.fill")
                    Text("Start \(selectedScenario.displayName)")
                }
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(canStart ? Color.green.opacity(0.85) : Color.gray.opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(canStart ? .black : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canStart)
        }
        .padding(12)
        .onAppear { permissions.checkPermissions() }
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
