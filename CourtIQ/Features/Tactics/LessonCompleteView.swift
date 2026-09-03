import SwiftUI

/// The reward moment. Shows exactly what was earned and, when one happened, the
/// level-up or chapter badge on top — then hands the player straight back to the
/// path with the next node already ringed.
///
/// Deliberately a sheet with dismissal disabled: this is the one screen the
/// gamification loop depends on being seen.
struct LessonCompleteView: View {
    let chapter: Chapter
    let lesson: Lesson
    let firstTry: Bool
    let wasReview: Bool
    let onDone: () -> Void

    @Environment(PlayerProgress.self) private var progress
    @EnvironmentObject private var lang: LanguageManager
    private var copy: TacticsCopy { TacticsCopy(lang: lang.language) }
    @Environment(ContentStore.self) private var content
    @Environment(TacticsAccess.self) private var subscriptions

    @State private var showPaywall = false

    private var xpEarned: Int {
        guard !wasReview else { return 0 }
        var total = XPAward.lessonRead + (firstTry ? XPAward.quizFirstTry : XPAward.quizRetry)
        if progress.pendingChapterComplete != nil { total += XPAward.chapterComplete }
        return total
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                crest

                Text(headline)
                    .appFont(30, weight: .heavy, relativeTo: .title)
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)

                Text(lesson.principle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if xpEarned > 0 { rewardRow }
                if let levelUp = progress.pendingLevelUp { levelUpCard(levelUp) }
                if let done = progress.pendingChapterComplete { chapterCard(done) }
                if let days = progress.pendingStreakMilestone { streakCard(days) }

                levelBar

                if !subscriptions.isSubscribed, shouldNudgeUnlock {
                    unlockNudge
                }

                PrimaryButton(title: nextTitle, icon: "arrow.right") {
                    progress.pendingLevelUp = nil
                    progress.pendingChapterComplete = nil
                    progress.pendingStreakMilestone = nil
                    onDone()
                }
            }
            .padding(28)
        }
        .background(AppPalette.cream)
        .sheet(isPresented: $showPaywall) { TacticsPaywallSheet() }
        .onAppear {
            let isBigMoment = progress.pendingChapterComplete != nil || progress.pendingLevelUp != nil

            // Exactly one sting, picked by rarity: a chapter that also levels the
            // player up and extends a streak would otherwise fire three at once.
            // A replay earns no XP, so it gets no reward sound at all.
            if !wasReview {
                if progress.pendingChapterComplete != nil {
                    Sound.play(.celebrate)
                } else if progress.pendingLevelUp != nil {
                    Sound.play(.levelUp)
                } else if progress.pendingStreakMilestone != nil {
                    Sound.play(.streak)
                } else {
                    Sound.play(.complete)
                }
            }

            // Ask for a rating at a genuine high point — a finished chapter or a
            // level-up — never after a plain lesson. Finishing a chapter is the
            // strongest moment we get, and for a free player it is usually the
            // last one before the paywall, so it asks on its own; a mid-chapter
            // level-up still waits for a second win.
            if isBigMoment {
                RatingPrompt.registerWin(
                    minimumWins: progress.pendingChapterComplete != nil ? 1 : 2
                )
            }
        }
    }

    // MARK: Pieces

    private var crest: some View {
        ZStack {
            Circle()
                .fill(firstTry ? AppPalette.goldTint : AppPalette.mossTint)
                .frame(width: 96, height: 96)
            Image(systemName: firstTry ? "star.fill" : "checkmark")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(firstTry ? AppPalette.gold : AppPalette.mossDeep)
        }
        .padding(.top, 12)
    }

    private var headline: String {
        if wasReview { return "Still got it" }
        if progress.pendingChapterComplete != nil { return "Chapter complete" }
        return firstTry ? "Nailed it first try" : "Lesson complete"
    }

    private var rewardRow: some View {
        HStack(spacing: 10) {
            reward("bolt.fill", "+\(xpEarned) XP", AppPalette.goldText, AppPalette.goldTint)
            reward("flame.fill", "\(progress.streakDays)-day streak",
                   AppPalette.clayText, AppPalette.clayTint)
        }
    }

    private func reward(_ icon: String, _ text: String, _ tint: Color, _ background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.footnote.weight(.bold))
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(Capsule())
    }

    private func levelUpCard(_ level: PlayerLevel) -> some View {
        VStack(spacing: 8) {
            Eyebrow(copy.newLevel, tint: .white.opacity(0.85))
            HStack(spacing: 10) {
                Image(systemName: level.symbol)
                    .font(.title2.weight(.bold))
                Text(level.title)
                    .appFont(24, weight: .heavy, relativeTo: .title2)
            }
            .foregroundStyle(.white)
            Text(level.blurb)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppPalette.premiumGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func chapterCard(_ done: Chapter) -> some View {
        HStack(spacing: 14) {
            Image(systemName: done.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppPalette.mossText)
            VStack(alignment: .leading, spacing: 2) {
                Text(copy.badgeEarned(done.number))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(done.title)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .cardSurface(fill: AppPalette.mossTint, stroke: AppPalette.mossDeep.opacity(0.4))
    }

    /// Shown only on a milestone day, so the streak count in `rewardRow` stays
    /// the everyday version and this stays an event.
    private func streakCard(_ days: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppPalette.clayText)
            VStack(alignment: .leading, spacing: 2) {
                Text(copy.daysInARow(days))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(copy.habitLine)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .cardSurface(fill: AppPalette.clayTint, stroke: AppPalette.clay.opacity(0.4))
    }

    private var levelBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.level.title)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                if let togo = progress.xpToNextLevel, let next = progress.level.next {
                    Text(copy.xpTo(togo, next.title))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            KineticBar(value: progress.levelProgress)
        }
        .padding(16)
        .cardSurface()
    }

    /// Nudge only where it's earned: right after the free chapter is finished, or
    /// once the day's free lesson is gone.
    private var shouldNudgeUnlock: Bool {
        if let done = progress.pendingChapterComplete, done.isFree { return true }
        return !progress.hasFreeDailyLesson
    }

    private var unlockNudge: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(progress.pendingChapterComplete?.isFree == true
                     ? "That was the free chapter."
                     : "That was today's free lesson.")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(copy.unlockAll(content.totalLessonCount))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                HStack(spacing: 6) {
                    Text(copy.seeOptions)
                    Image(systemName: "chevron.right")
                }
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.clayText)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardSurface(fill: AppPalette.goldTint, stroke: AppPalette.gold.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    private var nextTitle: String {
        content.nextLesson(for: progress) == nil ? "Back to the course" : "Next lesson"
    }
}
