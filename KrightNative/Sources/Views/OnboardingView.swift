import SwiftUI
import AppKit

/// First-run panel shown on launch until Accessibility is granted. Explains why
/// the permission is needed and opens the right settings pane in one click.
struct OnboardingView: View {
    let onGrant: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 64, height: 64)

            Text("Welcome to Kright").font(.system(size: 18, weight: .bold))
            Text("Keyboard done right.").font(.system(size: 12)).foregroundColor(Color(white: 0.5))

            Text("To fix wrong-layout typing, Kright needs **Accessibility** access — to read the focused text field and type the correction.")
                .font(.system(size: 12)).multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.72))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                row("wifi.slash", "No internet — it never makes a network request.")
                row("externaldrive.badge.xmark", "Nothing stored — your typing is never saved.")
                row("eye.slash.fill", "Password & secure fields are never read.")
            }
            .padding(.vertical, 2)

            Button(action: onGrant) {
                Text("Open Accessibility Settings")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Text("Enable Kright in the list — this window closes automatically once you do.")
                .font(.system(size: 10)).multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 420)
        .background(Color(white: 0.1))
        .preferredColorScheme(.dark)
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.green).frame(width: 14)
            Text(text).font(.system(size: 10.5)).foregroundColor(Color(white: 0.62))
            Spacer(minLength: 0)
        }
    }
}
