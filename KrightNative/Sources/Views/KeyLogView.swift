import SwiftUI

struct KeyLogView: View {
    @EnvironmentObject var keyboard: KeyboardMonitor

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard").foregroundColor(.blue).font(.system(size: 14))
                Text("Key Log").font(.system(size: 13, weight: .semibold))
                Spacer()
                if keyboard.trusted {
                    Text("\(keyboard.events.count) events")
                        .font(.system(size: 11)).foregroundColor(Color(white: 0.47))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.07))
            Divider()

            if !keyboard.trusted {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "lock.shield").font(.system(size: 36)).foregroundColor(.orange)
                    Text("Accessibility permission needed to log keys.")
                        .multilineTextAlignment(.center).font(.system(size: 12))
                        .foregroundColor(Color(white: 0.6))
                    Button { keyboard.requestAccess() } label: {
                        Label("Request access", systemImage: "bell.badge")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
            } else if keyboard.events.isEmpty {
                VStack { Spacer()
                    Text("Start typing anywhere…").font(.system(size: 12))
                        .foregroundColor(Color(white: 0.47))
                    Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(keyboard.events) { ev in
                            HStack {
                                Image(systemName: ev.isDown ? "arrow.down" : "arrow.up")
                                    .font(.system(size: 10))
                                    .foregroundColor(ev.isDown ? .green : Color(white: 0.4))
                                Text("keyCode \(ev.keyCode)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(white: 0.85))
                                if !ev.modifierString.isEmpty {
                                    Text(ev.modifierString).font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 5)
                        }
                    }
                }
            }
        }
    }
}
