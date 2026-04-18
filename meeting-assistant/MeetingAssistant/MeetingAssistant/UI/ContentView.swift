import SwiftUI

/// Root view of the floating overlay.
/// Layout (top → bottom):
///   Header bar (scenario picker, status, controls)
///   Related session banner (conditional)
///   Tab picker (Words | Answers | Questions)
///   Selected panel
///   Divider
///   Live transcript (always visible)
struct ContentView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()
                .cornerRadius(14)

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                if coordinator.showRelatedSessionBanner, let prev = coordinator.relatedSession {
                    relatedSessionBanner(prev)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                tabPicker
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // AI panels
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case 0: WordResearchPanel()
                        case 1: AnswerFinderPanel()
                        case 2: QuestionPanel()
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }
                .frame(maxHeight: .infinity)

                Divider().padding(.horizontal, 12)

                // Always-visible transcript strip
                TranscriptView()
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 360, minHeight: 480, maxHeight: 700)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - Sub-views

    private var headerBar: some View {
        HStack(spacing: 8) {
            StatusIndicator(isActive: coordinator.isRunning)

            // Scenario picker
            Picker("", selection: $coordinator.scenario) {
                ForEach(MeetingScenario.allCases, id: \.self) { s in
                    Text("\(s.emoji) \(s.displayName)").tag(s)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(.caption)
            .disabled(coordinator.isRunning)

            Spacer()

            // Start / Stop
            Button {
                Task {
                    if coordinator.isRunning {
                        await coordinator.endSession()
                    } else {
                        await coordinator.startSession()
                    }
                }
            } label: {
                Image(systemName: coordinator.isRunning ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title3)
                    .foregroundStyle(coordinator.isRunning ? .red : .green)
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    private func relatedSessionBanner(_ record: SessionRecord) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Related \(record.scenario.displayName) found")
                .font(.caption)
            Spacer()
            Button("Load") { coordinator.loadRelatedSession() }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            Button { coordinator.dismissRelatedSession() } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.15))
        )
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(label: "Terms",   icon: "magnifyingglass", tag: 0)
            tabButton(label: "Answers", icon: "lightbulb",       tag: 1)
            tabButton(label: "Ask",     icon: "bubble.left",     tag: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }

    private func tabButton(label: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tag }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption.weight(selectedTab == tag ? .semibold : .regular))
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                selectedTab == tag
                    ? RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.15))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}
