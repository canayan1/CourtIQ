import Foundation

/// The single place that decides whether a lesson can be opened. Every gating
/// question in the app routes through here so the freemium rules can be changed
/// in one edit.
///
/// The rules, in order:
///  1. **Sequential.** The course teaches geometry before patterns, so a lesson
///     opens only once the one before it is done. Finished lessons stay
///     revisitable forever.
///  2. **Chapter 1 is free.** The whole first chapter, no account, no paywall —
///     this is the entry the freemium model rests on.
///  3. **Beyond chapter 1:** subscribers get everything. Free players get one
///     lesson per day, so the course keeps teaching them something instead of
///     turning into a wall.
enum LessonAccess: Equatable {
    /// Openable at no cost.
    case open
    /// Openable, but doing so spends today's one free lesson.
    case freeDaily
    /// Blocked until the preceding lesson is finished.
    case needsPrevious(id: String, title: String)
    /// Blocked by the paywall — today's free lesson is already spent.
    case needsSubscription

    var isOpenable: Bool { self == .open || self == .freeDaily }
}

@MainActor
struct AccessGate {
    let content: ContentStore
    let progress: PlayerProgress
    /// Just the entitlement, not the whole store: the gate has no business with
    /// products or purchase state, and taking a `Bool` means the rules can be
    /// tested without standing up StoreKit.
    let isSubscribed: Bool

    func access(to lesson: Lesson, in chapter: Chapter) -> LessonAccess {
        // Revisiting is always free — the sequential and paywall rules only
        // guard the *first* unlock of a lesson.
        if progress.isCompleted(lesson.id) { return .open }

        if let previous = previousLesson(before: lesson, in: chapter),
           !progress.isCompleted(previous.id) {
            return .needsPrevious(id: previous.id, title: previous.title)
        }

        if chapter.isFree { return .open }
        if isSubscribed { return .open }
        return progress.hasFreeDailyLesson ? .freeDaily : .needsSubscription
    }

    /// Whether the chapter's card should render with a lock glyph. Chapters the
    /// player has already broken into (any lesson done) stop showing as locked
    /// even for free players, because their daily lesson keeps them going.
    func isChapterLocked(_ chapter: Chapter) -> Bool {
        if chapter.isFree || isSubscribed { return false }
        return progress.completedCount(in: chapter) == 0
    }

    /// The lesson immediately before this one in its own reading order.
    ///
    /// For a main chapter that order is the whole course, so the sequence runs
    /// across chapter boundaries. For a side set it is only the set's own
    /// lessons — a side set is entered mid-course from a conversation, so it must
    /// not demand that the main course be finished first.
    private func previousLesson(before lesson: Lesson, in chapter: Chapter) -> Lesson? {
        let order = chapter.isSideSet ? chapter.lessons : content.curriculum.allLessons
        guard let index = order.firstIndex(where: { $0.id == lesson.id }), index > 0 else { return nil }
        return order[index - 1]
    }
}
