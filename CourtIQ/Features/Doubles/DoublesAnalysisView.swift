import SwiftUI

/// Runs a compatibility analysis for one partner: a ~12s labor-illusion loading
/// screen (reusing `MatchAnalyzingView`) with the network call running
/// concurrently and held for a minimum window, then a report screen with the big
/// score + the AI report (reusing `SwingReportText`). Saves a `DoublesReport` on
/// success. On failure: a friendly alert with retry.
struct DoublesAnalysisView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    let partner: DoublesPartner

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private let service = DoublesService()
    @StateObject private var store = DoublesStore.shared

    private enum Phase {
        case analyzing
        case result(text: String, score: Int?)
    }

    @State private var phase: Phase = .analyzing
    @State private var errorMessage: String?
    @State private var showError = false

    /// Minimum time we hold the analyzing screen so it always feels like real
    /// work (matches the swing/match labor-illusion convention).
    private let minimumDisplay: UInt64 = 12_000_000_000

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await runAnalysis() }
        .alert(copy.errorTitle, isPresented: $showError) {
            Button(copy.retryCTA) { Task { await runAnalysis() } }
            Button(copy.cancelCTA, role: .cancel) { dismiss() }
        } message: {
            Text(errorMessage ?? copy.errorGeneric)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .analyzing:
            MatchAnalyzingView(title: copy.analyzingTitle, stepLabels: copy.analyzingSteps)
        case .result(let text, let score):
            resultStep(text: text, score: score)
        }
    }

    private func resultStep(text: String, score: Int?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let score {
                    DoublesScoreView(score: score, copy: copy)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.headline).foregroundStyle(AppPalette.clay)
                    Text(copy.reportTitle)
                        .font(.title3.bold()).foregroundStyle(AppPalette.ink)
                }

                SwingReportText(text: text)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    dismiss()
                } label: {
                    Text(doneTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.clay)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var doneTitle: String {
        lang.language == .turkish ? "Bitti" : "Done"
    }

    // MARK: - Actions

    private func runAnalysis() async {
        phase = .analyzing
        do {
            // Run the network call concurrently with a minimum-display timer so
            // the loading animation always plays for ~12s (labor illusion).
            async let minimum: Void = Task.sleep(nanoseconds: minimumDisplay)
            let supabaseSession = try await ensureSessionWithRetry()
            let result = try await service.analyze(
                partner: partner,
                language: lang.language,
                session: supabaseSession
            )
            try? await minimum

            // Persist the report so it shows up in the partner's history.
            store.addReport(
                DoublesReport(partnerId: partner.id, score: result.score, reportText: result.report)
            )
            phase = .result(text: result.report, score: result.score)
            // Peak moment: the compatibility score just landed.
            Haptics.success()
        } catch RemoteDataError.missingConfiguration {
            presentError(copy.errorConnect)
        } catch {
            let message = (error as? RemoteDataError)?.errorDescription ?? copy.errorGeneric
            presentError(message)
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    /// Mint or reuse a Supabase session, retrying a few times so a single
    /// transient blip doesn't surface as a failure — mirrors the swing/match flow.
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
