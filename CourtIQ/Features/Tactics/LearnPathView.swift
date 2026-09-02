import SwiftUI

/// A lesson plus the chapter it belongs to — the unit of navigation, because
/// every gating and XP decision needs both.
struct LessonRoute: Hashable {
    let chapter: Chapter
    let lesson: Lesson
}

/// Non-lesson screens the rail can push onto the same stack. A separate route
/// type (with its own `navigationDestination`) so Tennis IQ never has to
/// pretend to be a lesson and `LessonRoute` keeps meaning exactly one thing.
enum ExtraRoute: Hashable {
    case tennisIQ
}

/// The course path: the app's home screen.
///
/// One vertical rail with a node per lesson, so the whole 30-lesson course is
/// one scroll and the player can always see how far the road goes. The "next
/// lesson" node is enlarged and ringed — on open, the single most important
/// question ("what do I do now?") is answered without reading anything.
struct LearnPathView: View {
    @Environment(ContentStore.self) private var content
    @Environment(PlayerProgress.self) private var progress
    @Environment(TacticsAccess.self) private var subscriptions

    @State private var router = LessonRouter()
    @State private var showPaywall = false

    private var gate: AccessGate {
        AccessGate(content: content, progress: progress,
                   isSubscribed: subscriptions.isSubscribed)
    }

