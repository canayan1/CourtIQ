import SwiftUI

/// Post-match (played) capture. Asks whether the user had a plan before the
/// match (and captures it if so), then result (required), score, ratings,
/// and post-match notes / takeaway. On save → compound AI analysis (with a
/// ~12s minimum analyzing animation) → stores `aiReport`, saves as
/// `.completed`. If analysis fails the entry is still saved; a retry
/// affordance re-runs analysis.
struct MatchPlayedFormView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    /// Optional date to seed the date picker with (e.g. a tapped calendar day).
    var initialDate: Date? = nil

    let onDone: () -> Void

    private enum Phase {
        case form
        case analyzing
        case reveal(report: String?)   // nil report → failed, show retry
    }

    @State private var phase: Phase = .form

    // Plan
    @State private var hadPlan: Bool = false
    @State private var plan: String = ""

    // Meta
    @State private var date: Date = Date()
    @State private var opponentName: String = ""
    @State private var tournament: String = ""
    @State private var surface: MatchSurface = .hard
    @State private var result: MatchResult = .won
    @State private var score: String = ""

    // Ratings
    @State private var serve = 3
    @State private var ret = 3
    @State private var movement = 3
    @State private var mental = 3

    // Notes
    @State private var postMatchNotes: String = ""
    @State private var takeaway: String = ""

    @FocusState private var focusedField: Field?
    private enum Field { case opponent, score, plan, post, takeaway }

    private let service = MatchAnalysisService()
    private let entryID = UUID().uuidString

    var body: some View {
        Group {
            switch phase {
            case .form:
                form
            case .analyzing:
                MatchAnalyzingView(
                    title: lang.t("matches.ai_report_analyzing_title"),
                    stepLabels: analyzingSteps
                )
            case .reveal(let report):
                revealStep(report: report)
            }
        }
        .onAppear { if let initialDate { date = initialDate } }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                planSection

                // Match details — grouped under one header.
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(lang.t("matches.section_details"))
                    metaBlock
                }

                // Ratings — grouped under one header.
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(lang.t("matches.section_ratings"))
                    MatchFormComponents.RatingsBlock(
                        serve: $serve, ret: $ret, movement: $movement, mental: $mental
                    )
                }

                MatchFormComponents.NoteField(
                    iconName: "checkmark.seal.fill",
                    iconColor: AppPalette.moss,
                    label: lang.t("matches.post_match_label"),
                    placeholder: lang.t("matches.post_match_placeholder"),
                    text: $postMatchNotes
                )
                .focused($focusedField, equals: .post)

                takeawayBlock

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
                Button(lang.t("common.save")) { startAnalysis() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("common.done")) { focusedField = nil }
            }
        }
    }

    // MARK: - "Did you have a plan?"

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundStyle(AppPalette.clay)
                    .font(.subheadline.weight(.bold))
                Eyebrow(lang.t("matches.had_plan_label"))
            }

            HStack(spacing: 0) {
                planToggleButton(label: lang.t("common.yes"), isOn: hadPlan) {
                    hadPlan = true
                }
                planToggleButton(label: lang.t("common.no"), isOn: !hadPlan) {
                    hadPlan = false
                    plan = ""
                }
            }
            .padding(4)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if hadPlan {
                MatchFormComponents.NoteField(
                    iconName: "list.bullet.clipboard",
                    iconColor: AppPalette.clay,
                    label: lang.t("matches.pre_match_label"),
                    placeholder: lang.t("matches.pre_match_placeholder"),
                    text: $plan,
                    lineLimit: 4
                )
                .focused($focusedField, equals: .plan)
            }
        }
    }

    private func planToggleButton(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? .white : AppPalette.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? AppPalette.clay : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meta block

    private var metaBlock: some View {
        VStack(spacing: 14) {
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            MatchFormComponents.BoxedField(
                placeholder: lang.t("matches.opponent_placeholder"),
                text: $opponentName
            )

            MatchFormComponents.BoxedField(
                placeholder: lang.t("matches.tournament_placeholder"),
                text: $tournament
            )

            HStack(spacing: 12) {
                MatchFormComponents.SurfacePicker(surface: $surface)
                MatchFormComponents.ResultPicker(result: $result)
            }

            MatchFormComponents.BoxedField(
                placeholder: lang.t("matches.score_placeholder"),
                text: $score,
                monospaced: true
            )
        }
    }

    // MARK: - Takeaway

    private var takeawayBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppPalette.gold)
                    .font(.subheadline.weight(.bold))
                Eyebrow(lang.t("matches.takeaway_label"))
            }
            TextField(lang.t("matches.takeaway_placeholder"), text: $takeaway, axis: .vertical)
                .focused($focusedField, equals: .takeaway)
                .lineLimit(2, reservesSpace: true)
                .font(.subheadline)
                .padding(14)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: takeaway) { _, newValue in
                    if newValue.count > 200 { takeaway = String(newValue.prefix(200)) }
                }
        }
    }

    // MARK: - Reveal step

    private func revealStep(report: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let report {
                    MatchAnalysisCard(title: lang.t("matches.ai_report_title"), report: report)
                } else {
                    failureCard
                }

                Button {
                    Haptics.tap()
                    onDone()
                } label: {
                    Text(lang.t("common.done"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("matches.ai_failed_title"))
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text(lang.t("matches.ai_failed_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startAnalysis()
            } label: {
                Label(lang.t("matches.ai_retry"), systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.clay)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var analyzingSteps: [String] {
        [
            lang.t("matches.ai_step_reading_match"),
            lang.t("matches.ai_step_ratings"),
            lang.t("matches.ai_step_patterns"),
            lang.t("matches.ai_step_writing")
        ]
    }

    // MARK: - Save + analysis

    /// Persist the entry as completed (so it's never lost even if analysis
    /// fails) then run compound analysis with a ~12s minimum animation.
    /// Re-runnable: the failure card calls it again to retry on the
    /// already-saved entry.
    private func startAnalysis() {
        let entry = buildEntry(report: matches.entry(withID: entryID)?.aiReport)
        matches.save(entry)
        focusedField = nil
        phase = .analyzing

        Task {
            // Run the AI call and a SHORT minimum floor concurrently. The total
            // analyzing time = max(callTime, 3.5s): the labor-illusion still
            // reads, but a fast network reveals as soon as the floor elapses
            // instead of always waiting a hard 12s.
            async let minHold: Void = Task.sleep(nanoseconds: 3_500_000_000) as Void
            let result: Result<String, Error>
            do {
                let supabaseSession = try await ensureSessionWithRetry()
                let summary = MatchAnalysisService.buildSummary(
                    for: entry, mode: .compound, language: lang.language
                )
                let report = try await service.analyze(
                    mode: .compound, summary: summary, session: supabaseSession
                )
                result = .success(report)
            } catch {
                result = .failure(error)
            }
            try? await minHold

            switch result {
            case .success(let report):
                // Persist the report onto the saved entry.
                var updated = entry
                updated.aiReport = report
                matches.save(updated)
                Haptics.success()
                phase = .reveal(report: report)
            case .failure:
                Haptics.error()
                phase = .reveal(report: nil)
            }
        }
    }

    private func buildEntry(report: String?) -> MatchEntry {
        MatchEntry(
            id: entryID,
            date: date,
            opponentName: opponentName.trimmingCharacters(in: .whitespacesAndNewlines),
            tournament: tournament.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : tournament.trimmingCharacters(in: .whitespacesAndNewlines),
            surface: surface,
            status: .completed,
            result: result,
            score: score.trimmingCharacters(in: .whitespacesAndNewlines),
            serveRating: serve,
            returnRating: ret,
            movementRating: movement,
            mentalRating: mental,
            preMatchNotes: hadPlan ? plan.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            postMatchNotes: postMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            takeaway: takeaway.trimmingCharacters(in: .whitespacesAndNewlines),
            aiReport: report,
            hadPlan: hadPlan,
            isQuickLog: false,
            isDraft: false
        )
    }

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
