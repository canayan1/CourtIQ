import SwiftUI

// MARK: - Domain types

/// The stroke the user is filming. Sent to the edge function as a lowercase
/// rawValue ("forehand" | "backhand" | "serve" | "volley").
enum SwingStroke: String, CaseIterable, Identifiable {
    case forehand, backhand, serve, volley
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .forehand: return "figure.tennis"
        case .backhand: return "figure.tennis"
        case .serve:    return "arrow.up.circle"
        case .volley:   return "hand.raised"
        }
    }
}

/// Optional handedness hint. Sent as "right" | "left".
enum SwingHandedness: String, CaseIterable, Identifiable {
    case right, left
    var id: String { rawValue }
}

// MARK: - Consent gate

/// Records the user's explicit consent to send still frames from their swing
/// video to the third-party AI service (Anthropic) that powers Swing Analysis.
/// Required before ANY frame leaves the device — App Store guidelines
/// 5.1.1(i) (data collection) and 5.1.2(i) (data use / third-party sharing).
enum SwingAnalysisConsent {
    /// Bump if the disclosure materially changes (forces re-consent).
    static let currentVersion = 1
    static let key = "DropVolley.swingAnalysis.consent.version"

    static var isAccepted: Bool {
        UserDefaults.standard.integer(forKey: key) >= currentVersion
    }
    static func recordAcceptance() {
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}

/// Gate that swaps the consent disclosure for `content` once consent is
/// recorded. The `@AppStorage` re-renders the moment consent lands.
struct SwingAnalysisGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @AppStorage(SwingAnalysisConsent.key) private var consentVersion: Int = 0

    var body: some View {
        if consentVersion >= SwingAnalysisConsent.currentVersion {
            content()
        } else {
            SwingAnalysisConsentView()
        }
    }
}

/// One-time disclosure + explicit opt-in before Swing Analysis sends any
/// frame to Anthropic. Plain-language: what is sent, who it goes to, that the
/// video itself is not stored, and a clear choice. Nothing is sent until the
/// user taps agree.
struct SwingAnalysisConsentView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    /// Called after consent is recorded — lets a presenter continue the flow
    /// (e.g. kick off the pending analysis). Optional.
    var onAccepted: (() -> Void)? = nil

    private func t(_ en: String, _ tr: String) -> String { lang.language == .turkish ? tr : en }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 64, height: 64)
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(AppPalette.clay)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

                Text(t("Before you start", "Başlamadan önce"))
                    .font(.title2.bold()).foregroundStyle(AppPalette.ink)

                Text(t("Swing Analysis is powered by Claude, an AI service from Anthropic, PBC — a third-party company based in the United States.",
                       "Vuruş Analizi, Anthropic, PBC'nin (Amerika Birleşik Devletleri merkezli üçüncü taraf bir şirket) yapay zeka servisi Claude tarafından çalışır."))
                    .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text(t("Here's exactly what happens:", "Tam olarak şunlar olur:"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    bullet(t("A few still frames are extracted from your video on this device.",
                             "Videondan bu cihazda birkaç sabit kare çıkarılır."))
                    bullet(t("Only those still frames are sent to Anthropic (Claude), in the US, to generate your analysis.",
                             "Yalnızca o sabit kareler, analizini üretmek için ABD'deki Anthropic'e (Claude) gönderilir."))
                    bullet(t("Your video itself is never uploaded or stored on our servers.",
                             "Videonun kendisi sunucularımıza asla yüklenmez veya orada saklanmaz."))
                    bullet(t("Nothing is sent until you tap “I understand and agree”.",
                             "“Anladım ve onaylıyorum”a dokunana kadar hiçbir şey gönderilmez."))
                }
                .padding(14)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(t("Anthropic processes the frames only to generate your coaching notes. They are not used for ads or third-party tracking. You can stop using Swing Analysis at any time.",
                       "Anthropic kareleri yalnızca koçluk notlarını üretmek için işler. Reklam ya da üçüncü taraf takibi için kullanılmaz. Vuruş Analizi'ni istediğin zaman kullanmayı bırakabilirsin."))
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
                        SwingAnalysisConsent.recordAcceptance()   // gate re-renders
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
        .navigationTitle(t("Swing Analysis", "Vuruş Analizi"))
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
