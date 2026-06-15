import SwiftUI

/// Completes an upcoming match: the user enters result (required), score,
/// ratings, and post-match notes. On save the entry flips to `.completed`
/// and runs compound AI analysis (~12s animation) → stores `aiReport`.
/// The existing plan (`preMatchNotes`) is carried through into the
/// analysis. Mirrors the played-form analysis behaviour.
struct MatchAddResultView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    let entry: MatchEntry

    private enum Phase {
        case form
        case analyzing
        case reveal(report: String?)
    }

    @State private var phase: Phase = .form

    @State private var result: MatchResult = .won
    @State private var score: String = ""
    @State private var serve = 3
    @State private var ret = 3
    @State private var movement = 3
    @State private var mental = 3
    @State private var postMatchNotes: String = ""
    @State private var takeaway: String = ""

    @FocusState private var focusedField: Field?
    private enum Field { case score, post, takeaway }

    private let service = MatchAnalysisService()

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
        .navigationTitle(lang.t("matches.add_result_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !entry.preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    planRecap
                }

                HStack(spacing: 12) {
                    MatchFormComponents.ResultPicker(result: $result)
                    Spacer()
                }

                MatchFormComponents.BoxedField(
                    placeholder: lang.t("matches.score_placeholder"),
                    text: $score,
                    monospaced: true
                )
                .focused($focusedField, equals: .score)

                MatchFormComponents.RatingsBlock(
                    serve: $serve, ret: $ret, movement: $movement, mental: $mental
                )

                MatchFormComponents.NoteField(
                    iconName: "checkmark.seal.fill",
                    iconColor: AppPalette.moss,
                    label: lang.t("matches.post_match_label"),
                    placeholder: lang.t("matches.post_match_placeholder"),
                    text: $postMatchNotes
                )
                .focused($focusedField, equals: .post)

                MatchFormComponents.NoteField(
                    iconName: "lightbulb.fill",
                    iconColor: AppPalette.gold,
                    label: lang.t("matches.takeaway_label"),
                    placeholder: lang.t("matches.takeaway_placeholder"),
                    text: $takeaway,
                    lineLimit: 2
                )
                .focused($focusedField, equals: .takeaway)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(AppPalette.cream)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("common.cancel")) { dismiss() }
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
        .onChange(of: takeaway) { _, newValue in
            if newValue.count > 200 { takeaway = String(newValue.prefix(200)) }
        }
    }

    private var planRecap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lang.t("matches.pre_match_label"))
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
            Text(entry.preMatchNotes)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(AppPalette.clay.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

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
                    dismiss()
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

    private func startAnalysis() {
        let completed = buildCompleted(report: matches.entry(withID: entry.id)?.aiReport)
        matches.save(completed)
        // The "add your result" reminder is no longer needed.
        NotificationManager.shared.cancelUpcomingMatchResultReminder(entryID: entry.id)
        focusedField = nil
        phase = .analyzing

        Task {
            // Run the AI call and a SHORT minimum floor concurrently. Total
            // analyzing time = max(callTime, 3.5s) — keeps the labor-illusion
            // but reveals promptly on a fast network instead of a hard 12s.
            async let minHold: Void = Task.sleep(nanoseconds: 3_500_000_000) as Void
            let result: Result<String, Error>
            do {
                let supabaseSession = try await ensureSessionWithRetry()
                let summary = MatchAnalysisService.buildSummary(
                    for: completed, mode: .compound, language: lang.language
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
                var updated = completed
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

    private func buildCompleted(report: String?) -> MatchEntry {
        var e = entry
        e.status = .completed
        e.result = result
        e.score = score.trimmingCharacters(in: .whitespacesAndNewlines)
        e.serveRating = serve
        e.returnRating = ret
        e.movementRating = movement
        e.mentalRating = mental
        e.postMatchNotes = postMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        e.takeaway = takeaway.trimmingCharacters(in: .whitespacesAndNewlines)
        e.hadPlan = !e.preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        e.aiReport = report
        return e
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
