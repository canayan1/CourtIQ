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

/// Declarative description of one AI feature's front door: SELLS the
/// tennis-specific system first (honest claims only), with the third-party
/// disclosure compressed to one visible line + an expandable itemized list on
/// the same screen — the pattern the AI Coach uses (`AICoachConsentView`).
/// Drives the reusable `AIConsentView` and the per-feature opt-in record.
///
/// Every feature below sends data to **Google (Gemini)** via our edge
/// functions; Gemini stays named in the visible privacy line and the
/// US-processing note stays in the expandable list (5.1.1(i)/5.1.2(i)
/// substance intact — the agree button is still the explicit opt-in that
/// gates any data leaving the device).
struct AIConsentSpec {
    struct Benefit {
        let icon: String
        let en: String
        let tr: String
    }

    /// UserDefaults version key — stores the accepted version number.
    let key: String
    /// Bump when the disclosure materially changes (forces re-consent).
    let version: Int
    let icon: String
    let navTitleEN: String;  let navTitleTR: String
    /// Benefit-led headline — what this feature does for the player.
    let titleEN: String;     let titleTR: String
    /// 2–3 honest selling points (purpose-built framing, no training claims).
    let benefits: [Benefit]
    /// One visible line naming the AI provider and the sole purpose.
    let privacyLineEN: String; let privacyLineTR: String
    /// Itemized "what leaves the device" list, one tap away (parallel arrays).
    let bulletsEN: [String]; let bulletsTR: [String]
    /// Optional short per-feature note ("" hides it).
    let footerEN: String;    let footerTR: String
    /// Agree-button label ("Agree & …").
    let ctaEN: String;       let ctaTR: String
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
    /// were sent, so prior acceptances must be re-collected. (The v3 marketing
    /// re-layout shares the same data + provider, so no further bump.)
    static let swing = AIConsentSpec(
        key: "DropVolley.swingAnalysis.consent.version", version: 2,
        icon: "video.badge.waveform",
        navTitleEN: "Swing Analysis", navTitleTR: "Vuruş Analizi",
        titleEN: "A coach's eye on your swing — frame by frame",
        titleTR: "Vuruşunda bir koç gözü — kare kare",
        benefits: [
            .init(icon: "figure.tennis",
                  en: "Purpose-built for tennis strokes: preparation, contact point, follow-through — checked against club-level coaching checkpoints.",
                  tr: "Tenis vuruşlarına özel kurulum: hazırlık, temas noktası, tamamlama — kulüp seviyesi koçluk kontrol noktalarına göre incelenir."),
            .init(icon: "gauge.with.needle",
                  en: "You get a 0–100 score plus specific fixes, so you know exactly what to drill next.",
                  tr: "0–100 puan + net düzeltmeler alırsın; sırada ne çalışacağını tam olarak bilirsin."),
            .init(icon: "iphone",
                  en: "Your video stays in your history on this device — DropVolley doesn't store it on our servers.",
                  tr: "Videon bu cihazdaki geçmişinde kalır — DropVolley kendi sunucularında saklamaz.")
        ],
        privacyLineEN: "Private & secure: your clip is compressed on-device and processed by Google's Gemini AI solely to score your swing — never for ads or tracking.",
        privacyLineTR: "Gizli ve güvenli: videon cihazda sıkıştırılır ve yalnızca vuruşunu puanlamak için Google'ın Gemini yapay zekasınca işlenir — asla reklam ya da takip için kullanılmaz.",
        bulletsEN: [
            "Your swing video (compressed on this device)",
            "A short summary of your tennis profile and recent scores, so the coaching fits your game"
        ],
        bulletsTR: [
            "Vuruş videon (bu cihazda sıkıştırılır)",
            "Tenis profilinin ve son skorlarının kısa bir özeti; koçluk senin oyununa göre olur"
        ],
        footerEN: "",
        footerTR: "",
        ctaEN: "Agree & analyze my swing",
        ctaTR: "Onayla ve vuruşumu analiz et"
    )

