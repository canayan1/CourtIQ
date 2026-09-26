import SwiftUI

/// Shown when a `/c/<payload>` link reached the app but could not be turned
/// into a challenge.
///
/// This exists because the alternative was nothing at all: the decode was
/// wrapped in `try?`, so a friend's link opened the app on Home and the person
/// who tapped it was left to guess whether they had done something wrong. The
/// three failures have genuinely different fixes — one is a stale build, one is
/// a newer build, one is a broken link — so they get three different sentences
/// rather than one shrug.
struct ChallengeUnreadableView: View {
    let reason: ChallengeCodec.DecodeError

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(AppPalette.inkSoft)
                Text(lang.t(titleKey))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t(bodyKey))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppPalette.cream)
            .navigationTitle(lang.t("challenge.title"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("ChallengeUnreadable")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("common.done")) { dismiss() }
                        .foregroundStyle(AppPalette.clay)
                }
            }
        }
    }

    private var icon: String {
        switch reason {
        case .unsupportedVersion: return "arrow.down.circle"
        case .questionMissing:    return "questionmark.circle"
        case .malformed:          return "link.badge.plus"
        }
    }

    private var titleKey: String {
        switch reason {
        case .unsupportedVersion: return "challenge.unreadable_newer_title"
        case .questionMissing:    return "challenge.unreadable_missing_title"
        case .malformed:          return "challenge.unreadable_broken_title"
        }
    }

    private var bodyKey: String {
        switch reason {
        case .unsupportedVersion: return "challenge.unreadable_newer_body"
        case .questionMissing:    return "challenge.unreadable_missing_body"
        case .malformed:          return "challenge.unreadable_broken_body"
        }
    }
}
