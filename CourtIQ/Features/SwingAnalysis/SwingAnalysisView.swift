import SwiftUI
import UIKit

/// The AI Swing Analysis flow:
///  1. Pick stroke + handedness (+ a "how to film" tip).
///  2. Record a swing or choose a clip from the library.
///  3. (Consent gate on first run) → loading → coaching notes.
struct SwingAnalysisView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    private var copy: SwingAnalysisCopy { SwingAnalysisCopy(lang: lang.language) }
    private let service = SwingAnalysisService()

    // MARK: Flow state

    private enum Phase {
        case setup        // step 1: stroke + handedness
        case capture      // step 2: record / library
        case analyzing
        case result(text: String, score: Int?)
    }

    @State private var phase: Phase
    @State private var stroke: SwingStroke = .forehand
    @State private var handedness: SwingHandedness = .right

    init() {
#if DEBUG
        // App Store screenshot harness (launch-arg gated): start in the result
        // state showing a realistic sample analysis so the capture shows a
        // finished coaching readout — no video, no network call. Excluded from
        // Release builds.
        if ProcessInfo.processInfo.arguments.contains("-previewSwing") {
            _phase = State(initialValue: .result(text: Self.previewSampleAnalysis, score: 82))
        } else {
            _phase = State(initialValue: .setup)
        }
#else
        _phase = State(initialValue: .setup)
#endif
    }

#if DEBUG
    /// Sample forehand analysis for the App Store screenshot harness only.
    /// Mirrors the live output format: **bold headers** + "•" bullets.
    /// Excluded from Release builds.
    private static let previewSampleAnalysis = """
    **What's working**
    • Your unit turn is early and complete — shoulders and hips coil together as the ball leaves your opponent's strings, which is exactly where racquet-head speed comes from.
    • Semi-western grip is well-suited to your swing path; you're getting clean topspin and a safe net-clearance margin.
    • Good balance through the shot — your head stays still and your eyes track the contact zone rather than drifting up to the target too early.

    **Top fixes**
    • Contact point is creeping a touch late, slightly behind your front hip. Meet the ball a half-step further in front so you can drive through it instead of brushing up the back. Cue: "catch it out front."
    • Your follow-through wraps low across the body. Finish higher — over the opposite shoulder — to add depth and keep the ball heavy under pressure.
    • Footwork into the shot is a little flat-footed. Add a small split-step and a final adjustment step so you load the outside leg and push up through contact rather than reaching with the arm.

    **One thing to try next session**
    • Shadow-swing ten forehands focusing only on contact out in front of your front hip, then feed yourself twenty balls holding that same spacing. Groove the early-and-out-front contact before adding pace — rhythm first, power second.
    """
