import SwiftUI

enum LegalDocument: String, CaseIterable, Identifiable {
    case privacy
    case terms
    case support
    case moderation

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .privacy: return "legal.privacy"
        case .terms: return "legal.terms"
        case .support: return "legal.support"
        case .moderation: return "legal.moderation"
        }
    }

    var bodyKey: String {
        switch self {
        case .privacy: return "legal.privacy_body"
        case .terms: return "legal.terms_body"
        case .support: return "legal.support_body"
        case .moderation: return "legal.moderation_body"
        }
    }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        case .support: return "Support"
        case .moderation: return "Moderation Policy"
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument
    @EnvironmentObject private var lang: LanguageManager
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
                Text(lang.t(document.bodyKey))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let documentURL {
                    Link(destination: documentURL) {
                        Label(lang.t("legal.open_doc"), systemImage: "arrow.up.right.square")
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
        .navigationTitle(lang.t(document.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}
