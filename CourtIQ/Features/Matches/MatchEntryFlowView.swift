import SwiftUI

/// New-match coordinator. Step 0 asks whether the match is already played
/// or coming up, then routes into the matching flow:
///
/// - **Upcoming**: opponent, surface, date/time, plan. Optional "have AI
///   comment on my plan". Saves as `.upcoming` and schedules an "add your
///   result" reminder ~3h after the match.
/// - **Played**: "did you have a plan?" → result (required) + score +
///   ratings + post-match notes. On save → compound AI analysis → store
///   `aiReport`, save as `.completed`.
///
/// Editing an existing entry, and completing an upcoming match, are handled
/// by `MatchDetailView` / `MatchAddResultView`; this view is for brand-new
/// entries only.
struct MatchEntryFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    /// Optional date to pre-fill the new entry's date picker with (e.g. a
    /// day tapped in the calendar). Default nil keeps existing call sites
    /// working and falls back to "now".
    var initialDate: Date? = nil

    private enum Step {
        case choose
        case upcoming
        case played
    }

    @State private var step: Step = .choose

    var body: some View {
        Group {
            switch step {
            case .choose:
                chooseStep
            case .upcoming:
                MatchUpcomingFormView(initialDate: initialDate, onDone: { dismiss() })
            case .played:
                MatchPlayedFormView(initialDate: initialDate, onDone: { dismiss() })
            }
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("matches.journal_title_new"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if step == .choose {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang.t("common.cancel")) { dismiss() }
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
        }
    }

    // MARK: - Step 0: choose kind

    private var chooseStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                Image(systemName: "figure.tennis")
                    .appFont(40, weight: .medium, design: .default)
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("matches.flow_choose_title"))
                    .appFont(22, weight: .heavy)
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                choiceCard(
                    icon: "checkmark.seal.fill",
                    tint: AppPalette.moss,
                    title: lang.t("matches.flow_played"),
                    subtitle: lang.t("matches.flow_played_sub")
                ) { step = .played }

                choiceCard(
                    icon: "calendar.badge.clock",
                    tint: AppPalette.clay,
                    title: lang.t("matches.flow_upcoming"),
                    subtitle: lang.t("matches.flow_upcoming_sub")
                ) { step = .upcoming }
            }

            Spacer()
        }
        .padding(22)
    }

    private func choiceCard(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.14)).frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .appFont(20, weight: .bold, design: .default)
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .appFont(17, weight: .bold)
                        .foregroundStyle(AppPalette.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
