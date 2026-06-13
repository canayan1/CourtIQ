import SwiftUI

/// Single conversation. Renders messages chronologically, lets the
/// user type a new message, sends it through AIChatClient, and shows
/// the streaming-style optimistic loading state until the assistant
/// reply lands.
struct AICoachThreadView: View {
    /// `nil` = brand-new thread that doesn't exist yet on the server.
    /// First `send()` allocates the server-side `chatId`.
    let thread: AIChatThread?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var aiClient: AIChatClient
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    @State private var input: String = ""
    @State private var workingThreadID: String?
    @State private var isSending = false
    @State private var errorBanner: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            if let err = errorBanner { banner(err) }
            composer
        }
        .background(AppPalette.cream)
        .navigationTitle(currentThread?.title ?? lang.t("ai.new_chat"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("common.done")) { dismiss() }
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .onAppear {
            workingThreadID = thread?.id
            // Bring up the keyboard the moment a brand-new chat opens —
            // the user came here to type, not to admire the empty space.
            if thread == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    inputFocused = true
                }
            }
        }
        .task { await compactMatchMemoryIfNeeded() }
    }

    /// Fire-and-forget: fold any newly-aged-out matches into the rolling
    /// long-term summary when the Coach opens. Throttled inside the store
    /// so this stays a rare, cheap call. No UI feedback — purely improves
    /// the context the next turn ships.
    private func compactMatchMemoryIfNeeded() async {
        let committed = matches.entries.filter { !$0.isDraft }
        guard MatchMemoryStore.shared.shouldCompact(committed: committed) else { return }
        guard let supabaseSession = try? await session.ensureAnonymousSession() else { return }
        await aiClient.compactMatchMemoryIfNeeded(
            committed: committed,
            session: supabaseSession
        )
    }

    // MARK: - Current thread

    /// The live thread from the client (so we re-render when messages
    /// flow in). Falls back to the initial snapshot until the first
    /// send happens.
    private var currentThread: AIChatThread? {
        if let id = workingThreadID,
           let live = aiClient.threads.first(where: { $0.id == id }) {
            return live
        }
        return thread
    }

    private var messages: [AIChatMessage] {
        currentThread?.messages ?? []
    }

    // MARK: - Messages list

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Safety + reliance disclaimer. Always shown at the top
                    // of the scroll feed so users see it in fresh threads,
                    // and remain reminded of it when scrolling back to read
                    // earlier messages in long threads.
                    disclaimerBanner
                    if messages.isEmpty { introHint }
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    // Spacer so the last bubble isn't glued to the composer.
                    Color.clear.frame(height: 8).id("end")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("end", anchor: .bottom)
                }
            }
        }
    }

    /// Persistent reminder that AI output is unverified and not medical
    /// advice. Apple App Review Guideline 5.2.2 (AI-generated content)
    /// + civil liability defence against "I followed the coach and got
    /// hurt / lost a match" claims. Compact two-line copy so it doesn't
    /// dominate the thread visually.
    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("ai.disclaimer_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("ai.disclaimer_body"))
                    .font(.caption2)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.clay.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.clay.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var introHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(lang.t("ai.thread_hint_kicker"), systemImage: "sparkles")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(lang.t("ai.thread_hint_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func messageBubble(_ msg: AIChatMessage) -> some View {
        switch msg.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(msg.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                    .padding(.top, 4)
                Group {
                    if msg.pending {
                        thinkingDots
                    } else {
                        Text(msg.content)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 40)
            }
        case .system:
            EmptyView()
        }
    }

    /// Three-dot pulsing indicator while waiting for the assistant
    /// reply. TimelineView keeps it lightweight.
    private var thinkingDots: some View {
        TimelineView(.animation(minimumInterval: 1.0/12.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    let phase = sin(t * 4 + Double(i) * 0.6)
                    Circle()
                        .fill(AppPalette.clay.opacity(0.4 + 0.4 * (phase + 1) / 2))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppPalette.alert)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            Spacer()
            Button(lang.t("common.dismiss")) {
                withAnimation { errorBanner = nil }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AppPalette.clay)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppPalette.alert.opacity(0.08))
        .overlay(Rectangle().fill(AppPalette.alert.opacity(0.18)).frame(height: 1), alignment: .top)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(lang.t("ai.composer_placeholder"), text: $input, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...5)
                .padding(10)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                Task { await tappedSend() }
            } label: {
                Image(systemName: isSending ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(canSend ? AppPalette.clay : AppPalette.inkSoft.opacity(0.4))
            }
            .disabled(!canSend || isSending)
            .accessibilityLabel(lang.t("ai.send"))
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func tappedSend() async {
        let toSend = input
        input = ""
        isSending = true
        errorBanner = nil
        defer { isSending = false }

        // Mint or reuse a Supabase session. AI Coach works without
        // Apple Sign-In by falling back to anonymous auth — RLS still
        // scopes by auth.uid(), the user just isn't connected across
        // devices until they upgrade to Apple Sign-In later.
        let supabaseSession: SupabaseSession
        do {
            supabaseSession = try await ensureSessionWithRetry()
        } catch {
            errorBanner = lang.t("ai.error_connect")
            input = toSend
            return
        }

        do {
            let updated = try await aiClient.send(
                message: toSend,
                threadID: workingThreadID,
                session: supabaseSession,
                contextProvider: { contextSnapshot() }
            )
            workingThreadID = updated.id
        } catch {
            errorBanner = aiClient.lastError ?? lang.t("ai.error_send_generic")
            input = toSend
        }
    }

    /// Establishing the Supabase session can fail transiently (cold auth
    /// endpoint, brief network hiccup, or a short-lived anonymous sign-in
    /// rate limit). Retry a few times with backoff so a single blip doesn't
    /// surface as "no response" — the #1 thing reviewers and users hit.
    private func ensureSessionWithRetry(attempts: Int = 3) async throws -> SupabaseSession {
        var lastError: Error?
        for i in 0..<attempts {
            do {
                return try await session.ensureAnonymousSession()
            } catch {
                lastError = error
                if i < attempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(700_000_000) * UInt64(i + 1))
                }
            }
        }
        throw lastError ?? RemoteDataError.message("Could not establish a session.")
    }

    // MARK: - Context snapshot

    /// Assemble the tennis context block at the moment of send so it's
    /// always fresh. Pulls from the local stores we already maintain
    /// (matches, quiz, profile, onboarding).
    private func contextSnapshot() -> AIChatContextPayload {
        // Only committed (non-draft) matches feed the Coach — an
        // in-progress draft defaults to won/hard and would mislead it.
        // The newest `recentWindowSize` go verbatim WITH notes; older ones
        // are represented by the rolling `matchMemory` summary instead.
        // Only completed (played) matches with a result feed the Coach — an
        // in-progress draft defaults to won/hard, and an upcoming match has
        // no result yet; either would mislead it.
        let committed = matches.entries.filter {
            !$0.isDraft && $0.status == .completed && $0.result != nil
        }
        let recentMatches: [AIChatContextPayload.MatchPayload] = committed
            .prefix(MatchMemoryStore.recentWindowSize)
            .map { entry in
                AIChatContextPayload.MatchPayload(
                    date: Self.dayKeyFormatter.string(from: entry.date),
                    opponentName: entry.opponentName.nilIfEmptyTrimmed,
                    result: (entry.result ?? .won).rawValue,
                    score: entry.score.nilIfEmptyTrimmed,
                    surface: entry.surface.rawValue,
                    ratings: AIChatContextPayload.RatingsPayload(
                        serve: entry.serveRating,
                        return: entry.returnRating,
                        movement: entry.movementRating,
                        mental: entry.mentalRating
                    ),
                    takeaway: entry.takeaway.nilIfEmptyTrimmed,
                    preMatchNotes: entry.preMatchNotes.nilIfEmptyTrimmed,
                    postMatchNotes: entry.postMatchNotes.nilIfEmptyTrimmed
                )
            }

        let topMistakes = Array(dailyQuizManager.topMistakePatterns.prefix(3))
        let recentQuizzes: [AIChatContextPayload.QuizSessionPayload] = dailyQuizManager
            .archivedDailyHistory
            .prefix(3)
            .map { record in
                AIChatContextPayload.QuizSessionPayload(
                    date: Self.dayKeyFormatter.string(from: record.completedAt),
                    score: record.score,
                    total: record.totalQuestions,
                    focusLabel: record.focusLabel.nilIfEmptyTrimmed
                )
            }

        // Tactical profile — combined drill + quiz signal. Quiz feeds
        // the same 6-category map via DailyQuizManager.quizTacticalProfile,
        // and CourtTapDrillManager.combinedTacticalProfile fuses both
        // weighted by sample count. We still keep the ≥3-samples floor
        // before exposing a category to the AI so it doesn't anchor
        // on a single noisy result.
        let selfAssessment = SelfAssessmentStore.shared.load()
        let combined = drillManager.combinedTacticalProfile(
            with: dailyQuizManager,
            selfAssessment: selfAssessment
        )
        .filter { $0.isEstablished || ($0.score ?? 0) > 0 }
        let totalDrillTaps = drillManager.sessions.reduce(0) { $0 + $1.taps.count }
        let totalQuizQs = dailyQuizManager.sessionHistory.reduce(0) {
            $0 + ($1.tacticalBuckets?.reduce(0) { $0 + $1.total } ?? 0)
        }
        let totalSignals = totalDrillTaps + totalQuizQs
        let tactical: AIChatContextPayload.TacticalProfilePayload?
        if totalSignals > 0 {
            func s(_ cat: TacticalCategory) -> Double? {
                combined.first { $0.category == cat }?.score
            }
            tactical = AIChatContextPayload.TacticalProfilePayload(
                openCourt: s(.openCourt),
                defense: s(.defense),
                approach: s(.approach),
                patterns: s(.patterns),
                netGame: s(.netGame),
                return_: s(.return),
                totalDrillsCompleted: totalSignals
            )
        } else {
            tactical = nil
        }

        // Play style fingerprint — only included if the user has any
        // v2 drill shots logged. AI Coach can then anchor coaching
        // around archetype + preference patterns.
        let psp = drillManager.playStyleProfile
        let playStyle: AIChatContextPayload.PlayStylePayload?
        if psp.totalShots > 0 {
            playStyle = AIChatContextPayload.PlayStylePayload(
                topspinPct: psp.percentages[.topspin],
                flatPct:    psp.percentages[.flat],
                slicePct:   psp.percentages[.slice],
                dropPct:    psp.percentages[.drop],
                lobPct:     psp.percentages[.lob],
                shotTypeAccuracy: psp.shotTypeAccuracy,
                archetype: psp.archetype?.rawValue,
                totalShots: psp.totalShots
            )
        } else {
            playStyle = nil
        }

        // Self-assessed Tennis Profile (level, style, strengths, growth) +
        // adopted goals — sent in English so the Coach personalizes to it.
        let tennisProfilePayload: AIChatContextPayload.TennisProfilePayload? = {
            guard let p = TennisProfileStore.shared.profile else { return nil }
            let en = TennisProfileCopy(lang: .english)
            let r = p.result
            return AIChatContextPayload.TennisProfilePayload(
                level: en.levelTitle(r.level),
                levelRef: en.levelNTRP(r.level),
                archetype: en.archetypeTitle(r.archetype),
                strengths: r.strengths.map { en.dimension($0) },
                growthAreas: r.growthAreas.map { en.dimension($0) },
                goals: p.adoptedGoals.map { en.goalTitle($0.titleKey) }
            )
        }()

        return AIChatContextPayload(
            profile: AIChatContextPayload.ProfilePayload(
                level: UserDefaults.standard.string(forKey: "CourtIQ.onboardingLevel"),
                focus: session.currentImprovementFocus.nilIfEmptyTrimmed,
                topMistakePatterns: topMistakes.isEmpty ? nil : topMistakes,
                currentFocus: session.currentImprovementFocus.nilIfEmptyTrimmed
            ),
            matches: recentMatches.isEmpty ? nil : recentMatches,
            quiz: AIChatContextPayload.QuizPayload(
                lastSessions: recentQuizzes.isEmpty ? nil : recentQuizzes,
                topMistakes: topMistakes.isEmpty ? nil : topMistakes
            ),
            tacticalProfile: tactical,
            playStyle: playStyle,
            imported: nil,  // Phase 3 will wire imported ChatGPT summary here
            matchMemory: MatchMemoryStore.shared.memoryForContext,
            tennisProfile: tennisProfilePayload
        )
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private extension String {
    /// File-scoped twin of the existing `nilIfBlank` helper that lives
    /// behind fileprivate elsewhere in the module — keeps the context
    /// snapshot builder readable without exposing the original.
    var nilIfEmptyTrimmed: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
