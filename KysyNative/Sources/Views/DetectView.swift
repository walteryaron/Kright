import SwiftUI

struct DetectView: View {
    @EnvironmentObject var inspector: FieldInspector

    var body: some View {
        VStack(spacing: 0) {
            header
            languageBar
            Divider()
            content
        }
        // Polling is started/stopped by AppDelegate on panel show/hide — not via
        // onAppear, which fires while the panel is still hidden and would poll AX
        // (expensive cross-process work) continuously in the background.
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope").foregroundColor(.blue).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text("Text Detection").font(.system(size: 13, weight: .semibold))
                Text(inspector.field?.appName != nil
                     ? "Focused app: \(inspector.field!.appName!)" : "Live inspector")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.47))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.07))
    }

    // MARK: Language bar

    private var languageBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe").font(.system(size: 12)).foregroundColor(Color(white: 0.4))
                Text("SYSTEM LANGUAGES")
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                Text(inspector.forced ? "Forced" : "Force lang")
                    .font(.system(size: 11))
                    .foregroundColor(inspector.forced ? .yellow : Color(white: 0.47))
                Toggle("", isOn: Binding(
                    get: { inspector.forced },
                    set: { inspector.toggleForce($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .frame(width: 38)
                    .disabled(inspector.languages.count < 2)
            }
            if inspector.languages.isEmpty {
                Text("No input sources found.")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.4))
            } else {
                FlowChips(sources: inspector.languages) { inspector.selectLanguage($0) }
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.06))
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if let f = inspector.field {
            if !f.trusted {
                PermissionCard()
            } else if !f.hasElement {
                centerNote("No field detected.\n\nClick into a text field in any app.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        LayoutFixCard(text: f.value,
                                      busy: inspector.busy,
                                      result: inspector.replaceResult) {
                            inspector.replace(with: $0)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("ALL PARAMETERS")
                            ForEach(f.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                ParamRow(name: k, value: v)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("TEXT FIELD DETECTION")
                            GuessCard(field: f)
                        }
                    }
                    .padding(16)
                }
            }
        } else {
            centerNote("Reading…")
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 10, weight: .bold)).tracking(1.2)
            .foregroundColor(Color(white: 0.4))
    }

    private func centerNote(_ t: String) -> some View {
        Text(t).multilineTextAlignment(.center).font(.system(size: 12))
            .foregroundColor(Color(white: 0.47)).padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Language chips

struct FlowChips: View {
    let sources: [InputSource]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(sources) { s in
                Button { onTap(s.id) } label: {
                    HStack(spacing: 5) {
                        if s.isCurrent { Image(systemName: "checkmark").font(.system(size: 10)) }
                        Text(s.name.isEmpty ? s.lang : s.name).font(.system(size: 11))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundColor(s.isCurrent ? .blue : Color(white: 0.8))
                    .background(s.isCurrent ? Color.blue.opacity(0.18) : Color(white: 0.1))
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(s.isCurrent ? Color.blue : Color(white: 0.16)))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Lightweight wrapping layout (chips flow onto new rows as needed). Replaces
/// LazyVGrid, which loops/misbehaves outside a ScrollView.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Wrong-layout fix

struct LayoutFixCard: View {
    let text: String
    let busy: Bool
    let result: String?
    let onReplace: (String) -> Void

    var body: some View {
        let suggestion = LayoutConverter.suggest(text)
        let hasFix = suggestion?.isMeaningful ?? false

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard.badge.ellipsis").font(.system(size: 14))
                    .foregroundColor(hasFix ? .yellow : Color(white: 0.4))
                Text("WRONG-LAYOUT FIX").font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundColor(Color(white: 0.53))
            }
            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Type ≥3 letters in a field to see a suggestion.")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.4))
            } else if !hasFix, let s = suggestion {
                kv("Typed", s.original)
            } else if !hasFix {
                kv("Typed", text)
            } else if let s = suggestion {
                kv("Typed", s.original)
                Text("\(s.fromLayout) → \(s.toLayout)").font(.system(size: 10))
                    .foregroundColor(Color(white: 0.53))
                Text(s.converted).font(.system(size: 18, weight: .bold)).foregroundColor(.yellow)
                gibberishVerdict(s)
                Button { onReplace(s.fullReplacement) } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().controlSize(.small) }
                        else { Image(systemName: "wand.and.stars") }
                        Text("Replace in field")
                    }
                }
                .disabled(busy)
            }
            if let result {
                Text(result).font(.system(size: 11))
                    .foregroundColor(result.hasPrefix("Replaced") ? .green : .red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.086))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(hasFix ? Color.yellow.opacity(0.5) : Color(white: 0.15)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func gibberishVerdict(_ s: LayoutSuggestion) -> some View {
        if !GibberishDetector.shared.ready {
            Text("Analyzing… (building language model)")
                .font(.system(size: 11)).foregroundColor(Color(white: 0.45))
        } else {
            let v = GibberishDetector.shared.looksWrongLayout(typed: s.original, converted: s.converted)
            Text(v.wrong
                 ? "🧠 Likely wrong layout — \(Int(v.confidence * 100))% confident"
                 : "🧠 Looks intentional — probably not a layout mistake")
                .font(.system(size: 11))
                .foregroundColor(v.wrong ? .green : Color(white: 0.55))
        }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.system(size: 11)).foregroundColor(Color(white: 0.47)).frame(width: 50, alignment: .leading)
            Text(v.truncatedForDisplay).font(.system(size: 13)).foregroundColor(Color(white: 0.87))
                .textSelection(.enabled).lineLimit(4).truncationMode(.tail)
        }
    }
}