#endif

    @State private var pickerSource: UIImagePickerController.SourceType?
    @State private var pendingVideoURL: URL?      // selected but awaiting consent
    @State private var showConsent = false

    @State private var errorMessage: String?
    @State private var showError = false

    @State private var showHistory = false

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Label(copy.historyEntryCTA, systemImage: "clock.arrow.circlepath")
                }
                .tint(AppPalette.clay)
            }
        }
        .navigationDestination(isPresented: $showHistory) {
            SwingHistoryView()
        }
        // Camera / library picker.
        .sheet(item: $pickerSource) { source in
            VideoPicker(sourceType: source) { url in
                pickerSource = nil
                if let url { handlePicked(url) }
            }
            .ignoresSafeArea()
        }
        // First-run consent before any frame leaves the device.
        .sheet(isPresented: $showConsent) {
            NavigationStack {
                SwingAnalysisConsentView(onAccepted: {
                    // Consent recorded → continue with the clip we held back.
                    if let url = pendingVideoURL {
                        startAnalysis(videoURL: url)
                    }
                })
            }
        }
        .alert(copy.errorTitle, isPresented: $showError) {
            Button(copy.retryCTA) {
                if let url = pendingVideoURL { startAnalysis(videoURL: url) }
            }
            Button(copy.cancelCTA, role: .cancel) { phase = .capture }
        } message: {
            Text(errorMessage ?? copy.errorGeneric)
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .setup:        setupStep
        case .capture:      captureStep
        case .analyzing:    analyzingStep
        case .result(let text, let score): resultStep(text: text, score: score)
        }
    }

    // MARK: - Step 1: setup

    private var setupStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                kicker(copy.step1Kicker)

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.pickStrokeTitle)
                        .font(.headline).foregroundStyle(AppPalette.ink)
                    ForEach(SwingStroke.allCases) { s in
                        optionRow(copy.stroke(s), isSelected: stroke == s) { stroke = s }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.pickHandednessTitle)
                        .font(.headline).foregroundStyle(AppPalette.ink)
                    ForEach(SwingHandedness.allCases) { h in
                        optionRow(copy.handedness(h), isSelected: handedness == h) { handedness = h }
                    }
                }

                filmingTip

                primaryButton(copy.continueCTA) { phase = .capture }
                    .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var filmingTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "video.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppPalette.moss)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(copy.filmingTipTitle)
                    .font(.caption.weight(.semibold)).foregroundStyle(AppPalette.ink)
                Text(copy.filmingTipBody(stroke))
                    .font(.caption).foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.moss.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.moss.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Step 2: capture

    private var captureStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                kicker(copy.step2Kicker)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.captureTitle)
                        .font(.title3.bold()).foregroundStyle(AppPalette.ink)
                    Text(copy.captureSubtitle)
                        .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                filmingTip

                VStack(spacing: 12) {
                    primaryButton(copy.recordCTA, systemImage: "record.circle") {
                        pickerSource = .camera
                    }
                    secondaryButton(copy.libraryCTA, systemImage: "photo.on.rectangle") {
                        pickerSource = .photoLibrary
                    }
                }
                .padding(.top, 4)

                Button(copy.backCTA) { phase = .setup }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(20)
        }
    }

    // MARK: - Loading

    private var analyzingStep: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(AppPalette.clay)
            Text(copy.analyzingStroke(stroke))
                .font(.headline).foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)
            Text(copy.analyzingSubtitle)
                .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 3: result

    private func resultStep(text: String, score: Int?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let score {
                    SwingScoreView(score: score, copy: copy)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.headline).foregroundStyle(AppPalette.clay)
                    Text(copy.resultTitle)
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

                primaryButton(copy.analyzeAnotherCTA, systemImage: "arrow.counterclockwise") {
                    pendingVideoURL = nil
                    phase = .setup
                }
                .padding(.top, 4)

                secondaryButton(copy.viewAllReportsCTA, systemImage: "clock.arrow.circlepath") {
                    showHistory = true
                }
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    /// A clip was picked/recorded. Gate on consent before any frame leaves
    /// the device; otherwise go straight to analysis.
    private func handlePicked(_ url: URL) {
        pendingVideoURL = url
        if SwingAnalysisConsent.isAccepted {
            startAnalysis(videoURL: url)
        } else {
            showConsent = true
        }
    }

    private func startAnalysis(videoURL: URL) {
        phase = .analyzing
        Task {
            do {
                let supabaseSession = try await ensureSessionWithRetry()
                // Personalize: feed the AI the player's profile + recent scores
                // for this stroke so the coaching references their real game.
                let playerContext = PlayerContext.forSwing(stroke: stroke)
                let result = try await service.analyze(
                    videoURL: videoURL,
                    stroke: stroke,
                    handedness: handedness,
                    context: playerContext,
                    session: supabaseSession
                )
                // Persist the analysis (video on device + report + score) so the
                // user can browse it later from History.
                await SwingAnalysisStore.shared.add(
                    analysis: result.analysis,
                    score: result.score,
                    stroke: stroke,
                    handedness: handedness,
                    videoURL: videoURL
                )
                phase = .result(text: result.analysis, score: result.score)
                // Celebrate the landing of the swing result — the flagship peak
                // moment, mirroring the doubles score reveal.
                Haptics.success()
            } catch let err as SwingFrameExtractor.ExtractionError {
                _ = err
                presentError(copy.errorTooShort)
            } catch RemoteDataError.missingConfiguration {
                presentError(copy.errorConnect)
            } catch {
                // Surface a server-provided message when we have one, else a
                // friendly generic.
                let message = (error as? RemoteDataError)?.errorDescription ?? copy.errorGeneric
                presentError(message)
            }
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        phase = .capture
        showError = true
    }

    /// Mint or reuse a Supabase session, retrying a few times so a single
    /// transient blip (cold auth endpoint / brief network hiccup) doesn't
    /// surface as a failure — mirrors the AI Coach behaviour.
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

    // MARK: - Reusable bits

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(AppPalette.clay)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func optionRow(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.sand)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    private func primaryButton(_ title: String, systemImage: String? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
    }

    private func secondaryButton(_ title: String, systemImage: String? = nil, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.clay)
    }
}

// MARK: - Sheet item conformance

extension UIImagePickerController.SourceType: Identifiable {
    public var id: Int { rawValue }
}
