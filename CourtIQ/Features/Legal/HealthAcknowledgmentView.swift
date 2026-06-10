import SwiftUI

/// One-time health & safety acknowledgment shown after onboarding (or at
/// first launch for existing accounts). Blocks access to the app until the
/// user explicitly accepts the assumption-of-risk language.
///
/// The acceptance is persisted in UserDefaults with a timestamp so we can
/// prove (in a dispute) when the user agreed and on which app version.
struct HealthAcknowledgmentView: View {
    /// Called once the user taps "I understand and agree". Caller is
    /// responsible for advancing the navigation.
    var onAccept: () -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var didConfirmReading = false

    private let configuration = AppConfiguration.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    bulletList(items: [
                        lang.t("health.bullet_not_medical"),
                        lang.t("health.bullet_consult_doctor"),
                        lang.t("health.bullet_stop_if_pain"),
                        lang.t("health.bullet_assume_risk"),
                        lang.t("health.bullet_self_directed")
                    ])
                    legalLinks
                    confirmToggle
                }
                .padding(24)
            }

            bottomCTA
        }
        .background(AppPalette.cream)
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("health.eyebrow"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(AppPalette.clay)
            }

            Text(lang.t("health.title"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)

            Text(lang.t("health.subtitle"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletList(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.clay)
                        .frame(width: 20)
                        .padding(.top, 2)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var legalLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("health.read_more"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)

            if let url = configuration.privacyPolicyURL.flatMap({ _ in
                URL(string: "https://canayan-ios-apps.vercel.app/apps/dropvolley/health-disclaimer")
            }) {
                Link(destination: url) {
                    Label(lang.t("health.full_disclaimer_link"), systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                }
            } else {
                NavigationLink {
                    LegalDocumentView(document: .terms)
                } label: {
                    Label(lang.t("health.full_disclaimer_link"), systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                }
            }

            NavigationLink {
                LegalDocumentView(document: .terms)
            } label: {
                Label(lang.t("paywall.terms"), systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
            }
        }
    }

    private var confirmToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: didConfirmReading ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(didConfirmReading ? AppPalette.moss : AppPalette.clay)
                Text(didConfirmReading
                     ? lang.t("health.confirm_done_hint")
                     : lang.t("health.confirm_required_hint"))
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .foregroundStyle(didConfirmReading ? AppPalette.moss : AppPalette.clay)
            }

            Toggle(isOn: $didConfirmReading) {
                Text(lang.t("health.confirm_toggle"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tint(AppPalette.clay)
        }
        .padding(18)
        .background(
            didConfirmReading
            ? AppPalette.moss.opacity(0.08)
            : AppPalette.clay.opacity(0.08)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    didConfirmReading
                    ? AppPalette.moss.opacity(0.4)
                    : AppPalette.clay.opacity(0.45),
                    lineWidth: 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            Button(action: accept) {
                Text(lang.t("health.accept"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(didConfirmReading ? AppPalette.clay : AppPalette.inkSoft.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!didConfirmReading)
            .padding(.horizontal, 22)

            Text(lang.t("health.footer_note"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
        .padding(.top, 14)
        .background(.thinMaterial)
    }

    private func accept() {
        HealthAcknowledgment.recordAcceptance()
        Haptics.tap()
        onAccept()
    }
}

/// Persistence helper for the health acknowledgment. Stored separately from
/// onboarding so we can re-prompt if the disclaimer version changes (e.g.
/// after a material update to the assumption-of-risk language).
enum HealthAcknowledgment {
    /// Bump this any time the disclaimer language changes materially.
    /// Bumping forces every existing user to re-accept on next launch.
    static let currentVersion = 1

    private static let versionKey = "CourtIQ.healthAck.version"
    private static let timestampKey = "CourtIQ.healthAck.timestamp"
    private static let appVersionKey = "CourtIQ.healthAck.appVersion"

    static var isAccepted: Bool {
        UserDefaults.standard.integer(forKey: versionKey) >= currentVersion
    }

    static func recordAcceptance() {
        let d = UserDefaults.standard
        d.set(currentVersion, forKey: versionKey)
        d.set(Date().timeIntervalSince1970, forKey: timestampKey)
        let app = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        d.set("\(app) (\(build))", forKey: appVersionKey)
    }

    /// Returns the recorded acceptance details for audit / support.
    static func acceptanceRecord() -> (version: Int, timestamp: Date?, appVersion: String?)? {
        guard isAccepted else { return nil }
        let d = UserDefaults.standard
        let v = d.integer(forKey: versionKey)
        let ts = d.double(forKey: timestampKey)
        let date = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        let app = d.string(forKey: appVersionKey)
        return (v, date, app)
    }
}
