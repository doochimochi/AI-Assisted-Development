import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.15))

            // API Keys
            Group {
                SecureSettingsField(
                    label: "Anthropic API Key",
                    placeholder: "sk-ant-...",
                    value: $settings.anthropicApiKey
                )
                SecureSettingsField(
                    label: "Google Speech API Key",
                    placeholder: "AIza...",
                    value: $settings.googleSpeechApiKey
                )
            }

            Divider().background(Color.white.opacity(0.15))

            // Overlay
            VStack(alignment: .leading, spacing: 8) {
                Text("Overlay Opacity")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                HStack {
                    Slider(value: $settings.overlayOpacity, in: 0.5...1.0)
                        .accentColor(.cyan)
                    Text("\(Int(settings.overlayOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36)
                }
            }

            // Options
            Toggle(isOn: $settings.autoSaveSession) {
                Text("Auto-save sessions")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(.switch)

            Toggle(isOn: $settings.useCloudSTT) {
                Text("Cloud STT (Google Speech) — recommended")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .toggleStyle(.switch)

            Spacer()

            Button {
                settings.save()
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.cyan.opacity(0.8))
                    .cornerRadius(7)
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.clear)
    }
}

private struct SecureSettingsField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            HStack {
                if isRevealed {
                    TextField(placeholder, text: $value)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                } else {
                    SecureField(placeholder, text: $value)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                }
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(5)
        }
    }
}
