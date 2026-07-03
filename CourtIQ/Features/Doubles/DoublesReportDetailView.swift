import SwiftUI

/// The two sides of a linked pairing, for the side-by-side profile cards.
/// `you` comes from the local Tennis Profile; `partner` from the partnership
/// row's shared snapshot.
struct DoublesPairProfiles {
    let you: DoublesProfile?
    let partner: DoublesProfile
}

/// A single saved compatibility report: the score (prominently), the linked
/// pair's profile cards (when available), the date, and the analysis text.
/// Reuses `DoublesScoreView` + `SwingReportText`.
struct DoublesReportDetailView: View {
    @EnvironmentObject private var lang: LanguageManager

    let report: DoublesReport
    /// Present only for LINKED partnerships (both sides shared a profile);
    /// nil keeps the manual-partner report unchanged.
    var pair: DoublesPairProfiles? = nil

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let score = report.score {
                        DoublesScoreView(score: score, copy: copy)
                            .frame(maxWidth: .infinity)
                    }

                    if let pair {
                        DoublesPairProfilesView(pair: pair, copy: copy, lang: lang.language)
                    }

                    Text(copy.relativeDate(report.date))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)

                    SwingReportText(text: report.reportText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
            }
        }
        .navigationTitle(copy.reportTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Side-by-side pair profile cards

/// "You | Partner" mini profile cards: level, style, strengths, growth areas —
/// the mutual view both players unlocked by pairing.
struct DoublesPairProfilesView: View {
    let pair: DoublesPairProfiles
    let copy: DoublesCopy
    let lang: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(copy.pairSectionTitle)
            HStack(alignment: .top, spacing: 10) {
                if let you = pair.you {
                    profileCard(you, title: copy.youLabel, accentBorder: true)
                }
                profileCard(pair.partner, title: pair.partner.name, accentBorder: false)
            }
        }
    }

    private func profileCard(_ profile: DoublesProfile, title: String, accentBorder: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.clay)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)
            }

            if let level = profile.levelTitle(lang: lang) {
                Text(level)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let style = profile.styleTitle(lang: lang) {
                Text(style)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !profile.strengths.isEmpty {
                labeledLine(icon: "bolt.fill", text: profile.strengths)
            }
            if !profile.weaknesses.isEmpty {
                labeledLine(icon: "leaf.fill", text: profile.weaknesses)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accentBorder ? AppPalette.clay.opacity(0.45) : AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func labeledLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
