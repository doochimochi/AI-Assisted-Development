import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var anthropicKey = AppSettings.shared.anthropicAPIKey
    @State private var deepgramKey  = AppSettings.shared.deepgramAPIKey

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { saveAndDismiss() }
                    .keyboardShortcut(.return)
            }

            GroupBox("API Keys") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Anthropic") {
                        SecureField("sk-ant-…", text: $anthropicKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Deepgram") {
                        SecureField("token…", text: $deepgramKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Display") {
                HStack {
                    Text("Overlay opacity")
                    Slider(value: $settings.overlayOpacity, in: 0.4...1.0, step: 0.05)
                    Text("\(Int(settings.overlayOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }

            GroupBox("Speech-to-Text") {
                Toggle("Use offline STT (WhisperKit — requires ~1.5 GB download)", isOn: $settings.useOfflineSTT)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .frame(width: 380, height: 320)
    }

    private func saveAndDismiss() {
        AppSettings.shared.anthropicAPIKey = anthropicKey
        AppSettings.shared.deepgramAPIKey  = deepgramKey
        dismiss()
    }
}
