import SwiftUI
import AppKit
import Combine

/// Shared routing state so the right-click "Settings" item can switch the panel
/// to the Settings tab.
final class PanelState: ObservableObject {
    @Published var tab: AppTab = .settings
}

/// Always-on watcher that flips Kright into "blind mode" while a password (secure)
/// field is focused: the menu-bar icon becomes a slashed eye and keystroke
/// capture is paused, so it's visibly clear Kright isn't reading the password.
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
    static var isDisabled = UserDefaults.standard.bool(forKey: "kright_disabled")

    private var statusItem: NSStatusItem!
    private var settingsPopover: NSPopover?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Under unit tests the app is only a host for pure-logic tests — don't
        // start the event tap, timers, status item, or onboarding.
        if NSClassFromString("XCTestCase") != nil { return }

        Self.keyboard.start()
        if !Self.isDisabled { Self.enforcer.startIfEnabled() }
        HotkeyManager.shared.onTrigger = { Self.fixFocusedLayout() }
        // Auto-fix mode: when a word boundary is typed, convert it if it's
        // wrong-layout (gated by the detector). Off unless enabled in Settings.
        Self.keyboard.onWordCompleted = { word in
            DispatchQueue.main.async { Self.autoFixWord(word) }
        }
        setupStatusItem()

        // Blind mode: pause capture and show a slashed-eye icon on password fields.
        Self.privacy.onChange = { [weak self] sensitive in
            Self.keyboard.paused = sensitive
            if sensitive { Self.keyboard.resetWord() }
            self?.refreshStatusIcon()
        }
        Self.privacy.start()

        // First run: until Accessibility is granted, show an onboarding panel
        // that explains why and opens the settings pane in one click.
        showOnboardingIfNeeded()
    }

    /// Shows the first-run Accessibility panel when not yet trusted, and closes
    /// it automatically once the user grants access.
    private func showOnboardingIfNeeded() {
        guard !Self.keyboard.trusted else { return }

        let hosting = NSHostingView(rootView: OnboardingView(onGrant: {
            // The system prompt registers the app AND has its own "Open System
            // Settings" button — so we show only this (don't also open the pane,
            // which produced two overlapping windows).
            Self.keyboard.requestAccess()
        }))
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
                           styleMask: [.titled, .closable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        // Normal level (not floating) so it tucks behind System Settings when the
        // user opens the Accessibility list — it still auto-closes once granted.
        win.level = .normal
        win.contentView = hosting
        win.center()
        onboardingWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)

        // Auto-dismiss the moment access is granted.
        Self.keyboard.$trusted
            .receive(on: RunLoop.main)
            .sink { [weak self] trusted in
                if trusted { self?.onboardingWindow?.close(); self?.onboardingWindow = nil }
            }
            .store(in: &cancellables)
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
                switchKeyboard(to: s)
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
                switchKeyboard(to: s)
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
        switchKeyboard(to: s)
    }

    /// After a fix, switch the keyboard to the corrected text's language so the
    /// user keeps typing in the right layout instead of producing more gibberish.
    private static func switchKeyboard(to s: LayoutSuggestion) {
        guard let id = s.toLayoutID else { return }
        KeyboardLanguage.select(id: id)
    }

    /// Auto-fix mode: a word boundary (space/tab) was just typed. If `word` looks
    /// like wrong-layout gibberish (the on-device bigram detector confirms the
    /// typed form isn't a real word in its script but the converted form is a real
    /// word in the other), convert it in place — the trailing space stays — and
    /// switch the keyboard so the next word is typed correctly. Opt-in, off by
    /// default. The hotkey path is unchanged.
    static func autoFixWord(_ word: String) {
        guard UserDefaults.standard.bool(forKey: "auto_fix") else { return }
        guard !isDisabled, !privacy.sensitive, word.count >= 2 else { return }
        guard let s = LayoutConverter.suggest(word), s.isMeaningful else { return }
        guard GibberishDetector.shared.looksWrongLayout(
                typed: word, converted: s.converted, fromLang: s.fromLang, toLang: s.toLang).wrong
        else { return }

        // Editable field: swap the just-typed word in the value (space untouched).
        if let (element, value) = AXInspector.focusedValue(),
           let range = value.range(of: word, options: .backwards) {
            let full = value.replacingCharacters(in: range, with: s.converted)
            if AXInspector.setValue(full, on: element).ok {
                keyboard.resetWord(); switchKeyboard(to: s); return
            }
        }
        // Read-only field (terminal/console): delete the word + its trailing
        // space and retype the conversion, then switch layout.
        let replacement = s.converted + " "
        let deleteCount = word.count + 1
        DispatchQueue.global(qos: .userInitiated).async {
            KeystrokeReplacer.replaceLastWord(originalLength: deleteCount, replacement: replacement)
        }
        keyboard.resetWord(); switchKeyboard(to: s)
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
            name = "pause.circle"; tip = "Kright is disabled — click to enable"
        } else if Self.privacy.sensitive {
            name = "eye.slash"; tip = "Blind mode — Kright isn't reading this password field"
        } else {
            name = "keyboard"; tip = "Kright"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: tip)
        image?.isTemplate = true
        button.image = image
        button.toolTip = tip
    }

    /// Either mouse button opens the menu; "Settings" then shows the panel.
    @objc private func handleClick() {
        showMenu()
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: Self.isDisabled ? "Enable Kright" : "Disable Kright",
                                action: #selector(toggleActive), keyEquivalent: "")
        toggle.target = self
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: "Quit Kright", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)

        // Temporarily attach the menu so the click pops it, then detach so a
        // later click still routes through handleClick.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleActive() {
        Self.isDisabled.toggle()
        UserDefaults.standard.set(Self.isDisabled, forKey: "kright_disabled")
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
        showSettingsPopover()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Settings popover

    /// Compact size for the Settings-only popover, and the larger size used when
    /// Debug mode adds the Key Log tab.
    private static let settingsSize = NSSize(width: 360, height: 670)
    private static let debugSize = NSSize(width: 460, height: 680)

    /// Shows Settings as a popover anchored to the menu-bar icon (with an arrow
    /// pointing at it). It sticks to the menu and dismisses when you click away —
    /// not a draggable floating window.
    private func showSettingsPopover() {
        guard let button = statusItem.button else { return }
        let debug = UserDefaults.standard.bool(forKey: "debug_mode")
        let size = debug ? Self.debugSize : Self.settingsSize

        settingsPopover?.performClose(nil)
        let host = NSHostingController(
            rootView: ContentView()
                .environmentObject(Self.keyboard)
                .environmentObject(Self.inspector)
                .environmentObject(Self.panel)
                .environmentObject(Self.enforcer)
                .environmentObject(HotkeyManager.shared)
                .frame(width: size.width, height: size.height))
        host.preferredContentSize = size

        let pop = NSPopover()
        pop.contentViewController = host
        pop.behavior = .transient        // dismiss on outside click
        pop.animates = true
        settingsPopover = pop

        NSApp.activate(ignoringOtherApps: true)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

@main
struct KrightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // No visible scene — the UI lives in the status-item panel above.
        Settings { EmptyView() }
    }
}
