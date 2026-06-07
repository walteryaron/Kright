import SwiftUI

enum AppTab: String, CaseIterable {
    case detect = "Detect"
    case keyLog = "Key Log"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .detect: return "scope"
        case .keyLog: return "keyboard"
        case .settings: return "gearshape"
        }
    }
}

/// Root panel UI shown from the menu bar. Normally just Settings; the Key Log
/// tab appears when Debug mode is enabled, so the user can watch exactly what's
/// captured — and see that password fields are never read.
struct ContentView: View {
    @EnvironmentObject var panel: PanelState
    @AppStorage("debug_mode") private var debugMode = false

    /// Debug adds only the Key Log; Settings is always shown. (Detect is a
    /// developer-only view, not surfaced.)
    private var tabs: [AppTab] { debugMode ? [.keyLog, .settings] : [.settings] }
    private var current: AppTab { tabs.contains(panel.tab) ? panel.tab : .settings }

    var body: some View {
        VStack(spacing: 0) {
            if debugMode {
                tabBar
                Divider()
            }
            Group {
                switch current {
                case .detect: DetectView()
                case .keyLog: KeyLogView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        .preferredColorScheme(.dark)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { t in
                Button {
                    panel.tab = t
                } label: {
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: t.icon).font(.system(size: 12))
                            Text(t.rawValue).font(.system(size: 12, weight: current == t ? .semibold : .regular))
                        }
                        Rectangle()
                            .fill(current == t ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundColor(current == t ? .blue : Color(white: 0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.07))
    }
}
