import SwiftUI

/// Explains the match-log section: the three ways to log a match, what
/// each is for, and — crucially — what the user *gets back* (trends + an
/// AI Coach that remembers their whole history). Shown automatically on
/// first visit to the Matches tab, and re-openable any time via the (i)
/// button in the navigation bar.
///
/// Kept deliberately scannable: one card per logging mode + one "what you
/// get" payoff card. No walls of text — the match-log UI is otherwise
/// near-wordless, so this is the one place we explain the *why*.
struct MatchLogTutorialView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro

                    modeCard(
                        icon: "checkmark.seal.fill",
                        tint: AppPalette.moss,
                        title: lang.t("matches.tutorial.played_title"),
                        body: lang.t("matches.tutorial.played_body")
                    )
                    modeCard(
                        icon: "calendar.badge.clock",
                        tint: AppPalette.clay,
                        title: lang.t("matches.tutorial.upcoming_title"),
                        body: lang.t("matches.tutorial.upcoming_body")
                    )
                    payoffCard
                }
                .padding()
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("matches.tutorial.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("common.done")) {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(AppPalette.clay)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("matches.tutorial.intro_title"))
                .appFont(22, weight: .heavy)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lang.t("matches.tutorial.intro_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func modeCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(16, weight: .bold)
                    .foregroundStyle(AppPalette.ink)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var payoffCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("matches.tutorial.payoff_title"))
                    .appFont(16, weight: .bold)
                    .foregroundStyle(AppPalette.ink)
            }
            Text(lang.t("matches.tutorial.payoff_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppPalette.clay.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.clay.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
