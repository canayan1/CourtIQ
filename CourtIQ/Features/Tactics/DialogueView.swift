import SwiftUI

/// Pushes lessons onto the Learn tab's navigation stack.
///
/// A shared router rather than each screen owning a `navigationDestination`,
/// because a dialogue can branch *sideways* — Rocco offers a side set mid-lesson
/// and that has to push onto the same stack the rail pushed onto.
@Observable
@MainActor
final class LessonRouter {
    /// Type-erased on purpose: the rail also pushes non-lesson screens (the
    /// rally warm-up) onto this same stack via their own route types.
    var path = NavigationPath()

    func open(_ lesson: Lesson, in unit: Chapter) {
        path.append(LessonRoute(chapter: unit, lesson: lesson))
    }

    /// Pop everything, landing back on the rail.
    func popToRoot() {
        path = NavigationPath()
    }
}

/// A lesson taught as a conversation with Rocco.
///
/// This is the app's main flow. The reason it replaced a readable lesson page:
/// a beginner will not read three cards of tactics, but they will answer a
/// question a raccoon just asked them. Same content, one decision per screen.
///
/// The transcript accumulates, so scrolling back re-reads what Rocco said — the
/// conversation is the lesson notes, not a slideshow that erases itself.
struct DialogueView: View {
    let chapter: Chapter
    let lesson: Lesson

