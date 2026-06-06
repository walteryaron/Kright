import SwiftUI
import AppKit

/// Shared routing state so the right-click "Settings" item can switch the panel
/// to the Settings tab.
final class PanelState: ObservableObject {
    @Published var tab: AppTab = .settings
}

/// Always-on watcher that flips Kysy into "blind mode" while a password (secure)
/// field is focused: the menu-bar icon becomes a slashed eye and keystroke
/// capture is paused, so it's visibly clear Kysy isn't reading the password.
final class PrivacyMonitor {
    private(set) var sensitive = false

    /// Called on the main thread whenever `sensitive` flips.
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private let ownPid = getpid()

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard AXIsProcessTrusted() else { return }
        // A focused secure field reports the "Password" guess (AXSecureTextField).
        let s = AXInspector.focusedFieldLight(ignoring: ownPid)?.guess.label == "Password"
        if s != sensitive {
            sensitive = s
            onChange?(s)
        }
    }
}

/// Owns the status-bar item, the floating panel, and the long-lived managers.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let keyboard = KeyboardMonitor()
    static let inspector = FieldInspector()
    static let panel = PanelState()
    static let enforcer = FocusLanguageEnforcer()
    static let privacy = PrivacyMonitor()

    /// Master on/off switch (right-click menu). While disabled, the fix hotkey is
    /// inert and the auto-language enforcer is paused — handy for A/B demos.
    static var isDisabled = UserDefaults.standard.bool(forKey: "kysy_disabled")

    private var statusItem: NSStatusItem!
    private var panelWindow: NSPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.keyboard.start()
        if !Self.isDisabled { Self.enforcer.startIfEnabled() }
        HotkeyManager.shared.onTrigger = { Self.fixFocusedLayout() }
        setupPanelWindow()
        setupStatusItem()

        // Blind mode: pause capture and show a slashed-eye icon on password fields.
        Self.privacy.onChange = { [weak self] sensitive in
            Self.keyboard.paused = sensitive
            if sensitive { Self.keyboard.resetWord() }
            self?.refreshStatusIcon()
        }
        Self.privacy.start()
    }

    /// Convert the focused field's just-typed phrase from the wrong layout and
    /// replace it in place — triggered by the global hotkey, no panel needed.
    /// Handles a whole multi-word run ("nrhu dktexh"), not only the last word.
    static func fixFocusedLayout() {
        // Master switch off → do nothing (for recording the before/after).
        if isDisabled { NSSound.beep(); return }
        // Blind mode: never read or touch a password field.
        if privacy.sensitive { NSSound.beep(); return }

        // Single-token fields (email / URL / username): the keystroke buffer
        // breaks on '@' and '.', so it can't represent the whole value — that's
        // why an email only converted the part after '@'. Convert the field's
        // actual value instead. The layout map round-trips the real characters,
        // so '@' and '.' stay correct. Skipped for fields with spaces (handled by
        // the phrase path below) and long buffers (suggestPhrase caps length).
        if let (element, value) = AXInspector.focusedValue() {
            let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty, !token.contains(where: { $0.isWhitespace }),
               let s = LayoutConverter.suggestPhrase(token), s.isMeaningful,
               AXInspector.setValue(s.converted, on: element).ok {
                keyboard.resetWord(to: s.converted)
                return
            }
        }

        // Use the exact characters the user just typed (tracked by the keyboard
        // monitor), NOT the field's AX value — terminals expose their whole
        // buffer as the value, which made us delete far too much.
        let typed = keyboard.currentPhrase
        guard let s = LayoutConverter.suggestPhrase(typed), s.isMeaningful else {
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
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refreshStatusIcon()
    }

    /// Picks the menu-bar glyph from the current state: disabled (paused), blind
    /// mode (password field), or normal.
    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        let name: String, tip: String
        if Self.isDisabled {
            name = "pause.circle"; tip = "Kysy is disabled — right-click to enable"
        } else if Self.privacy.sensitive {
            name = "eye.slash"; tip = "Blind mode — Kysy isn't reading this password field"
        } else {
            name = "keyboard"; tip = "Kysy"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: tip)
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
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
        let toggle = NSMenuItem(title: Self.isDisabled ? "Enable Kysy" : "Disable Kysy",
                                action: #selector(toggleActive), keyEquivalent: "")
        toggle.target = self
        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: "Quit Kysy", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)

        // Temporarily attach the menu so a click pops it, then detach so the
        // next left-click still toggles the panel instead of opening the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleActive() {
        Self.isDisabled.toggle()
        UserDefaults.standard.set(Self.isDisabled, forKey: "kysy_disabled")
        if Self.isDisabled {
            Self.enforcer.stop()
            Self.keyboard.resetWord()
        } else {
            Self.enforcer.startIfEnabled()
        }
        refreshStatusIcon()
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
