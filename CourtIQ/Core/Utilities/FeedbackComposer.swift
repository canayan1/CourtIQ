import SwiftUI
import UIKit

/// Builds a pre-filled mailto: URL for beta feedback.
///
/// Beta testers face the lowest possible friction: tapping the button
/// opens their mail client with the recipient, subject, and a system-info
/// footer already populated. They just type and hit send.
enum FeedbackComposer {
    /// Recipient address. Update before public beta.
    static let recipient = "feedback@courtiq.app"

    /// One entry point for all feedback flows.
    static func openMailComposer() {
        guard let url = mailURL(),
              UIApplication.shared.canOpenURL(url) else {
            // Fallback — copy address to clipboard so user can paste manually.
            UIPasteboard.general.string = recipient
            return
        }
        UIApplication.shared.open(url)
    }

    private static func mailURL() -> URL? {
        let subject = "CourtIQ Beta Feedback"
        let body = """


        ────────────────────────────
        \(diagnosticFooter())
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    private static func diagnosticFooter() -> String {
        let app = appVersionString()
        let build = appBuildString()
        let device = deviceModelIdentifier()
        let ios = UIDevice.current.systemVersion
        let locale = Locale.current.identifier

        return """
        App: CourtIQ \(app) (\(build))
        iOS: \(ios)
        Device: \(device)
        Locale: \(locale)
        """
    }

    private static func appVersionString() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private static func appBuildString() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }
        return identifier
    }
}

/// Reusable button + row used across the app (Profile, error states, etc.)
struct FeedbackButton: View {
    var label: String = "Send beta feedback"
    var systemImage: String = "envelope.fill"

    var body: some View {
        Button {
            FeedbackComposer.openMailComposer()
        } label: {
            Label(label, systemImage: systemImage)
        }
    }
}