    @Environment(ContentStore.self) private var content
    @Environment(PlayerProgress.self) private var progress
    @Environment(TacticsAccess.self) private var subscriptions
    @Environment(LessonRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var script: DialogueScript?
    @State private var bubbles: [Bubble] = []
    @State private var currentID: String = ""
    @State private var mood: Mood = .happy
    /// Any wrong pick anywhere in the run costs the first-try bonus.
    @State private var wrongPicks = 0
    @State private var showCompletion = false
    @State private var showNotes = false
    @State private var showPaywall = false
    @State private var wasAlreadyDone: Bool?
    /// Measured height of the transcript's viewport, used as the bubble column's
    /// minimum height.
    @State private var viewportHeight: CGFloat = 0

    private var isReview: Bool { wasAlreadyDone ?? progress.isCompleted(lesson.id) }

    private var gate: AccessGate {
        AccessGate(content: content, progress: progress,
                   isSubscribed: subscriptions.isSubscribed)
    }

    private var currentNode: DialogueNode? {
        script?.node(currentID)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
            actionBar
        }
        .background(AppPalette.cream)
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    showNotes = true
                } label: {
                    Label("Notes", systemImage: "text.alignleft")
                }
                .accessibilityLabel("Read the full notes")
            }
        }
        .onAppear(perform: start)
        .sheet(isPresented: $showNotes) {
            NavigationStack {
                LessonView(chapter: chapter, lesson: lesson, showsQuiz: false)
            }
        }
        .sheet(isPresented: $showPaywall) { TacticsPaywallSheet() }
        .sheet(isPresented: $showCompletion) {
            LessonCompleteView(
                chapter: chapter,
                lesson: lesson,
                firstTry: wrongPicks == 0,
                wasReview: isReview
            ) {
                showCompletion = false
                // Pop back to the rail rather than one step, so finishing a side
                // set lands on the course instead of the lesson that offered it.
                router.popToRoot()
            }
            .interactiveDismissDisabled()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: typeSize.isAccessibilitySize ? 6 : 10) {
            // Rocco shrinks at accessibility text sizes. He does not scale with
            // Dynamic Type — he is a picture — so at the largest sizes a fixed
            // 94pt header was taking screen the text needed.
            RaccoonView(mood: mood, size: typeSize.isAccessibilitySize ? 54 : 94)

            StepRail(value: scriptProgress)
                .padding(.horizontal, 60)
        }
        .padding(.top, 4)
        .padding(.bottom, typeSize.isAccessibilitySize ? 8 : 12)
        .frame(maxWidth: .infinity)
        .background(AppPalette.sand.opacity(0.45))
    }

    /// How far through the script the player is. Clamped to never go backwards,
    /// so a retry loop doesn't look like lost progress.
    private var scriptProgress: Double {
        guard let script, script.nodes.count > 1 else { return 0 }
        guard let index = script.nodes.firstIndex(where: { $0.id == currentID }) else { return 0 }
        return Double(index) / Double(script.nodes.count - 1)
    }

    // MARK: Transcript

    /// The conversation so far.
    ///
    /// The bubble column is given a minimum height of one viewport and aligned to
    /// its top, then the scroll view is anchored to its bottom. Those two together
    /// give both behaviours a chat needs: a short conversation sits at the top of
    /// the screen, and once it outgrows the viewport the newest bubble is always
    /// the one on screen. Scrolling explicitly after each append instead raced the
    /// new bubble's layout, which could leave a question hidden above the options.
    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(bubbles) { bubble in
                    BubbleRow(bubble: bubble)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: viewportHeight, alignment: .topLeading)
        }
        .defaultScrollAnchor(.bottom)
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, new in viewportHeight = new }
            }
        }
    }

    // MARK: Action bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            switch currentNode?.kind {
            case .ask:
                ForEach(currentNode?.options ?? []) { option in
                    Button {
                        pick(option)
                    } label: {
                        Text(option.label)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .cardSurface(cornerRadius: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())
                }

            case .offer:
                PrimaryButton(title: "Go on then", icon: "arrow.turn.down.right") {
                    acceptOffer()
                }
                QuietButton(title: "Maybe later") {
                    Haptics.tap()
                    advance()
                }

            case .finish:
                PrimaryButton(
                    title: isReview ? "Done" : "Complete lesson",
                    icon: "checkmark",
                    tint: AppPalette.mossDeep
                ) {
                    finish()
                }

            case .say, .show:
                PrimaryButton(title: "Continue", icon: "arrow.right") {
                    Sound.play(.tap)
                    advance()
                }

            case nil:
                EmptyView()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(AppPalette.parchment)
        .overlay(alignment: .top) {
            Rectangle().fill(AppPalette.sand).frame(height: 1)
        }
    }

    // MARK: Flow

    private func start() {
        guard script == nil else { return }
        if wasAlreadyDone == nil { wasAlreadyDone = progress.isCompleted(lesson.id) }

        let loaded = content.script(for: lesson)
        script = loaded
        guard let first = loaded.first else { return }
        currentID = first.id
        mood = first.mood
        bubbles = bubbleContent(of: first)

    }

    /// Moves to the current node's `next`.
    private func advance() {
        guard let node = currentNode, let nextID = node.next else { return }
        go(to: nextID)
    }

    private func go(to id: String) {
        guard let next = script?.node(id) else { return }
        currentID = id
        // The offer is the one node that gets its own sting: it is Rocco changing
        // the subject, and the cue is what makes a player look up at it.
        if next.kind == .offer { Sound.play(.curious) }
        withAnimation(reduceMotion ? nil : Motion.entrance) {
            mood = next.mood
            bubbles.append(contentsOf: bubbleContent(of: next))
        }
    }

    private func pick(_ option: DialogueNode.Option) {
        guard let node = currentNode else { return }

        if option.correct {
            Haptics.success()
            Sound.play(.correct)
        } else {
            Haptics.error()
            Sound.play(.wrong)
            wrongPicks += 1
        }

        withAnimation(reduceMotion ? nil : Motion.entrance) {
            bubbles.append(Bubble(speaker: .player, text: option.label, wasWrong: !option.correct))
            bubbles.append(Bubble(speaker: .rocco, text: option.reply))
            mood = option.correct ? .happy : .oops
        }

        // A wrong option loops back to the same question. Re-presenting the node
        // would print the question a second time, so the options simply stay live
        // and only Rocco's reaction is added.
        guard option.next != node.id else { return }
        go(to: option.next)
    }

    /// Rocco offered a side set and the player said yes.
    private func acceptOffer() {
        guard let setID = currentNode?.setID,
              let set = content.sideSet(id: setID),
              let first = set.lessons.first else {
            advance()
            return
        }

        // Advance the conversation first: coming back from the side set should
        // land on the rest of this lesson, not on the offer again.
        advance()

        switch gate.access(to: first, in: set) {
        case .open:
            router.open(first, in: set)
        case .freeDaily:
            progress.spendFreeDailyLesson()
            router.open(first, in: set)
        case .needsSubscription:
            showPaywall = true
        case .needsPrevious:
            // Only reachable if the set's own first lesson is somehow gated;
            // opening it anyway would break the sequence, so fall back to the
            // set's next unfinished lesson.
            if let resume = set.lessons.first(where: { !progress.isCompleted($0.id) }) {
                router.open(resume, in: set)
            }
        }
    }

    private func finish() {
        progress.completeLesson(lesson, in: chapter, firstTry: wrongPicks == 0)
        Haptics.celebrate()
        showCompletion = true
    }

    private func bubbleContent(of node: DialogueNode) -> [Bubble] {
        [Bubble(speaker: .rocco, text: node.text, scene: node.scene)]
    }
}

