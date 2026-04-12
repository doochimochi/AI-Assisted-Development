import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var coordinator: MeetingCoordinator
    @EnvironmentObject var settings: AppSettings

    @State private var selectedTab: Tab = .answer
    @State private var selectedScenario: MeetingScenario = .team
    @State private var showSettings = false
    @State private var dragOffset = CGSize.zero

    enum Tab: String, CaseIterable {
        case answer = "Answer"
        case words = "Terms"
        case questions = "Questions"
        case transcript = "Live"

        var icon: String {
            switch self {
            case .answer:     return "lightbulb.fill"
            case .words:      return "text.magnifyingglass"
            case .questions:  return "questionmark.bubble.fill"
            case .transcript: return "waveform"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Frosted glass background
            VisualEffectBackground()
                .cornerRadius(14)

            VStack(spacing: 0) {
                // --- Header ---
                header
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(Color.white.opacity(0.04))

                if !coordinator.isRunning {
                    // --- Session Selector ---
                    SessionSelectorView(
                        selectedScenario: $selectedScenario
                    ) {
                        Task { await coordinator.startSession(scenario: selectedScenario) }
                    }
                    .environmentObject(coordinator.memoryManager)
                    .environmentObject(settings)
                } else {
                    // --- Error banner ---
                    if let error = coordinator.error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                    }

                    // --- Tab bar ---
                    tabBar
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    // --- Panel content ---
                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            switch selectedTab {
                            case .answer:
                                AnswerFinderPanel()
                                    .environmentObject(coordinator.answerFinder)
                            case .words:
                                WordResearchPanel()
                                    .environmentObject(coordinator.wordResearcher)
                            case .questions:
                                QuestionPanel()
                                    .environmentObject(coordinator.questionGenerator)
                                    .environmentObject(coordinator)
                            case .transcript:
                                TranscriptView()
                                    .environmentObject(coordinator.transcriptStore)
                                    .frame(minHeight: 200)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .frame(width: settings.overlayWidth)
        .background(Color.clear)
        .opacity(settings.overlayOpacity)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .frame(width: 340, height: 420)
                .background(VisualEffectBackground())
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let window = NSApp.keyWindow {
                                let origin = window.frame.origin
                                window.setFrameOrigin(NSPoint(
                                    x: origin.x + value.translation.width,
                                    y: origin.y - value.translation.height
                                ))
                            }
                        }
                )

            // Scenario badge
            if coordinator.isRunning {
                Text(coordinator.scenario.emoji + " " + coordinator.scenario.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Text("Meeting Assistant")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            StatusIndicator(
                isActive: coordinator.isRunning,
                audioLevel: coordinator.audioCapture.audioLevel
            )

            if coordinator.isRunning {
                Button {
                    Task { await coordinator.stopSession() }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(5)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(selectedTab == tab ? Color.cyan.opacity(0.25) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .cyan : .white.opacity(0.5))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - NSVisualEffectView bridge

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// MARK: - Copy button

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10))
                .foregroundColor(copied ? .green : .white.opacity(0.4))
        }
        .buttonStyle(.plain)
    }
}
