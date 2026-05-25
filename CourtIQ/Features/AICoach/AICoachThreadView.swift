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
            supabaseSession = try await session.ensureAnonymousSession()
        } catch {
            errorBanner = lang.t("ai.error_sign_in_required")
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

    // MARK: - Context snapshot

    /// Assemble the tennis context block at the moment of send so it's
    /// always fresh. Pulls from the local stores we already maintain
    /// (matches, quiz, profile, onboarding).
    private func contextSnapshot() -> AIChatContextPayload {
        let recentMatches: [AIChatContextPayload.MatchPayload] = matches.entries
            .prefix(5)
            .map { entry in
                AIChatContextPayload.MatchPayload(
                    date: Self.dayKeyFormatter.string(from: entry.date),
                    opponentName: entry.opponentName.nilIfEmptyTrimmed,
                    result: entry.result.rawValue,
                    score: entry.score.nilIfEmptyTrimmed,
                    surface: entry.surface.rawValue,
                    ratings: AIChatContextPayload.RatingsPayload(
                        serve: entry.serveRating,
                        return: entry.returnRating,
                        movement: entry.movementRating,
                        mental: entry.mentalRating
                    ),
                    takeaway: entry.takeaway.nilIfEmptyTrimmed
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

        // Tactical profile — pick out the categories with enough reps
        // to be credible (≥3 taps each). Skip the whole block if the
        // user has done zero drills.
        let established = drillManager.establishedTacticalProfile
        let drillCount = drillManager.sessions.reduce(0) { $0 + $1.taps.count }
        let tactical: AIChatContextPayload.TacticalProfilePayload?
        if drillCount > 0 {
            func s(_ cat: TacticalCategory) -> Double? {
                established.first { $0.category == cat }?.score
            }
            tactical = AIChatContextPayload.TacticalProfilePayload(
                openCourt: s(.openCourt),
                defense: s(.defense),
                approach: s(.approach),
                patterns: s(.patterns),
                netGame: s(.netGame),
                return_: s(.return),
                totalDrillsCompleted: drillCount
            )
        } else {
            tactical = nil
        }

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
            imported: nil   // Phase 3 will wire imported ChatGPT summary here
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
