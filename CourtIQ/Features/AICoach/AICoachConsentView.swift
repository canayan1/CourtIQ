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
/// Anthropic. Plain-language: what is sent, who it goes to, and a clear choice.
struct AICoachConsentView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private func t(_ en: String, _ tr: String) -> String { lang.language == .turkish ? tr : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 64, height: 64)
                    Image(systemName: "sparkles").font(.system(size: 30, weight: .bold)).foregroundStyle(AppPalette.clay)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text(t("Before you start", "Başlamadan önce"))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)

                Text(t("The AI Coach is powered by Claude, an AI service from Anthropic, PBC — a third-party company.",
                       "AI Koç, Anthropic, PBC'nin (üçüncü taraf bir şirket) yapay zeka servisi Claude tarafından çalışır."))
                    .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text(t("To answer you, CourtIQ sends Anthropic:", "Sana yanıt vermek için CourtIQ, Anthropic'e şunları gönderir:"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    bullet(t("The messages you type to the Coach", "Koç'a yazdığın mesajlar"))
                    bullet(t("Your profile (skill level and focus)", "Profilin (seviye ve odak)"))
                    bullet(t("Your Tennis Profile (level, style, and goals)", "Tenis Profilin (seviye, stil ve hedefler)"))
                    bullet(t("Your recent matches, scores, and self-ratings", "Son maçların, skorların ve öz-değerlendirmelerin"))
                    bullet(t("Your quiz mistake patterns", "Quiz hata desenlerin"))
                }
                .padding(14)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(t("Anthropic processes this only to generate the Coach's replies. Your data is stored privately to your account and is never used for ads or third-party tracking. You can stop using the AI Coach at any time.",
                       "Anthropic bunları yalnızca Koç'un yanıtlarını üretmek için işler. Verilerin hesabına özel saklanır; reklam ya da üçüncü taraf takibi için asla kullanılmaz. AI Koç'u istediğin zaman kullanmayı bırakabilirsin."))
                    .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

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
                        dismiss()
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
            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(AppPalette.clay).padding(.top, 6)
            Text(text).font(.subheadline).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
