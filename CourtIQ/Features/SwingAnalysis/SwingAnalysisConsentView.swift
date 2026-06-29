import SwiftUI

// MARK: - Domain types

/// The stroke the user is filming. Sent to the edge function as a lowercase
/// rawValue ("forehand" | "backhand" | "serve" | "volley").
enum SwingStroke: String, CaseIterable, Identifiable {
    case forehand, backhand, serve, volley, session, footwork
    var id: String { rawValue }

    /// Footwork is a movement analysis, not a stroke — handled by a separate
    /// prompt server-side and a different filming guide.
    var isFootwork: Bool { self == .footwork }
    /// A mixed clip: the AI identifies each stroke type and reports per stroke.
    var isSession: Bool { self == .session }

    var systemImage: String {
        switch self {
        case .forehand: return "figure.tennis"
        case .backhand: return "figure.tennis"
        case .serve:    return "arrow.up.circle"
        case .volley:   return "hand.raised"
        case .session:  return "rectangle.stack.fill"
        case .footwork: return "figure.run"
        }
    }
}

/// Optional handedness hint. Sent as "right" | "left".
enum SwingHandedness: String, CaseIterable, Identifiable {
    case right, left
    var id: String { rawValue }
}

// MARK: - Third-party AI consent (App Store 5.1.1 / 5.1.2)

/// Declarative description of one AI feature's data-sharing disclosure. Drives
/// the reusable `AIConsentView` and the per-feature opt-in record.
///
/// Every feature below sends data to **Google (Gemini)** via our edge
/// functions. The AI Coach uses Anthropic instead and keeps its own consent
/// screen (`AICoachConsentView`).
struct AIConsentSpec {
    /// UserDefaults version key — stores the accepted version number.
    let key: String
    /// Bump when the disclosure materially changes (forces re-consent).
    let version: Int
    let icon: String
    let navTitleEN: String;  let navTitleTR: String
    /// "<Feature> is powered by Google Gemini …" line.
    let providerEN: String;  let providerTR: String
    /// Plain-language list of exactly what leaves the device (parallel arrays).
    let bulletsEN: [String]; let bulletsTR: [String]
    let footerEN: String;    let footerTR: String
}

/// Records and checks the user's explicit, per-feature consent to share data
/// with the third-party AI service that powers each feature. Required before
/// ANY data leaves the device — App Store guidelines 5.1.1(i) (data
/// collection) and 5.1.2(i) (data use / third-party sharing).
enum AIConsent {
    static func isAccepted(_ spec: AIConsentSpec) -> Bool {
        UserDefaults.standard.integer(forKey: spec.key) >= spec.version
    }
    static func record(_ spec: AIConsentSpec) {
        UserDefaults.standard.set(spec.version, forKey: spec.key)
    }
}

/// Built-in disclosure specs. Defined on the struct so the leading-dot form
/// (`.swing`, `.match`, …) resolves against `AIConsentSpec` at every call site
/// — both as `AIConsentView(spec:)` and as `AIConsent.isAccepted(_:)`.
extension AIConsentSpec {

