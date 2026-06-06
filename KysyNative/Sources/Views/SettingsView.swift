import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var enforcer: FocusLanguageEnforcer
    @EnvironmentObject var hotkey: HotkeyManager
    @AppStorage("debug_mode") private var debugMode = false
    @State private var key: String = GeminiService.apiKey
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape").foregroundColor(.blue).font(.system(size: 14))
                Text("Settings").font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.07))
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Fix-layout shortcut").font(.system(size: 12, weight: .semibold))
                Text("Press this anywhere to convert the focused field's last word from the wrong keyboard layout — no need to open Kysy.")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.5))
                HStack {
                    Text(hotkey.recording ? "Press keys…" : hotkey.displayString)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(hotkey.recording ? .yellow : .white)
                        .frame(minWidth: 70, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Button(hotkey.recording ? "Cancel" : "Change…") {
                        hotkey.recording ? hotkey.stopRecording() : hotkey.startRecording()
                    }
                    Spacer()
                }

                Divider().padding(.vertical, 4)

                Text("Auto keyboard language").font(.system(size: 12, weight: .semibold))
                Toggle(isOn: $enforcer.enabled) {
                    Text("Switch to English on email / URL / password fields")
                        .font(.system(size: 11)).foregroundColor(Color(white: 0.75))
                }
                .toggleStyle(.switch)
                if let action = enforcer.lastAction {
                    Text(action).font(.system(size: 10)).foregroundColor(.green)
                }

                Divider().padding(.vertical, 4)

                Text("Gemini API Key").font(.system(size: 12, weight: .semibold))
                Text("Stored locally on this Mac. Get a free key at aistudio.google.com/apikey.")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.5))
                SecureField("AIza…", text: $key)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        GeminiService.apiKey = key
                        status = GeminiService.isReady ? "Saved ✓" : "Cleared"
                    } label: { Text("Save") }
                    if let status {
                        Text(status).font(.system(size: 11))
                            .foregroundColor(status.hasPrefix("Saved") ? .green : Color(white: 0.5))
                    }
                    Spacer()
                }
                Divider().padding(.vertical, 4)

                Text("Developer").font(.system(size: 12, weight: .semibold))
                Toggle(isOn: $debugMode) {
                    Text("Debug mode — show the Detect and Key Log tabs")
                        .font(.system(size: 11)).foregroundColor(Color(white: 0.75))
                }
                .toggleStyle(.switch)

                Spacer()
                Divider()
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Kysy", systemImage: "power")
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
