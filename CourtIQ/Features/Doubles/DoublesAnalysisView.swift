import SwiftUI

/// Runs a compatibility analysis for one partner: a brief labor-illusion loading
/// screen (reusing `MatchAnalyzingView`) with the network call running
/// concurrently and held for a minimum window, then a report screen with the big
/// score + the AI report (reusing `SwingReportText`). Saves a `DoublesReport` on
/// success. On failure: a friendly alert with retry.
///
/// The analyze orchestration lives in `DoublesAnalysisViewModel` so the View
/// stays declarative and the flow is unit-testable with a stub service.
struct DoublesAnalysisView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    let partner: DoublesPartner

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    @State private var vm = DoublesAnalysisViewModel()

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await run() }
        // First-run disclosure before any profile data leaves the device.
        // Declining ("Not now") pops back instead of stranding the spinner.
        .sheet(isPresented: $vm.showConsent, onDismiss: {
            if !AIConsent.isAccepted(.doubles) { dismiss() }
        }) {
            NavigationStack {
                AIConsentView(spec: .doubles) { Task { await run() } }
            }
        }
        .alert(copy.errorTitle, isPresented: $vm.showError) {
            Button(copy.retryCTA) { Task { await run() } }
            Button(copy.cancelCTA, role: .cancel) { dismiss() }
        } message: {
            Text(vm.errorMessage ?? copy.errorGeneric)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
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

    private func run() async {
        await vm.run(
            partner: partner,
            language: lang.language,
            copy: copy,
            ensureSession: { try await session.ensureSessionWithRetry() }
        )
    }
}

// MARK: - ViewModel

/// Abstraction over the doubles analysis network call so the view model can be
/// unit-tested with a stub. `DoublesService` is the production implementation.
protocol DoublesAnalyzing {
    func analyze(
        partner: DoublesPartner,
        language: AppLanguage,
        session: SupabaseSession
    ) async throws -> (report: String, score: Int?)
}

extension DoublesService: DoublesAnalyzing {}

/// Owns the doubles-analysis flow — consent gate, labor-illusion loading window,
/// session retry, service call, persistence, and error mapping — so the View is
/// purely declarative. Inject a stub `DoublesAnalyzing` (and `minimumDisplay: 0`)
/// to unit-test the orchestration without the network or the labor-illusion wait.
@MainActor @Observable
final class DoublesAnalysisViewModel {
    enum Phase {
        case analyzing
        case result(text: String, score: Int?)
    }

    private(set) var phase: Phase = .analyzing
    var errorMessage: String?
    var showError = false
    /// First-run consent before any profile data is sent to Google (Gemini).
    var showConsent = false

    private let service: DoublesAnalyzing
    private let store: DoublesStore
    /// Minimum time we hold the analyzing screen so it always feels like real
    /// work (matches the swing/match labor-illusion convention).
    private let minimumDisplay: UInt64

    init(
        service: DoublesAnalyzing? = nil,
        store: DoublesStore = .shared,
        minimumDisplay: UInt64 = 3_500_000_000
    ) {
        // Construct the default service inside the (main-actor) init body —
        // its initializer is @MainActor-isolated and can't be a default arg.
        self.service = service ?? DoublesService()
        self.store = store
        self.minimumDisplay = minimumDisplay
    }

    /// `ensureSession` is passed in by the View (`session.ensureSessionWithRetry`)
    /// so the model doesn't depend on `UserSessionManager` and stays testable.
    func run(
        partner: DoublesPartner,
        language: AppLanguage,
        copy: DoublesCopy,
        ensureSession: () async throws -> SupabaseSession
    ) async {
        // Gate the third-party send on explicit consent (first run only).
        guard AIConsent.isAccepted(.doubles) else { showConsent = true; return }
        phase = .analyzing
        do {
            // Run the network call concurrently with a minimum-display timer so
            // the loading animation plays for a short beat (labor illusion).
            async let minimum: Void = Task.sleep(nanoseconds: minimumDisplay)
            let supabaseSession = try await ensureSession()
            let result = try await service.analyze(
                partner: partner,
                language: language,
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
            present(copy.errorConnect)
        } catch {
            present((error as? RemoteDataError)?.errorDescription ?? copy.errorGeneric)
        }
    }

    private func present(_ message: String) {
        errorMessage = message
        showError = true
    }
}