    /// Match Coaching (pre + compound) — sends the match summary to Google.
    static let match = AIConsentSpec(
        key: "DropVolley.matchAnalysis.consent.version", version: 1,
        icon: "list.clipboard.fill",
        navTitleEN: "Match Coaching", navTitleTR: "Maç Koçluğu",
        titleEN: "Match coaching that knows your game",
        titleTR: "Oyununu tanıyan maç koçluğu",
        benefits: [
            .init(icon: "figure.tennis",
                  en: "Purpose-built for tennis matches: it reads the score shape, your self-ratings, and your notes like a coach reviewing your match.",
                  tr: "Tenis maçlarına özel kurulum: skor akışını, öz-değerlendirmelerini ve notlarını maçını izlemiş bir koç gibi okur."),
            .init(icon: "person.text.rectangle",
                  en: "Coaches YOU, not a generic player — your Tennis Profile and recent form shape every insight.",
                  tr: "Jenerik bir oyuncuyu değil SENİ çalıştırır — Tenis Profilin ve son formun her içgörüyü şekillendirir."),
            .init(icon: "list.clipboard.fill",
                  en: "You get what to keep, what to fix, and a plan for the rematch.",
                  tr: "Neyi koruyacağını, neyi düzelteceğini ve rövanş planını alırsın.")
        ],
        privacyLineEN: "Private & secure: your match details are processed by Google's Gemini AI solely to write your coaching — never for ads or tracking.",
        privacyLineTR: "Gizli ve güvenli: maç bilgilerin yalnızca koçluğunu yazmak için Google'ın Gemini yapay zekasınca işlenir — asla reklam ya da takip için kullanılmaz.",
        bulletsEN: [
            "The match details you enter — opponent, surface, your plan, the result and score, your self-ratings, and your notes",
            "A short summary of your tennis profile and recent form, so the advice fits your game"
        ],
        bulletsTR: [
            "Girdiğin maç bilgileri — rakip, zemin, planın, sonuç ve skor, öz-değerlendirmelerin ve notların",
            "Tenis profilinin ve son formunun kısa bir özeti; tavsiye senin oyununa göre olur"
        ],
        footerEN: "",
        footerTR: "",
        ctaEN: "Agree & get my coaching",
        ctaTR: "Onayla ve koçluğu al"
    )

    /// Pre-Match Mental Check — sends the three ratings + optional note.
    static let mental = AIConsentSpec(
        key: "DropVolley.mentalCheck.consent.version", version: 1,
        icon: "brain.head.profile",
        navTitleEN: "Pre-Match Mental Check", navTitleTR: "Maç Öncesi Zihin Kontrolü",
        titleEN: "Walk on court with a clear head",
        titleTR: "Korta net bir kafayla çık",
        benefits: [
            .init(icon: "brain.head.profile",
                  en: "A pre-match routine built from how you actually feel today — your energy, confidence, and nerves.",
                  tr: "Bugün gerçekte nasıl hissettiğinden kurulan bir maç öncesi rutin — enerjin, güvenin ve gerginliğin."),
            .init(icon: "figure.tennis",
                  en: "Grounded in tennis mental-game practice: reset routines, breathing, first-games focus.",
                  tr: "Tenisin mental oyun pratiğine dayalı: sıfırlama rutinleri, nefes, ilk oyunlara odak.")
        ],
        privacyLineEN: "Private & secure: your ratings and note are processed by Google's Gemini AI solely to build your routine — never for ads or tracking.",
        privacyLineTR: "Gizli ve güvenli: değerlendirmelerin ve notun yalnızca rutinini kurmak için Google'ın Gemini yapay zekasınca işlenir — asla reklam ya da takip için kullanılmaz.",
        bulletsEN: [
            "Your three quick ratings — energy, confidence, and nerves",
            "The optional note you add"
        ],
        bulletsTR: [
            "Üç hızlı değerlendirmen — enerji, güven ve gerginlik",
            "Eklediğin isteğe bağlı not"
        ],
        footerEN: "",
        footerTR: "",
        ctaEN: "Agree & build my routine",
        ctaTR: "Onayla ve rutinimi kur"
    )

