import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var enforcer: FocusLanguageEnforcer
    @EnvironmentObject var appEnforcer: AppLanguageEnforcer
    @EnvironmentObject var ruleStore: AppLanguageRuleStore
    @EnvironmentObject var hotkey: HotkeyManager
    @AppStorage("debug_mode") private var debugMode = false
    @AppStorage("auto_fix") private var autoFix = false
    @State private var sources: [InputSource] = KeyboardLanguage.enabledSources()
    @State private var addSourceID: String = KeyboardLanguage.firstLatin()?.id ?? ""
    @State private var addStatus: String = ""

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

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

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fix-layout shortcut").font(.system(size: 12, weight: .semibold))
                    Text("Press this anywhere to convert the focused field's last word from the wrong keyboard layout — no need to open Kright.")
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

                    Text("Auto-fix as you type").font(.system(size: 12, weight: .semibold))
                    Toggle(isOn: $autoFix) {
                        Text("Convert wrong-layout words automatically on Space / Tab")
                            .font(.system(size: 11)).foregroundColor(Color(white: 0.75))
                    }
                    .toggleStyle(.switch)
                    Text("Hebrew ⇄ English. Each finished word is checked on-device; gibberish is converted and the keyboard switches to match.")
                        .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                        .fixedSize(horizontal: false, vertical: true)

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

                    Text("Per-app keyboard").font(.system(size: 12, weight: .semibold))
                    Toggle(isOn: $appEnforcer.enabled) {
                        Text("Switch keyboard when app gains focus")
                            .font(.system(size: 11)).foregroundColor(Color(white: 0.75))
                    }
                    .toggleStyle(.switch)
                    Text("When you switch to a listed app, Kright immediately changes to its configured layout.")
                        .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                        .fixedSize(horizontal: false, vertical: true)

                    if !ruleStore.rules.isEmpty {
                        VStack(spacing: 2) {
                            ForEach($ruleStore.rules) { $rule in
                                HStack(spacing: 8) {
                                    AppIconView(bundleID: rule.bundleID)
                                    Text(rule.appName)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(white: 0.75))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Picker("", selection: $rule.inputSourceID) {
                                        ForEach(sources, id: \.id) { s in
                                            Text(s.name).tag(s.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 90)
                                    Button {
                                        ruleStore.rules.removeAll { $0.id == rule.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color(white: 0.3))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }

                    HStack(spacing: 8) {
                        Picker("", selection: $addSourceID) {
                            ForEach(sources, id: \.id) { s in
                                Text(s.name).tag(s.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 90)
                        .disabled(sources.isEmpty)
                        Button("+ Add current app") {
                            let layoutName = sources.first { $0.id == addSourceID }?.name ?? addSourceID
                            if let name = ruleStore.addFrontmostApp(
                                inputSourceID: addSourceID, layoutName: layoutName) {
                                addStatus = "Added \(name)"
                            } else {
                                addStatus = "Already added or Kright is frontmost"
                            }
                        }
                        .disabled(sources.isEmpty)
                        Spacer()
                    }
                    if !addStatus.isEmpty {
                        Text(addStatus)
                            .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                    }

                    Divider().padding(.vertical, 4)

                    Text("Developer").font(.system(size: 12, weight: .semibold))
                    Toggle(isOn: $debugMode) {
                        Text("Debug mode — show the Detect and Key Log tabs")
                            .font(.system(size: 11)).foregroundColor(Color(white: 0.75))
                    }
                    .toggleStyle(.switch)

                    Divider().padding(.vertical, 4)

                    Text("Privacy").font(.system(size: 12, weight: .semibold))
                    Text("Kright doesn't collect your data — it all happens on your Mac. Your typing is never stored or sent anywhere, only used to fix the word you just typed.")
                        .font(.system(size: 10.5)).foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    privacyRow("wifi.slash", "No network — it makes zero internet requests, ever.")
                    privacyRow("externaldrive.badge.xmark", "No storage — what you type is never logged or saved to disk.")
                    privacyRow("eye.slash.fill", "Password-safe — it pauses on secure fields, which macOS also hides from every app.")
                    privacyRow("checkmark.seal", "Open source — verify every word of this in the code on GitHub.")

                    Divider().padding(.vertical, 4)

                    Text("About").font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard").foregroundColor(.blue).font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Kright \(appVersion)")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(Color(white: 0.8))
                            Text("Keyboard done right.")
                                .font(.system(size: 10)).foregroundColor(Color(white: 0.45))
                        }
                    }
                    HStack(spacing: 6) {
                        Link(destination: URL(string: "https://github.com/walteryaron/Kright")!) {
                            Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 11))
                        }
                        Spacer()
                        Text("by Yaron Walter").font(.system(size: 10)).foregroundColor(Color(white: 0.4))
                    }
                    .padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Kright", systemImage: "power")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private struct AppIconView: View {
        let bundleID: String
        @State private var icon: NSImage?

        var body: some View {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "app.fill").foregroundColor(Color(white: 0.4))
                }
            }
            .frame(width: 18, height: 18)
            .onAppear { icon = AppLanguageRuleStore.icon(for: bundleID) }
        }
    }

    @ViewBuilder
    private func privacyRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon).font(.system(size: 10))
                .foregroundColor(.green).frame(width: 14)
            Text(text).font(.system(size: 10.5)).foregroundColor(Color(white: 0.62))
            Spacer(minLength: 0)
        }
    }
}