    /// Swing Analysis — sends the swing VIDEO to Google (Gemini).
    /// Key unchanged from v1 but version bumped to 2: the v1 disclosure named
    /// the wrong provider ("Anthropic") and wrongly said only "still frames"
    /// were sent, so prior acceptances must be re-collected.
    static let swing = AIConsentSpec(
        key: "DropVolley.swingAnalysis.consent.version", version: 2,
        icon: "video.badge.waveform",
        navTitleEN: "Swing Analysis", navTitleTR: "Vuruş Analizi",
        providerEN: "Swing Analysis is powered by Google Gemini, an AI service from Google LLC — a third-party company based in the United States.",
        providerTR: "Vuruş Analizi, Google LLC'nin (Amerika Birleşik Devletleri merkezli üçüncü taraf bir şirket) yapay zeka servisi Google Gemini tarafından çalışır.",
        bulletsEN: [
            "Your swing video is compressed on this device and sent to Google (Gemini), in the US, to generate your analysis.",
            "A short summary of your tennis profile and recent scores goes with it, so the coaching fits your game.",
            "Your video is saved on this device for your history — DropVolley does not store it on our own servers.",
            "Nothing is sent until you tap \u{201C}I understand and agree\u{201D}."
        ],
        bulletsTR: [
            "Vuruş videon bu cihazda sıkıştırılır ve analizini üretmek için ABD'deki Google'a (Gemini) gönderilir.",
            "Yanında tenis profilinin ve son skorlarının kısa bir özeti gider; böylece koçluk senin oyununa göre olur.",
            "Videon geçmişin için bu cihazda saklanır — DropVolley kendi sunucularında saklamaz.",
            "\u{201C}Anladım ve onaylıyorum\u{201D}a dokunana kadar hiçbir şey gönderilmez."
        ],
        footerEN: "Google processes your video only to generate your coaching notes and score. It is not used for ads or third-party tracking. You can stop using Swing Analysis at any time.",
        footerTR: "Google videonu yalnızca koçluk notlarını ve puanını üretmek için işler. Reklam ya da üçüncü taraf takibi için kullanılmaz. Vuruş Analizi'ni istediğin zaman kullanmayı bırakabilirsin."
    )

    /// Match Coaching (pre + compound) — sends the match summary to Google.
    static let match = AIConsentSpec(
        key: "DropVolley.matchAnalysis.consent.version", version: 1,
        icon: "list.clipboard.fill",
        navTitleEN: "Match Coaching", navTitleTR: "Maç Koçluğu",
        providerEN: "Match Coaching is powered by Google Gemini, an AI service from Google LLC — a third-party company based in the United States.",
        providerTR: "Maç Koçluğu, Google LLC'nin (Amerika Birleşik Devletleri merkezli üçüncü taraf bir şirket) yapay zeka servisi Google Gemini tarafından çalışır.",
        bulletsEN: [
            "The match details you enter — opponent, surface, your plan, the result and score, your self-ratings, and your notes.",
            "A short summary of your tennis profile and recent form, so the advice fits your game.",
            "This is sent to Google (Gemini), in the US, to generate your coaching.",
            "Nothing is sent until you tap \u{201C}I understand and agree\u{201D}."
        ],
        bulletsTR: [
            "Girdiğin maç bilgileri — rakip, zemin, planın, sonuç ve skor, öz-değerlendirmelerin ve notların.",
            "Tenis profilinin ve son formunun kısa bir özeti; böylece tavsiye senin oyununa göre olur.",
            "Bunlar, koçluğunu üretmek için ABD'deki Google'a (Gemini) gönderilir.",
            "\u{201C}Anladım ve onaylıyorum\u{201D}a dokunana kadar hiçbir şey gönderilmez."
        ],
        footerEN: "Google processes this only to generate your coaching. It is not used for ads or third-party tracking. You can stop using Match Coaching at any time.",
        footerTR: "Google bunları yalnızca koçluğunu üretmek için işler. Reklam ya da üçüncü taraf takibi için kullanılmaz. Maç Koçluğu'nu istediğin zaman kullanmayı bırakabilirsin."
    )

    /// Pre-Match Mental Check — sends the three ratings + optional note.
    static let mental = AIConsentSpec(
        key: "DropVolley.mentalCheck.consent.version", version: 1,
        icon: "brain.head.profile",
        navTitleEN: "Pre-Match Mental Check", navTitleTR: "Maç Öncesi Zihin Kontrolü",
        providerEN: "The Pre-Match Mental Check is powered by Google Gemini, an AI service from Google LLC — a third-party company based in the United States.",
        providerTR: "Maç Öncesi Zihin Kontrolü, Google LLC'nin (Amerika Birleşik Devletleri merkezli üçüncü taraf bir şirket) yapay zeka servisi Google Gemini tarafından çalışır.",
        bulletsEN: [
            "Your three quick ratings — energy, confidence, and nerves — and the optional note you add.",
            "This is sent to Google (Gemini), in the US, to generate your pre-match routine.",
            "Nothing is sent until you tap \u{201C}I understand and agree\u{201D}."
        ],
        bulletsTR: [
            "Üç hızlı değerlendirmen — enerji, güven ve gerginlik — ve eklediğin isteğe bağlı not.",
            "Bunlar, maç öncesi rutinini üretmek için ABD'deki Google'a (Gemini) gönderilir.",
            "\u{201C}Anladım ve onaylıyorum\u{201D}a dokunana kadar hiçbir şey gönderilmez."
        ],
        footerEN: "Google processes this only to generate your routine. It is not used for ads or third-party tracking. You can stop using the Mental Check at any time.",
        footerTR: "Google bunları yalnızca rutinini üretmek için işler. Reklam ya da üçüncü taraf takibi için kullanılmaz. Zihin Kontrolü'nü istediğin zaman kullanmayı bırakabilirsin."
    )