    /// Doubles Compatibility — sends your profile + the partner mini-profile.
    static let doubles = AIConsentSpec(
        key: "DropVolley.doublesAnalysis.consent.version", version: 1,
        icon: "person.2.fill",
        navTitleEN: "Doubles Compatibility", navTitleTR: "Çiftler Uyumu",
        titleEN: "A doubles read built for tennis — and for you two",
        titleTR: "Tenis için — ve ikiniz için — kurulmuş bir doubles analizi",
        benefits: [
            .init(icon: "figure.tennis",
                  en: "Purpose-built for doubles tennis: court coverage, style complementarity, level fit — grounded in club-level doubles play.",
                  tr: "Doubles tenisine özel kurulum: kort kapsama, stil uyumu, seviye dengesi — kulüp seviyesi doubles oyununa dayalı."),
            .init(icon: "person.2.fill",
                  en: "Reads BOTH games — your Tennis Profile and your partner's: strengths, gaps, and how they interlock.",
                  tr: "İKİ oyunu birden okur — senin Tenis Profilin ve partnerininki: güçlü yönler, açıklar ve birbirini nasıl tamamladıkları."),
            .init(icon: "list.clipboard.fill",
                  en: "You get a 0–100 fit score plus a game plan: who covers what, and the patterns to run together.",
                  tr: "0–100 uyum puanı + oyun planı alırsın: kim neresini kapatır, birlikte hangi desenler oynanır.")
        ],
        privacyLineEN: "Private & secure: both mini-profiles are processed by Google's Gemini AI solely to write your pairing report — never for ads or tracking.",
        privacyLineTR: "Gizli ve güvenli: iki mini profil, yalnızca eşleşme raporunuzu yazmak için Google'ın Gemini yapay zekasınca işlenir — asla reklam ya da takip için kullanılmaz.",
        bulletsEN: [
            "Your tennis profile — level, style, strengths, and what you're working on",
            "Your partner's details — their name, level, and play style"
        ],
        bulletsTR: [
            "Tenis profilin — seviye, stil, güçlü yönler ve üzerinde çalıştıkların",
            "Partner bilgileri — adı, seviyesi ve oyun stili"
        ],
        footerEN: "Only add a partner's details with their okay.",
        footerTR: "Partner bilgilerini yalnızca onayıyla ekle.",
        ctaEN: "Agree & see our fit",
        ctaTR: "Onayla ve uyumu gör"
    )
}

// MARK: - Reusable consent gate view

/// Each AI feature's front door: sells the tennis-specific system first, with
/// the third-party disclosure in one visible line + an expandable itemized
/// list on the same screen (mirrors `AICoachConsentView`). The agree tap is
/// still the explicit opt-in — nothing is sent before it.
struct AIConsentView: View {
    let spec: AIConsentSpec
    /// Called after consent is recorded — lets a presenter continue the flow
    /// (e.g. kick off the pending analysis). Optional.
    var onAccepted: (() -> Void)? = nil

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDetails = false

    private var isTR: Bool { lang.language == .turkish }
    private func t(_ en: String, _ tr: String) -> String { isTR ? tr : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 64, height: 64)
                    Image(systemName: spec.icon)
                        .appFont(28, weight: .bold, design: .default).foregroundStyle(AppPalette.clay)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text(t(spec.titleEN, spec.titleTR))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(spec.benefits.enumerated()), id: \.offset) { _, benefit in
                        infoRow(icon: benefit.icon, text: t(benefit.en, benefit.tr))
                    }
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
                    Text(t(spec.privacyLineEN, spec.privacyLineTR))
                        .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup(isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array((isTR ? spec.bulletsTR : spec.bulletsEN).enumerated()), id: \.offset) { _, line in
                            bullet(line)
                        }
                        bullet(t("Processed on Google's servers in the US, only to generate this feature's results",
                                 "Yalnızca bu özelliğin sonuçlarını üretmek için Google'ın ABD'deki sunucularında işlenir"))
                        bullet(t("Nothing is sent until you tap Agree",
                                 "Onayla'ya dokunana kadar hiçbir şey gönderilmez"))
                    }
                    .padding(.top, 8)
                } label: {
                    Text(t("See exactly what's shared", "Tam olarak ne paylaşılıyor?"))
                        .font(.footnote.weight(.semibold)).foregroundStyle(AppPalette.clay)
                }
                .tint(AppPalette.clay)

                if !spec.footerEN.isEmpty {
                    Text(t(spec.footerEN, spec.footerTR))
                        .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                        Text(t(spec.ctaEN, spec.ctaTR))
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