// MARK: - Step rail

/// How far through the conversation the player is. Stateless on purpose: the
/// value is derived from the current node every render, so it can never disagree
/// with where the dialogue actually is.
private struct StepRail: View {
    /// 0…1.
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppPalette.sand)
                Capsule()
                    .fill(AppPalette.clay)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 6)
        .animation(Motion.reveal, value: value)
        .accessibilityHidden(true)
    }
}

// MARK: - Bubble

/// One line of the conversation. Rocco speaks from the left on parchment; the
/// player's own choices echo back from the right in clay, so the transcript reads
/// as a dialogue the player took part in rather than a lecture they scrolled.
private struct BubbleRow: View {
    let bubble: Bubble

    var body: some View {
        HStack {
            if bubble.speaker == .player { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 12) {
                Text(bubble.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)

                if let scene = bubble.scene {
                    CourtDiagram(scene: scene)
                }
            }
            .padding(bubble.scene == nil ? 16 : 14)
            .frame(maxWidth: bubble.scene == nil ? .infinity : nil,
                   alignment: .leading)
            .background(background)
            .clipShape(BubbleShape(fromPlayer: bubble.speaker == .player))

            if bubble.speaker == .rocco && bubble.scene == nil { Spacer(minLength: 40) }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var textColor: Color {
        bubble.speaker == .player ? .white : AppPalette.ink
    }

    private var background: Color {
        switch bubble.speaker {
        case .rocco:  return AppPalette.parchment
        case .player: return bubble.wasWrong ? AppPalette.alert : AppPalette.clay
        }
    }
}

/// A speech bubble: rounded, with the corner nearest its speaker pulled in tight
/// so it points back at whoever said it.
private struct BubbleShape: Shape {
    let fromPlayer: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 18
        let small: CGFloat = 5
        return Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: fromPlayer
                    ? [.topLeft, .topRight, .bottomLeft]
                    : [.topLeft, .topRight, .bottomRight],
                cornerRadii: CGSize(width: big, height: big)
            ).cgPath
        )
        .union(cornerPatch(in: rect, radius: small))
    }

    /// Squares off the speaker-side corner that `byRoundingCorners` left round.
    private func cornerPatch(in rect: CGRect, radius: CGFloat) -> Path {
        let side = radius * 2
        let origin = CGPoint(
            x: fromPlayer ? rect.maxX - side : rect.minX,
            y: rect.maxY - side
        )
        return Path(CGRect(origin: origin, size: CGSize(width: side, height: side)))
    }
}