    /// Doubles Compatibility — sends your profile + the partner mini-profile.
    static let doubles = AIConsentSpec(
        key: "DropVolley.doublesAnalysis.consent.version", version: 1,
        icon: "person.2.fill",
        navTitleEN: "Doubles Compatibility", navTitleTR: "Çiftler Uyumu",
        providerEN: "Doubles Compatibility is powered by Google Gemini, an AI service from Google LLC — a third-party company based in the United States.",
        providerTR: "Çiftler Uyumu, Google LLC'nin (Amerika Birleşik Devletleri merkezli üçüncü taraf bir şirket) yapay zeka servisi Google Gemini tarafından çalışır.",
        bulletsEN: [
            "Your tennis profile — level, style, strengths, and what you're working on.",
            "Your partner's details as entered here — their name, level, and play style.",
            "This is sent to Google (Gemini), in the US, to generate your compatibility report and game plan.",
            "Nothing is sent until you tap \u{201C}I understand and agree\u{201D}."
        ],
        bulletsTR: [
            "Tenis profilin — seviye, stil, güçlü yönler ve üzerinde çalıştıkların.",
            "Burada girdiğin partner bilgileri — adı, seviyesi ve oyun stili.",
            "Bunlar, uyum raporunu ve oyun planını üretmek için ABD'deki Google'a (Gemini) gönderilir.",
            "\u{201C}Anladım ve onaylıyorum\u{201D}a dokunana kadar hiçbir şey gönderilmez."
        ],
        footerEN: "Only add a partner's details with their okay. Google processes this only to generate your report — never for ads or third-party tracking. You can stop using Doubles Compatibility at any time.",
        footerTR: "Partner bilgilerini yalnızca onayıyla ekle. Google bunları yalnızca raporunu üretmek için işler — reklam ya da üçüncü taraf takibi için asla. Çiftler Uyumu'nu istediğin zaman kullanmayı bırakabilirsin."
    )
}

// MARK: - Reusable consent gate view

/// One-time disclosure + explicit opt-in before a feature sends any data to
/// its third-party AI service. Plain-language: what is sent, who it goes to,
/// and a clear choice. Nothing is sent until the user taps agree.
struct AIConsentView: View {
    let spec: AIConsentSpec
    /// Called after consent is recorded — lets a presenter continue the flow
    /// (e.g. kick off the pending analysis). Optional.
    var onAccepted: (() -> Void)? = nil

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private var isTR: Bool { lang.language == .turkish }
    private func t(_ en: String, _ tr: String) -> String { isTR ? tr : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 64, height: 64)
                    Image(systemName: spec.icon)
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(AppPalette.clay)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text(t("Before you start", "Başlamadan önce"))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)

                Text(t(spec.providerEN, spec.providerTR))
                    .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text(t("Here's exactly what happens:", "Tam olarak şunlar olur:"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    ForEach(Array((isTR ? spec.bulletsTR : spec.bulletsEN).enumerated()), id: \.offset) { _, line in
                        bullet(line)
                    }
                }
                .padding(14)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(t(spec.footerEN, spec.footerTR))
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
                        AIConsent.record(spec)   // gate re-renders / caller continues
                        onAccepted?()
                        dismiss()
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
        .navigationTitle(t(spec.navTitleEN, spec.navTitleTR))
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
