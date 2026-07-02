import SwiftUI

/// Records the user's explicit consent to share their tennis context + chat
/// messages with the third-party AI service (Anthropic) that powers the AI
/// Coach. Required before ANY message is sent — App Store guidelines
/// 5.1.1(i) (data collection) and 5.1.2(i) (data use / third-party sharing).
enum AICoachConsent {
    /// Bump if the disclosure materially changes (forces re-consent).
    static let currentVersion = 1
    private static let key = "CourtIQ.aiCoach.consent.version"

    static var isAccepted: Bool {
        UserDefaults.standard.integer(forKey: key) >= currentVersion
    }
    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}

/// Gate shown when the AI Coach opens: the consent disclosure until the user
/// agrees, then the chat. The `@AppStorage` re-renders the moment consent is
/// recorded, swapping the disclosure for the chat.
struct AICoachGate: View {
    @AppStorage("CourtIQ.aiCoach.consent.version") private var consentVersion: Int = 0

    var body: some View {
        if consentVersion >= AICoachConsent.currentVersion {
            AICoachView()
        } else {
            AICoachConsentView()
        }
    }
}

/// One-time disclosure + explicit opt-in before the AI Coach sends any data to
/// Anthropic. Three scannable icon rows carry the substance (who powers it,
/// what is sent, how it's used) so the screen reads in seconds; the itemized
/// data list stays one tap away in an expandable "exactly what's shared"
/// section — still ON this screen, before consent (5.1.1(i) / 5.1.2(i)).
struct AICoachConsentView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var showDetails = false

    private func t(_ en: String, _ tr: String) -> String { lang.language == .turkish ? tr : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 64, height: 64)
                    Image(systemName: "sparkles").appFont(30, weight: .bold, design: .default).foregroundStyle(AppPalette.clay)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text(t("Before you start", "Başlamadan önce"))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)

                VStack(alignment: .leading, spacing: 14) {
                    infoRow(icon: "sparkles",
                            text: t("The Coach is powered by Claude — an AI service from Anthropic, a third-party company.",
                                    "Koç, üçüncü taraf bir şirket olan Anthropic'in yapay zeka servisi Claude ile çalışır."))
                    infoRow(icon: "paperplane.fill",
                            text: t("Your messages and tennis context (profile, recent matches, quiz patterns) are sent to Anthropic to write the replies.",
                                    "Mesajların ve tenis bağlamın (profil, son maçlar, quiz desenleri) yanıtları üretmesi için Anthropic'e gönderilir."))
                    infoRow(icon: "lock.fill",
                            text: t("Used only for replies — stored privately, never for ads or tracking. Stop anytime.",
                                    "Yalnızca yanıtlar için kullanılır — hesabına özel saklanır, asla reklam/takip için kullanılmaz. İstediğin an bırakabilirsin."))
                }
                .padding(16)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                DisclosureGroup(isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        bullet(t("The messages you type to the Coach", "Koç'a yazdığın mesajlar"))
                        bullet(t("Your profile (skill level and focus)", "Profilin (seviye ve odak)"))
                        bullet(t("Your Tennis Profile (level, style, and goals)", "Tenis Profilin (seviye, stil ve hedefler)"))
                        bullet(t("Your recent matches, scores, and self-ratings", "Son maçların, skorların ve öz-değerlendirmelerin"))
                        bullet(t("Your quiz mistake patterns", "Quiz hata desenlerin"))
                    }
                    .padding(.top, 8)
                } label: {
                    Text(t("See exactly what's shared", "Tam olarak ne paylaşılıyor?"))
                        .font(.footnote.weight(.semibold)).foregroundStyle(AppPalette.clay)
                }
                .tint(AppPalette.clay)

                if let url = AppConfiguration.shared.privacyPolicyURL {
                    Link(destination: url) {
                        Text(t("Read the Privacy Policy", "Gizlilik Politikasını oku"))
                            .font(.footnote.weight(.semibold)).foregroundStyle(AppPalette.clay)
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        AICoachConsent.recordAcceptance()   // gate re-renders → chat
                    } label: {
                        Text(t("I understand and agree", "Anladım ve onaylıyorum"))
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent).tint(AppPalette.clay)

                    Button {
                        // This consent screen IS the Coach tab's root content
                        // (not a sheet), so dismiss() is a no-op here — send the
                        // user back to Home instead of a dead button.
                        tabRouter.selection = .home
                    } label: {
                        Text(t("Not now", "Şimdi değil"))
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered).tint(AppPalette.inkSoft)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(t("AI Coach", "AI Koç"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill").appFont(6, design: .default).foregroundStyle(AppPalette.clay).padding(.top, 6)
            Text(text).font(.subheadline).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .appFont(16, weight: .semibold, design: .default)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 24)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