// MARK: - Parameter row

struct ParamRow: View {
    let name: String
    let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(name).font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.54, green: 0.7, blue: 0.97))
                .frame(width: 150, alignment: .leading)
            Text(value.isEmpty ? "—" : value.truncatedForDisplay).font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.87)).textSelection(.enabled)
                .lineLimit(6).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension String {
    /// Large AX values (e.g. a whole document's text) can be thousands of chars,
    /// which makes CoreText typeset forever. Cap what we render.
    var truncatedForDisplay: String {
        count > 300 ? String(prefix(300)) + "… (\(count) chars)" : self
    }
}

// MARK: - Guess card

struct GuessCard: View {
    let field: FocusedField
    var body: some View {
        let g = field.guess
        let color: Color = g.confidence >= 0.7 ? .green : g.confidence >= 0.4 ? .yellow : Color(white: 0.53)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(color).font(.system(size: 14))
                Text(g.label).font(.system(size: 16, weight: .bold)).foregroundColor(color)
                Text("~\(Int(g.confidence * 100))%").font(.system(size: 12))
                    .foregroundColor(color.opacity(0.8))
            }
            Text("Basis: \(g.basis)").font(.system(size: 11)).foregroundColor(Color(white: 0.53))
            Text("Role \(field.role ?? "?")\(field.subrole != nil ? " · \(field.subrole!)" : "")")
                .font(.system(size: 11)).foregroundColor(Color(white: 0.53))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.086))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.15)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Permission card

struct PermissionCard: View {
    @EnvironmentObject var inspector: FieldInspector
    @State private var hint: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield").font(.system(size: 40)).foregroundColor(.orange)
            Text("Accessibility permission needed").font(.system(size: 15, weight: .bold))
            Text("Kysy reads the focused field through macOS Accessibility. macOS won’t grant this automatically — you flip the switch yourself, just once.")
                .multilineTextAlignment(.center).font(.system(size: 12))
                .foregroundColor(Color(white: 0.6)).padding(.horizontal, 28)
            Button {
                inspector.requestAccess()
                hint = "Prompt shown. If you didn’t see it, use “Open Settings”."
            } label: { Label("1. Request access", systemImage: "bell.badge") }
            Button { inspector.openSettings() } label: {
                Label("2. Open Accessibility settings", systemImage: "gearshape")
            }
            Text("Enable Kysy under Accessibility. This updates automatically once granted.")
                .multilineTextAlignment(.center).font(.system(size: 11))
                .foregroundColor(Color(white: 0.4)).padding(.horizontal, 28)
            if let hint { Text(hint).font(.system(size: 11)).foregroundColor(.green) }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
