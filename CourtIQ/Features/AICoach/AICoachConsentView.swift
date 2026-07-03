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

/// The Coach's front door: SELLS the tennis-specific coach first (honest
/// claims only — purpose-built system, real coaching frameworks, reads YOUR
/// game), with the third-party disclosure compressed to one visible line +
/// an expandable itemized list ON this screen, before the consent tap
/// (5.1.1(i) / 5.1.2(i) substance intact — the "agree" button is still the
/// explicit opt-in that gates any data leaving the device).
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

                Text(t("A coach built for tennis — and for your game",
                       "Tenis için — ve senin oyunun için — kurulmuş bir koç"))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    infoRow(icon: "figure.tennis",
                            text: t("Purpose-built for tennis: grounded in club-level coaching frameworks — NTRP-style levels, real match patterns, percentage play.",
                                    "Tenise özel kurulum: kulüp seviyesi koçluk çerçevelerine dayalı — NTRP tarzı seviyeler, gerçek maç desenleri, yüzde oyunu."))
                    infoRow(icon: "person.text.rectangle",
                            text: t("Coaches YOU, not a generic player — it reads your Tennis Profile, match journal, and quiz patterns before every reply.",
                                    "Jenerik bir oyuncuyu değil SENİ çalıştırır — her yanıttan önce Tenis Profilini, maç günlüğünü ve quiz desenlerini okur."))
                    infoRow(icon: "bubble.left.and.text.bubble.right.fill",
                            text: t("On call anytime: match plans, opponent reads, weak-spot fixes, drills for your next session.",
                                    "Her an hazır: maç planları, rakip okumaları, zayıf nokta çözümleri, sonraki antrenman için driller."))
                }
                .padding(16)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Compact disclosure — the compliance substance in one line,
                // itemized list one tap away (still pre-consent, same screen).
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption).foregroundStyle(AppPalette.inkSoft).padding(.top, 2)
                    Text(t("Private & secure: your messages and tennis context are processed by Anthropic's Claude solely to write the Coach's replies — never for ads or tracking.",
                           "Gizli ve güvenli: mesajların ve tenis bağlamın, yalnızca Koç'un yanıtlarını üretmek için Anthropic'in Claude servisince işlenir — asla reklam ya da takip için kullanılmaz."))
                        .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                        Text(t("Agree & start coaching", "Onayla ve koçluğa başla"))
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
