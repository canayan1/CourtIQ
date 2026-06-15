import SwiftUI

/// Pre-match (upcoming) capture: opponent, surface, date/time, and the
/// plan. No result, score, or ratings. Optionally lets the user get an AI
/// take on their plan before saving. On save the entry is stored as
/// `.upcoming` and a reminder is scheduled ~3h after the match.
struct MatchUpcomingFormView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    /// Called once the entry is saved and the flow should close.
    let onDone: () -> Void

    @State private var date: Date = Date()
    @State private var opponentName: String = ""
    @State private var surface: MatchSurface = .hard
    @State private var plan: String = ""

    @State private var aiPreComment: String?
    @State private var analyzing = false
    @State private var analysisFailed = false

    @FocusState private var focused: Bool

    private let service = MatchAnalysisService()
    private let entryID = UUID().uuidString

    var body: some View {
        ZStack {
            if analyzing {
                MatchAnalyzingView(
                    title: lang.t("matches.ai_pre_analyzing_title"),
                    stepLabels: analyzingSteps
                )
            } else {
                form
            }
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                MatchFormComponents.BoxedField(
                    placeholder: lang.t("matches.opponent_placeholder"),
                    text: $opponentName
                )

                MatchFormComponents.SurfacePicker(surface: $surface)

                MatchFormComponents.NoteField(
                    iconName: "target",
                    iconColor: AppPalette.clay,
                    label: lang.t("matches.pre_match_label"),
                    placeholder: lang.t("matches.pre_match_placeholder"),
                    text: $plan
                )
                .focused($focused)

                aiPlanSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(AppPalette.cream)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("common.cancel")) { onDone() }
                    .foregroundStyle(AppPalette.inkSoft)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.save")) { save() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("common.done")) { focused = false }
            }
        }
    }

    // MARK: - AI plan comment

    @ViewBuilder
    private var aiPlanSection: some View {
        if let comment = aiPreComment {
            MatchAnalysisCard(title: lang.t("matches.ai_pre_title"), report: comment)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    requestPreComment()
                } label: {
                    Label(lang.t("matches.ai_comment_plan_cta"), systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.clay)
                .disabled(plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if analysisFailed {
                    Text(lang.t("matches.ai_failed"))
                        .font(.caption)
                        .foregroundStyle(AppPalette.alert)
                }
            }
        }
    }

    private var analyzingSteps: [String] {
        [
            lang.t("matches.ai_step_reading_plan"),
            lang.t("matches.ai_step_opponent"),
            lang.t("matches.ai_step_tactics"),
            lang.t("matches.ai_step_writing")
        ]
    }

    // MARK: - Actions

    private func requestPreComment() {
        analysisFailed = false
        analyzing = true
        let snapshot = currentEntry(status: .upcoming)
        Task {
            // Run the call + a SHORT minimum floor concurrently so it still
            // feels like real analysis, but reveals as soon as the call
            // returns past the floor instead of a hard 12s.
            async let minHold: Void = Task.sleep(nanoseconds: 3_500_000_000) as Void
            let result: Result<String, Error>
            do {
                let supabaseSession = try await ensureSessionWithRetry()
                let summary = MatchAnalysisService.buildSummary(
                    for: snapshot, mode: .pre, language: lang.language
                )
                let report = try await service.analyze(
                    mode: .pre, summary: summary, session: supabaseSession
                )
                result = .success(report)
            } catch {
                result = .failure(error)
            }
            try? await minHold

            analyzing = false
            switch result {
            case .success(let report):
                aiPreComment = report
            case .failure:
                analysisFailed = true
            }
        }
    }

    private func save() {
        let entry = currentEntry(status: .upcoming)
        matches.save(entry)
        // Schedule the "how did it go? add the result" reminder.
        NotificationManager.shared.scheduleUpcomingMatchResultReminder(
            entryID: entry.id,
            opponentName: entry.opponentName,
            matchDate: entry.date
        )
        Haptics.confirm()
        onDone()
    }

    private var canSave: Bool {
        !plan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func currentEntry(status: MatchStatus) -> MatchEntry {
        MatchEntry(
            id: entryID,
            date: date,
            opponentName: opponentName.trimmingCharacters(in: .whitespacesAndNewlines),
            surface: surface,
            status: status,
            result: nil,
            score: "",
            preMatchNotes: plan.trimmingCharacters(in: .whitespacesAndNewlines),
            aiPreComment: aiPreComment,
            isQuickLog: false,
            isDraft: false
        )
    }

    /// Mint or reuse a Supabase session with a few retries — mirrors
    /// SwingAnalysisView.
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
        throw lastError ?? RemoteDataError.missingConfiguration
    }
}
