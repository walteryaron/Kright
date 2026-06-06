import SwiftUI
import AppKit

/// Shared routing state so the right-click "Settings" item can switch the panel
/// to the Settings tab.
final class PanelState: ObservableObject {
    @Published var tab: AppTab = .detect
}

/// Owns the status-bar item, the floating panel, and the long-lived managers.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let keyboard = KeyboardMonitor()
    static let inspector = FieldInspector()
    static let panel = PanelState()
    static let enforcer = FocusLanguageEnforcer()

    private var statusItem: NSStatusItem!
    private var panelWindow: NSPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.keyboard.start()
        Self.enforcer.startIfEnabled()
        HotkeyManager.shared.onTrigger = { Self.fixFocusedLayout() }
        setupPanelWindow()
        setupStatusItem()
    }

    /// Convert the focused field's last word from the wrong layout and replace it
    /// in place — triggered by the global hotkey, no panel needed.
    static func fixFocusedLayout() {
        // Use the exact characters the user just typed (tracked by the keyboard
        // monitor), NOT the field's AX value — terminals expose their whole
        // buffer as the value, which made us delete far too much.
        let typed = keyboard.currentWord
        guard let s = LayoutConverter.suggest(typed), s.isMeaningful else {
            NSSound.beep()
            return
        }

        // Editable fields: a clean AX write that swaps the word inside the value.
        if let (element, value) = AXInspector.focusedValue(),
           let range = value.range(of: typed, options: .backwards) {
            let full = value.replacingCharacters(in: range, with: s.converted)
            if AXInspector.setValue(full, on: element).ok {
                keyboard.resetWord(to: s.converted)
                return
            }
        }

        // Read-only AX (Terminal / iTerm / consoles) → simulate keystrokes.
        // We know the exact length to delete from the typed buffer.
        let deleteCount = typed.count
        let replacement = s.converted
        DispatchQueue.global(qos: .userInitiated).async {
            KeystrokeReplacer.replaceLastWord(originalLength: deleteCount, replacement: replacement)
        }
        keyboard.resetWord(to: s.converted)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Kysy")
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return togglePanel() }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: "Quit Kysy", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)

        // Temporarily attach the menu so a click pops it, then detach so the
        // next left-click still toggles the panel instead of opening the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        Self.panel.tab = .settings
        showPanel()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Floating panel

    private func setupPanelWindow() {
        // Use NSHostingView directly (not NSHostingController) as the panel's
        // contentView. The controller continuously drives the window's auto-layout
        // from SwiftUI's content size, which spins in a constraint/relayout loop.
        // A plain hosting view with sizingOptions=[] and a fixed-size panel fully
        // decouples window size from content — SwiftUI just fills the fixed bounds.
        let hostingView = NSHostingView(
            rootView: ContentView()
                .environmentObject(Self.keyboard)
                .environmentObject(Self.inspector)
                .environmentObject(Self.panel)
                .environmentObject(Self.enforcer)
                .environmentObject(HotkeyManager.shared))
        hostingView.sizingOptions = []

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 680),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hostingView
        panelWindow = panel
    }

    private func togglePanel() {
        if panelWindow.isVisible {
            panelWindow.orderOut(nil)
            Self.inspector.stopPolling()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        positionPanelUnderStatusItem()
        panelWindow.orderFront(nil)
        Self.inspector.startPolling()
    }

    private func positionPanelUnderStatusItem() {
        guard let buttonWindow = statusItem.button?.window else { return }
        let itemFrame = buttonWindow.frame
        var x = itemFrame.midX - panelWindow.frame.width / 2
        let y = itemFrame.minY - 4
        if let screen = buttonWindow.screen {
            let maxX = screen.visibleFrame.maxX - panelWindow.frame.width - 8
            x = min(max(screen.visibleFrame.minX + 8, x), maxX)
        }
        panelWindow.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }
}

@main
struct KysyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // No visible scene — the UI lives in the status-item panel above.
        Settings { EmptyView() }
    }
}