    private var next: (chapter: Chapter, lesson: Lesson)? {
        content.nextLesson(for: progress)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    continueCard

                    ForEach(content.chapters) { chapter in
                        chapterSection(chapter)
                    }

                    warmUpCard

                    if !content.sideSets.isEmpty {
                        sideSetSection
                    }

                    if !subscriptions.isSubscribed {
                        unlockCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(AppPalette.cream)
            .navigationTitle("Tactics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LessonRoute.self) { route in
                DialogueView(chapter: route.chapter, lesson: route.lesson)
            }
            .navigationDestination(for: ExtraRoute.self) { route in
                switch route {
                case .tennisIQ: DailyIQView()
                }
            }
            .sheet(isPresented: $showPaywall) {
                TacticsPaywallSheet()
            }
        }
        // Outside the stack, deliberately. A destination pushed by
        // `navigationDestination` is hosted by the NavigationStack itself and does
        // not inherit environment values injected *inside* the stack's root
        // content — so with this attached one level in, `DialogueView` could not
        // find `LessonRouter` and SwiftUI trapped the moment a lesson was tapped.
        // On a device that reads as the app vanishing to the home screen.
        .environment(router)
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_TACTICS=lesson pushes the first lesson
        // on appear — the push is exactly where a missing environment traps.
        .onAppear {
            guard ProcessInfo.processInfo.environment["QC_TACTICS"] == "lesson",
                  router.path.isEmpty,
                  let chapter = content.chapters.first, let lesson = chapter.lessons.first
            else { return }
            router.open(lesson, in: chapter)
        }
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            // Three pills side by side, falling back to a column once large text
            // means they no longer fit. Squeezed into an HStack at accessibility
            // sizes they wrapped into vertical stacks of single characters.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { pills }
                VStack(spacing: 8) { pills }
            }

            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack { levelName; Spacer(); levelTarget }
                    VStack(alignment: .leading, spacing: 4) { levelName; levelTarget }
                }
                KineticBar(value: progress.levelProgress)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var pills: some View {
        StatPill(icon: "flame.fill", value: "\(progress.streakDays)", label: "Day streak",
                 tint: AppPalette.clayText, background: AppPalette.clayTint)
        StatPill(icon: "bolt.fill", value: "\(progress.xp)", label: "XP",
                 tint: AppPalette.goldText, background: AppPalette.goldTint)
        StatPill(icon: "checkmark.seal.fill",
                 value: "\(progress.completedCount)/\(content.totalLessonCount)",
                 label: "Lessons done",
                 tint: AppPalette.mossText, background: AppPalette.mossTint)
    }

    private var levelName: some View {
        HStack(spacing: 6) {
            Image(systemName: progress.level.symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppPalette.clay)
            Text(progress.level.title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var levelTarget: some View {
        if let togo = progress.xpToNextLevel, let nextLevel = progress.level.next {
            Text("\(togo) XP → \(nextLevel.title)")
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Top level")
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: Continue hero

    @ViewBuilder
    private var continueCard: some View {
        if let next {
            let access = gate.access(to: next.lesson, in: next.chapter)
            Button {
                open(next.lesson, in: next.chapter, access: access)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(progress.completedCount == 0 ? "Start here" : "Continue",
                            tint: .white.opacity(0.85))
                    Text(next.lesson.title)
                        .appFont(24, weight: .heavy, relativeTo: .title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text("Chapter \(next.chapter.number) · \(next.chapter.title)")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    HStack(spacing: 6) {
                        Image(systemName: access == .needsSubscription ? "lock.fill" : "play.fill")
                        Text(access == .needsSubscription ? "Unlock to continue" : "Open lesson")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(AppPalette.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableCardStyle())
        } else {
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(AppPalette.gold)
                Text("Course complete")
                    .appFont(24, weight: .heavy, relativeTo: .title2)
                    .foregroundStyle(AppPalette.ink)
                Text("You've finished every lesson. Revisit any of them any time — replays are always free.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .cardSurface(fill: AppPalette.goldTint, stroke: AppPalette.gold.opacity(0.5))
        }
    }

    // MARK: Chapter section

    private func chapterSection(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: chapter.symbol)
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Eyebrow("Chapter \(chapter.number)")
                        if chapter.isFree {
                            Text("FREE")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppPalette.mossText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppPalette.mossTint)
                                .clipShape(Capsule())
                        } else if gate.isChapterLocked(chapter) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppPalette.inkSoft)
                        }
                    }
                    Text(chapter.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text(chapter.subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Spacer(minLength: 0)

                Text("\(progress.completedCount(in: chapter))/\(chapter.lessons.count)")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(progress.isChapterComplete(chapter) ? AppPalette.mossText : AppPalette.inkSoft)
            }
            .padding(.bottom, 8)

            ForEach(Array(chapter.lessons.enumerated()), id: \.element.id) { index, lesson in
                LessonNodeRow(
                    lesson: lesson,
                    chapter: chapter,
                    index: index,
                    isLast: index == chapter.lessons.count - 1,
                    access: gate.access(to: lesson, in: chapter),
                    isNext: next?.lesson.id == lesson.id
                ) { access in
                    open(lesson, in: chapter, access: access)
                }
            }
        }
    }

    // MARK: Tennis IQ

    /// The scenario drills' front door. Sits between the course and the side
    /// quests because it is neither: the same tactics, tested on real match
    /// situations instead of taught — and where the Tennis IQ number lives.
    private var warmUpCard: some View {
        NavigationLink(value: ExtraRoute.tennisIQ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.callout.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppPalette.clay)
                    VStack(alignment: .leading, spacing: 1) {
                        Eyebrow("Scenarios")
                        Text("Tennis IQ")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(AppPalette.ink)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Text("Real match situations, one decision at a time. Your IQ number lives here.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .cardSurface(fill: AppPalette.parchment, stroke: AppPalette.sand)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Side sets

    /// Rocco's side quests. They are also offered inside conversations, but a
    /// player who declined the offer needs a way back to them — a branch that
    /// only exists inside one dialogue is a branch most people never see again.
    private var sideSetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RaccoonView(mood: .thinking, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Eyebrow("Rocco's side quests")
                    Text("Short sets on one specific gap")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                }
                Spacer(minLength: 0)
            }

            ForEach(content.sideSets) { set in
                Button {
                    openSideSet(set)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: set.symbol)
                                .font(.callout.weight(.semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(AppPalette.clay)
                            Text(set.title)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(AppPalette.ink)
                            Spacer(minLength: 0)
                            Text("\(progress.completedCount(in: set))/\(set.lessons.count)")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(progress.isChapterComplete(set)
                                                 ? AppPalette.mossText : AppPalette.inkSoft)
                        }

                        if let hook = set.hook {
                            Text(hook)
                                .font(.footnote)
                                .foregroundStyle(AppPalette.inkSoft)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cardSurface(fill: AppPalette.parchment, stroke: AppPalette.sand)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    /// Opens a side set at the first lesson the player has not finished, so
    /// coming back to it resumes rather than restarts.
    private func openSideSet(_ set: Chapter) {
        let target = set.lessons.first { !progress.isCompleted($0.id) } ?? set.lessons.first
        guard let target else { return }
        open(target, in: set, access: gate.access(to: target, in: set))
    }

    // MARK: Unlock card

    private var unlockCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.open.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock the full course")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(content.totalLessonCount) lessons, every chapter, forever offline")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(AppPalette.premiumGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Actions

    private func open(_ lesson: Lesson, in chapter: Chapter, access: LessonAccess) {
        switch access {
        case .open:
            Sound.play(.swing)
            router.open(lesson, in: chapter)
        case .freeDaily:
            // Spend the allowance at open time, not at completion: otherwise a
            // free player could read every gated lesson and simply never finish
            // one.
            progress.spendFreeDailyLesson()
            Sound.play(.swing)
            router.open(lesson, in: chapter)
        case .needsSubscription:
            showPaywall = true
        case .needsPrevious:
            Haptics.error()
        }
    }
}

// MARK: - Lesson node

/// One rail node plus its title row. The rail is drawn per-row (a segment above
/// and below the node) so the whole path stays one lazy-friendly VStack instead
/// of a fragile overlay that has to know every row's height.
private struct LessonNodeRow: View {
    let lesson: Lesson
    let chapter: Chapter
    let index: Int
    let isLast: Bool
    let access: LessonAccess
    let isNext: Bool
    let onTap: (LessonAccess) -> Void

    @Environment(PlayerProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isDone: Bool { progress.isCompleted(lesson.id) }
    private var isLocked: Bool { !access.isOpenable }

    private var nodeSize: CGFloat { isNext ? 44 : 34 }

    var body: some View {
        Button {
            onTap(access)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                rail
                card
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: Rail + node

    private var rail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(index == 0 ? Color.clear : railColor)
                .frame(width: 3, height: 10)

            node

            Rectangle()
                .fill(isLast ? Color.clear : railColor)
                .frame(width: 3)
                .frame(minHeight: 18)
        }
        .frame(width: 46)
    }

    private var railColor: Color {
        isDone ? AppPalette.clay.opacity(0.55) : AppPalette.sand
    }

    private var node: some View {
        ZStack {
            Circle()
                .fill(nodeFill)
                .frame(width: nodeSize, height: nodeSize)

            if isNext {
                Circle()
                    .stroke(AppPalette.gold, lineWidth: 3)
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
                    .scaleEffect(pulse ? 1.12 : 1)
                    .opacity(pulse ? 0.35 : 1)
            }

            Group {
                if isDone {
                    Image(systemName: progress.isPerfect(lesson.id) ? "star.fill" : "checkmark")
                } else if isLocked {
                    Image(systemName: "lock.fill")
                } else {
                    Text("\(index + 1)")
                }
            }
            .font(.system(size: isNext ? 17 : 14, weight: .heavy, design: .rounded))
            .foregroundStyle(nodeForeground)
        }
        .onAppear {
            guard isNext, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var nodeFill: Color {
        if isDone { return AppPalette.clay }
        if isNext { return AppPalette.ink }
        if isLocked { return AppPalette.sand }
        return AppPalette.parchment
    }

    private var nodeForeground: Color {
        if isDone || isNext { return .white }
        return AppPalette.inkSoft
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lesson.title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isLocked ? AppPalette.inkSoft : AppPalette.ink)
                .multilineTextAlignment(.leading)

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(isLocked ? AppPalette.inkSoft.opacity(0.85) : AppPalette.inkSoft)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardSurface(
            fill: isLocked ? AppPalette.cream : AppPalette.parchment,
            stroke: isNext ? AppPalette.gold : AppPalette.sand,
            cornerRadius: 16
        )
        .padding(.bottom, 10)
    }

    private var subtitleText: String {
        switch access {
        case .needsPrevious(let title): return "Finish “\(title)” first"
        case .needsSubscription:        return "Unlock the full course to open this"
        case .freeDaily:                return "Today's free lesson"
        case .open:                     return isDone ? "Done · tap to review" : lesson.principle
        }
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        var state = "not started"
        if isDone { state = progress.isPerfect(lesson.id) ? "completed, first try" : "completed" }
        else if isLocked { state = "locked" }
        return "Lesson \(index + 1). \(lesson.title). \(state)."
    }

    private var accessibilityHint: String {
        switch access {
        case .open:                     return isDone ? "Opens the lesson again" : "Opens the lesson"
        case .freeDaily:                return "Uses today's free lesson"
        case .needsPrevious(let title): return "Locked until you finish \(title)"
        case .needsSubscription:        return "Opens the unlock options"
        }
    }
}
