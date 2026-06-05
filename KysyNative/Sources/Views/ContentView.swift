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

/// Root panel UI shown from the menu bar: a tab strip over the three views.
struct ContentView: View {
    @EnvironmentObject var panel: PanelState

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch panel.tab {
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
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    panel.tab = t
                } label: {
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: t.icon).font(.system(size: 12))
                            Text(t.rawValue).font(.system(size: 12, weight: panel.tab == t ? .semibold : .regular))
                        }
                        Rectangle()
                            .fill(panel.tab == t ? Color.blue : Color.clear)
                            .frame(height: 2)
                    }
                    .foregroundColor(panel.tab == t ? .blue : Color(white: 0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.07))
    }
}
