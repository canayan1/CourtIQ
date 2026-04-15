import SwiftUI

enum LegalDocument: String, CaseIterable, Identifiable {
    case privacy
    case terms
    case support
    case moderation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        case .support: return "Support"
        case .moderation: return "Moderation Policy"
        }
    }

    var bodyText: String {
        switch self {
        case .privacy:
            return """
            CourtIQ stores guest progress locally on device. When Sign in with Apple and remote sync are configured, profile, training logs, quiz completions, and discussion activity may be synced to your account. We do not sell personal data. App Store release should replace this placeholder with your production privacy policy text and public URL.
            """
        case .terms:
            return """
            CourtIQ All Access is an auto-renewing subscription that unlocks premium training programs, mobility flows, archived quiz insights, and community posting. Payment and renewal terms must match your App Store Connect products before release.
            """
        case .support:
            return """
            Support will be handled through your production support inbox or help center. Replace this placeholder with your final support email, response expectations, and troubleshooting steps before submitting to the App Store.
            """
        case .moderation:
            return """
            Community discussion is anchored to CourtIQ content. Players may report comments for review. Offensive, abusive, spammy, or unsafe content should be removed according to your production moderation workflow.
            """
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument
    private let configuration = AppConfiguration.shared

    private var documentURL: URL? {
        switch document {
        case .privacy:
            return configuration.privacyPolicyURL
        case .terms:
            return configuration.termsOfUseURL
        case .support:
            return configuration.supportURL
        case .moderation:
            return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.bodyText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let documentURL {
                    Link(destination: documentURL) {
                        Label("Open Published Document", systemImage: "arrow.up.right.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
