import SwiftUI

/// **Tennis Journal** — the app's fourth flagship, alongside swing analysis,
/// the wall and tactics.
///
/// It is one habit, not two: the match log and the fuel log were separate
/// screens that asked the same question a day at a time, so they now share a
/// calendar, a streak and a single open question. Tap any day, past or
/// present, and fill it in — which is the part the user asked for, because a
/// journal you can only write in *today* stops being a journal the first
/// time you forget.
struct JournalView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var matches: MatchEntryManager
    @ObservedObject private var nutrition = NutritionManager.shared

    @State private var selectedDay: Date?
    @State private var ratingEntry: NutritionEntry?
    @State private var newFuelDate: Date?
    @State private var newMatchDate: Date?
    @State private var matchDetail: MatchEntry?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var digest: JournalDigest {
        JournalDigest(matches: matches.entries.filter { !$0.isDraft }, fuel: nutrition.entries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if let prompt = digest.prompt { promptCard(prompt) }
                calendarCard
                quickActions
                destinations
                timeline
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("journal.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation(Motion.entrance) { appeared = true } }
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_JOURNAL=day|daypast|fuel|fuelpast|match.
        .onAppear {
            switch ProcessInfo.processInfo.environment["QC_JOURNAL"] {
            case "day":   selectedDay = Date()
            case "fuel":  newFuelDate = Date()
            case "fuelpast": newFuelDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
            case "daypast": selectedDay = Calendar.current.date(byAdding: .day, value: -3, to: Date())
            case "match": newMatchDate = Date()
            default: break
            }
        }
        #endif
        .sheet(item: Binding(get: { selectedDay.map(IdentifiableDate.init) },
                             set: { selectedDay = $0?.date })) { wrapper in
            JournalDaySheet(date: wrapper.date,
                            onLogFuel: { newFuelDate = $0 },
                            onLogMatch: { newMatchDate = $0 },
                            onRateFuel: { ratingEntry = $0 },
                            onOpenMatch: { matchDetail = $0 })
                .environmentObject(lang)
                .environmentObject(session)
                .environmentObject(matches)
        }
        .sheet(item: Binding(get: { newFuelDate.map(IdentifiableDate.init) },
                             set: { newFuelDate = $0?.date })) { wrapper in
            NutritionLogSheet(date: wrapper.date)
                .environmentObject(lang)
        }
        .sheet(item: Binding(get: { newMatchDate.map(IdentifiableDate.init) },
                             set: { newMatchDate = $0?.date })) { wrapper in
            NavigationStack {
                MatchEntryFlowView(initialDate: wrapper.date)
                    .environmentObject(matches)
                    .environmentObject(lang)
                    .environmentObject(session)
            }
        }
        .sheet(item: $ratingEntry) { entry in
            NutritionRateSheet(entry: entry)
                .environmentObject(lang)
        }
        .navigationDestination(item: $matchDetail) { entry in
            MatchDetailView(entryID: entry.id)
                .environmentObject(matches)
                .environmentObject(lang)
                .environmentObject(session)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("journal.eyebrow"))
            Text(lang.t("journal.headline"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lang.t("journal.intro"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The open question

    /// One card, one question. The journal never stacks three things to
    /// answer — an inbox is the opposite of a habit.
    private func promptCard(_ prompt: JournalPrompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: prompt.symbol)
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t(prompt.titleKey))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(promptBody(prompt))
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: lang.t(prompt.ctaKey), icon: prompt.symbol) {
                switch prompt {
                case .rateFuel(let entry):   ratingEntry = entry
                case .fuelForMatch(let m):   newFuelDate = m.date
                case .rateMatch(let m):      matchDetail = m
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(fill: AppPalette.goldTint.opacity(0.55), stroke: AppPalette.gold.opacity(0.4), cornerRadius: 18)
        .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)
    }

    /// The body names the day it is asking about, so "how did that leave
    /// you?" is never about a session the player can't place.
    private func promptBody(_ prompt: JournalPrompt) -> String {
        let date: Date
        switch prompt {
        case .rateFuel(let e):     date = e.date
        case .fuelForMatch(let m): date = m.date
        case .rateMatch(let m):    date = m.date
        }
        return String(format: lang.t(prompt.bodyKey), relativeDay(date))
    }

    // MARK: Calendar

    private var calendarCard: some View {
        let marks = digest.marks
        let streak = digest.streak
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(lang.t("journal.calendar"))
                Spacer()
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.clay)
                        .accessibilityLabel(String(format: lang.t("journal.streak_days"), streak))
                }
            }
            DayGridCalendar(
                mark: { marks[JournalDay.key($0)] ?? .none },
                accessibility: dayAccessibility,
                onSelectDay: { selectedDay = $0 }
            )
            HStack(spacing: 14) {
                legend(AppPalette.clay, lang.t("journal.legend_match"))
                legend(AppPalette.moss, lang.t("journal.legend_fuel"))
            }
            Text(lang.t("journal.calendar_hint"))
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    private func dayAccessibility(_ date: Date, _ mark: DayMark) -> String {
        var parts = [longDate(date)]
        if mark.match { parts.append(lang.t("journal.legend_match")) }
        if mark.fuel { parts.append(lang.t("journal.legend_fuel")) }
        if mark.isEmpty { parts.append(lang.t("matches.calendar_not_logged")) }
        return parts.joined(separator: ", ")
    }

    // MARK: Today

    private var quickActions: some View {
        HStack(spacing: 10) {
            actionTile("fork.knife", lang.t("journal.add_fuel")) { newFuelDate = Date() }
            actionTile("figure.tennis", lang.t("journal.add_match")) { newMatchDate = Date() }
        }
        .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
    }

    private func actionTile(_ symbol: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(AppPalette.clay)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .cardSurface(cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: The two halves

    private var destinations: some View {
        VStack(spacing: 10) {
            NavigationLink {
                MatchesListView()
                    .environmentObject(matches)
                    .environmentObject(lang)
                    .environmentObject(session)
            } label: {
                destinationCard("list.bullet.rectangle.portrait",
                                lang.t("journal.matches_card_title"),
                                String(format: lang.t("journal.matches_card_sub"), matches.totalEntries))
            }
            .buttonStyle(PressableCardStyle())

            NavigationLink {
                NutritionView()
                    .environmentObject(lang)
                    .environmentObject(session)
            } label: {
                destinationCard("fork.knife.circle.fill",
                                lang.t("journal.fuel_card_title"),
                                String(format: lang.t("journal.fuel_card_sub"), nutrition.entries.count))
            }
            .buttonStyle(PressableCardStyle())
        }
        .reveal(appeared: appeared, index: 3, reduceMotion: reduceMotion)
    }

    private func destinationCard(_ symbol: String, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(sub)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
        .contentShape(Rectangle())
    }

    // MARK: Timeline

    @ViewBuilder
    private var timeline: some View {
        let items = digest.timeline
        if items.isEmpty {
            Text(lang.t("journal.empty"))
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(lang.t("journal.recent"))
                ForEach(items.prefix(12)) { item in
                    JournalItemRow(item: item,
                                   onRateFuel: { ratingEntry = $0 },
                                   onOpenMatch: { matchDetail = $0 })
                        .environmentObject(lang)
                }
            }
            .reveal(appeared: appeared, index: 4, reduceMotion: reduceMotion)
        }
    }

    // MARK: Dates

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        if cal.isDateInToday(date) { return lang.t("journal.day_today") }
        if cal.isDateInYesterday(date) { return lang.t("journal.day_yesterday") }
        return longDate(date)
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return f.string(from: date)
    }
}

/// `sheet(item:)` needs an `Identifiable`; a bare `Date` is not one.
struct IdentifiableDate: Identifiable, Hashable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
