import SwiftUI
import UIKit

/// The AI Swing Analysis flow:
///  1. Pick stroke + handedness (+ a "how to film" tip).
///  2. Record a swing or choose a clip from the library.
///  3. (Consent gate on first run) → loading → coaching notes.
struct SwingAnalysisView: View {
    /// A clip handed in from elsewhere (Rally Cam records one). Routed through
    /// `handlePicked` on appear, so it passes the SAME consent + premium gates
    /// as a clip picked from the library — no side door into the paid flow.
    var preloadedClip: URL? = nil

    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    // Forwarded into the "Discuss with Coach" sheet so AICoachThreadView has the
    // full context it needs. (aiClient isn't injected at the app root — only in
    // the Coach tab — so it's referenced via its shared singleton instead.)
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    private var copy: SwingAnalysisCopy { SwingAnalysisCopy(lang: lang.language) }

    // MARK: Flow state

    @State private var stroke: SwingStroke = .forehand
    @State private var handedness: SwingHandedness = .right
    @State private var vm = SwingAnalysisViewModel(phase: SwingAnalysisView.launchPhase)

    /// Initial step for the view model. App Store screenshot harness (launch-arg
    /// gated, DEBUG only): start in the result state showing a realistic sample
    /// analysis so the capture shows a finished coaching readout — no video, no
    /// network call. Release builds always start at `.setup`.
    private static var launchPhase: SwingAnalysisViewModel.Phase {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-previewSwing")
            ? .result(SwingAnalysisResult(analysis: previewSampleAnalysis, score: 82,
                                          measuredCount: 12, overheadRatio: 0.08, mismatch: false))
            : .setup
#else
        .setup
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
    @State private var showPaywall = false

    @State private var errorMessage: String?
    @State private var showError = false

    @State private var showHistory = false
    @State private var coachSeed: CoachSeed?

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { consumePreloadedClip() }
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
        // Camera / library picker. The next step (consent gate or analysis) is
        // started in `onDismiss` — never synchronously inside the picker
        // callback — so the picker sheet is fully gone before the consent sheet
        // appears. Two sheets transitioning in the same runloop tick race, and
        // the consent sheet silently fails to present: the flow then looked like
        // it "auto-closed" back to the capture step right after a clip was picked.
        .sheet(item: $pickerSource, onDismiss: continueAfterPick) { source in
            VideoPicker(sourceType: source) { url in
                pendingVideoURL = url   // nil if the user cancelled
                pickerSource = nil      // dismiss → fires onDismiss
            }
            .ignoresSafeArea()
        }
        // First-run consent before any frame leaves the device.
        .sheet(isPresented: $showConsent) {
            NavigationStack {
                AIConsentView(spec: .swing, onAccepted: {
                    // Consent recorded → continue with the clip we held back.
                    if let url = pendingVideoURL {
                        startAnalysis(videoURL: url)
                    }
                })
            }
        }
        .alert(copy.errorTitle, isPresented: $vm.showError) {
            Button(copy.retryCTA) {
                // Route through handlePicked so a retry re-checks consent
                // (e.g. if the consent version was bumped mid-session).
                if let url = pendingVideoURL { handlePicked(url) }
            }
            Button(copy.cancelCTA, role: .cancel) { vm.phase = .capture }
        } message: {
            Text(vm.errorMessage ?? copy.errorGeneric)
        }
        // "Discuss with Coach": open a new AI Coach thread seeded with this
        // analysis so the user can dig into it / push back on the AI's read.
        .sheet(item: $coachSeed) { seed in
            NavigationStack {
                AICoachThreadView(thread: nil, seedDraft: seed.text)
                    .environmentObject(lang)
                    .environmentObject(AIChatClient.shared)
                    .environmentObject(session)
                    .environmentObject(matches)
                    .environmentObject(dailyQuizManager)
                    .environmentObject(drillManager)
            }
        }
        // Freemium gate: AI swing analysis is premium — it spends the PAID
        // Gemini video key. Non-premium users get the paywall instead of the
        // analysis (the AI Coach gates the same way in AICoachTabRoot).
        .sheet(isPresented: $vm.showPaywall) {
            NavigationStack {
                PaywallView(source: "Swing")
                    .environmentObject(lang)
                    .environmentObject(session)
            }
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .setup:        setupStep
        case .capture:      captureStep
        case .analyzing:    analyzingStep
        case .result(let result):          resultStep(result: result)
        }
    }

    // MARK: - Step 1: setup

    private var setupStep: some View {
        // Compact, preselected setup: forehand + right-handed are already
        // chosen, both groups render as chips, and the CTA sits above the
        // fold — the default path to the camera is ONE tap. The filming tip
        // lives on the capture step, where it's actually actionable.
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.pickStrokeTitle)
                        .font(.headline).foregroundStyle(AppPalette.ink)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)],
                              spacing: 8) {
                        // 'session' (mixed strokes) removed from the picker: auto
                        // stroke-classification from video is unreliable (even Pro
                        // mislabels a smash as a serve). Single-stroke modes let the
                        // player DECLARE the stroke, so the AI never invents one.
                        ForEach(SwingStroke.allCases.filter { $0 != .session }) { s in
                            compactChip(copy.stroke(s), isSelected: stroke == s) { stroke = s }
                        }
                    }
                }

                // The storefront moment: two feedback paths, equal billing —
                // instant AI (included) or a real coach ($, 72h). The AI stops
                // being "the promise" and becomes the fast lane.
                VStack(alignment: .leading, spacing: 10) {
                    Text(lang.t("coachreview.path_title"))
                        .font(.headline).foregroundStyle(AppPalette.ink)
                        .padding(.top, 4)

                    Button {
                        Haptics.tap()
                        vm.phase = .capture
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lang.t("coachreview.ai_eyebrow"))
                                    .font(.caption2.weight(.heavy)).kerning(0.8)
                                    .foregroundStyle(.white.opacity(0.85))
                                Text(lang.t("coachreview.ai_title"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(lang.t("coachreview.ai_sub"))
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.top, 4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableCardStyle())

                    CoachReviewInterestCard(source: "setup")
                }
            }
            .padding(20)
        }
    }

    /// Small selectable chip — same selection language as `optionRow` (clay
    /// stroke + fill when picked) at half the vertical cost.
    private func compactChip(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? AppPalette.parchment : AppPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? AppPalette.clay : AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

                Button(copy.backCTA) { vm.phase = .setup }
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
            SwingAnalyzingVisual()
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

    /// "AI is analyzing your swing" loading visual — a cinematic clay-court
    /// action photo with a stylized motion-analysis overlay baked in, plus a
    /// soft gold scan-light that sweeps while we work. Purely atmospheric: the
    /// real result is written coaching, not a live skeleton/measurement readout.
    private struct SwingAnalyzingVisual: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var scan = false
        var body: some View {
            ZStack {
                Image("SwingAnalyzeHero")
                    .resizable()
                    .scaledToFill()
                if !reduceMotion {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, AppPalette.gold.opacity(0.5), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .frame(height: 46)
                            .blendMode(.plusLighter)
                            .position(x: geo.size.width / 2,
                                      y: scan ? geo.size.height * 0.9 : geo.size.height * 0.1)
                            .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                                       value: scan)
                    }
                }
            }
            .aspectRatio(0.8, contentMode: .fit)
            .frame(maxWidth: 300)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand.opacity(0.6), lineWidth: 1))
            .shadow(color: AppPalette.ink.opacity(0.18), radius: 18, y: 10)
            .onAppear { scan = true }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Step 3: result

    private func resultStep(result: SwingAnalysisResult) -> some View {
        let text = result.analysis
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let score = result.score {
                    VStack(spacing: 4) {
                        SwingScoreView(score: score, copy: copy)
                        // K2: transitional honesty badge — the score is still
                        // the model's estimate until the R2 measured rubric.
                        Text(copy.scoreBasisBadge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppPalette.inkSoft.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }

                if result.mismatch {
                    // Server-verified stroke mismatch: the report below is a
                    // redirect, not coaching — frame it before the prose.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(AppPalette.gold)
                            .padding(.top, 1)
                        Text(copy.mismatchNotice)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let facts = measuredFactsLine(result) {
                    // INV-1's UI face: measured facts render as UI, never
                    // trusted out of the model's prose.
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.moss)
                        Text(facts)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppPalette.moss.opacity(0.10))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.headline).foregroundStyle(AppPalette.clay)
                    Text(copy.resultTitle)
                        .font(.title3.bold()).foregroundStyle(AppPalette.ink)
                }

                AIReportSectionsView(text: text)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                primaryButton(discussCoachCTA, systemImage: "bubble.left.and.text.bubble.right.fill") {
                    // The AI Coach is premium; the swing result is reachable on
                    // the free taste, so gate the coach hand-off too (same gate
                    // as the Coach tab — PremiumGate).
                    guard PremiumGate.canUseAICoach(session) else {
                        vm.showPaywall = true
                        return
                    }
                    coachSeed = CoachSeed(text: coachSeedText(for: text))
                }
                .padding(.top, 4)

                CoachReviewInterestCard(
                    source: "result",
                    orderVideoURL: pendingVideoURL,
                    ensureSession: { try await session.ensureSessionWithRetry() }
                )

                secondaryButton(copy.analyzeAnotherCTA, systemImage: "arrow.counterclockwise") {
                    pendingVideoURL = nil
                    vm.phase = .setup
                }

                secondaryButton(copy.viewAllReportsCTA, systemImage: "clock.arrow.circlepath") {
                    showHistory = true
                }
            }
            .padding(20)
        }
    }

    /// One-line "measured facts" caption: strike count + overhead share.
    /// Returns nil when nothing was measured (muted clip) — the UI then shows
    /// nothing rather than a hollow chip.
    private func measuredFactsLine(_ result: SwingAnalysisResult) -> String? {
        guard let count = result.measuredCount else { return nil }
        var parts = [copy.measuredCountChip(count)]
        if let ratio = result.overheadRatio, ratio > 0 {
            parts.append(copy.measuredOverheadChip(Int((ratio * 100).rounded())))
        }
        return parts.joined(separator: " · ")
    }

    private var discussCoachCTA: String {
        lang.language == .turkish ? "Koç'la tartış" : "Discuss with Coach"
    }

    /// Seed text for "Discuss with Coach": frames the report + invites the
    /// player to push back on anything the AI got wrong. Editable before send.
    private func coachSeedText(for analysis: String) -> String {
        let strokeName = copy.stroke(stroke)
        if lang.language == .turkish {
            return "AI \(strokeName) analizimi aldım. İşte yorum:\n\n\(analysis)\n\nBuna göre önce neye odaklanmalıyım ve nasıl çalışmalıyım? Katılmadığım bir yorum varsa tartışalım."
        }
        return "I just got my AI \(strokeName) swing analysis. Here's what it said:\n\n\(analysis)\n\nBased on this, what should I focus on first and how should I drill it? Let's discuss anything that might not be right."
    }

    /// Identifiable wrapper so the "Discuss with Coach" sheet receives the seed
    /// at presentation time — .sheet(item:) avoids the .sheet(isPresented:)
    /// stale-capture where the seed read back empty.
    private struct CoachSeed: Identifiable {
        let id = UUID()
        let text: String
    }

    // MARK: - Actions

    /// Continue once the picker sheet has FULLY dismissed (its `onDismiss`).
    /// Deferring to here — instead of acting synchronously inside the picker
    /// callback — guarantees only one sheet is ever transitioning at a time, so
    /// the consent sheet reliably presents instead of being dropped mid-race.
    private func continueAfterPick() {
        guard let url = pendingVideoURL else { return }   // cancelled → nothing to do
        routeAfterPick(url)
    }

    /// A clip was picked/recorded. Gate on consent before any frame leaves
    /// the device; otherwise go straight to analysis.
    /// Fires once for a clip handed in at init (Rally Cam → AI review).
    private func consumePreloadedClip() {
        guard let preloadedClip, pendingVideoURL == nil,
              case .setup = vm.phase else { return }
        handlePicked(preloadedClip)
    }

    private func handlePicked(_ url: URL) {
        pendingVideoURL = url
        routeAfterPick(url)
    }

    /// Consent-gate router: first run → consent sheet; otherwise analyze.
    private func routeAfterPick(_ url: URL) {
        if AIConsent.isAccepted(.swing) {
            startAnalysis(videoURL: url)
        } else {
            showConsent = true
        }
    }

    private func startAnalysis(videoURL: URL) {
        // The View owns the gate inputs + session bootstrap; the view model owns
        // the flow (gate → loading → analyze → persist → free-taste → errors).
        Task {
            await vm.start(
                videoURL: videoURL,
                stroke: stroke,
                handedness: handedness,
                isPremium: PremiumGate.isPremium(session),
                canAnalyze: PremiumGate.canUseSwingAnalysis(session),
                context: PlayerContext.forSwing(stroke: stroke),
                copy: copy,
                ensureSession: { try await session.ensureSessionWithRetry() }
            )
        }
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
                    .appFont(20, design: .default)
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

// MARK: - ViewModel

/// Abstraction over the swing analysis network call so the view model can be
/// unit-tested with a stub. `SwingAnalysisService` is the production impl.
protocol SwingAnalyzing {
    func analyze(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness?,
        context: String?,
        session: SupabaseSession
    ) async throws -> SwingAnalysisResult
}

extension SwingAnalysisService: SwingAnalyzing {}

/// Owns the swing-analysis flow — premium gate, loading, session retry, service
/// call, persistence, free-taste bookkeeping, and error mapping — so the View
/// stays declarative. `phase` is the screen's step machine: the View drives the
/// setup/capture navigation; this model drives analyzing/result. Inject a stub
/// `SwingAnalyzing` to unit-test the gate + orchestration without the network.
@MainActor @Observable
final class SwingAnalysisViewModel {
    enum Phase {
        case setup        // step 1: stroke + handedness
        case capture      // step 2: record / library
        case analyzing
        case result(SwingAnalysisResult)
    }

    var phase: Phase
    var errorMessage: String?
    var showError = false
    var showPaywall = false

    private let service: SwingAnalyzing

    init(service: SwingAnalyzing? = nil, phase: Phase = .setup) {
        // Construct the default service inside the (main-actor) init body — its
        // initializer is @MainActor-isolated and can't be a default arg.
        self.service = service ?? SwingAnalysisService()
        self.phase = phase
    }

    /// `canAnalyze` is the freemium gate (`PremiumGate.canUseSwingAnalysis`);
    /// `isPremium` distinguishes a paid user from one spending the free taste.
    /// Both — plus `ensureSession` and `context` — are supplied by the View so
    /// the model has no hard dependency on `UserSessionManager` and stays testable.
    func start(
        videoURL: URL,
        stroke: SwingStroke,
        handedness: SwingHandedness,
        isPremium: Bool,
        canAnalyze: Bool,
        context: String?,
        copy: SwingAnalysisCopy,
        ensureSession: () async throws -> SupabaseSession
    ) async {
        guard canAnalyze else { showPaywall = true; return }
        phase = .analyzing
        do {
            let supabaseSession = try await ensureSession()
            let result = try await service.analyze(
                videoURL: videoURL,
                stroke: stroke,
                handedness: handedness,
                context: context,
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
            phase = .result(result)
            // A non-premium player just spent their one free taste.
            if !isPremium { FreeTaste.swingUsed = true }
            // Celebrate the landing of the swing result — the flagship peak
            // moment, mirroring the doubles score reveal.
            Haptics.success()
        } catch let err as SwingFrameExtractor.ExtractionError {
            _ = err
            present(copy.errorTooShort)
        } catch RemoteDataError.missingConfiguration {
            present(copy.errorConnect)
        } catch {
            present((error as? RemoteDataError)?.errorDescription ?? copy.errorGeneric)
        }
    }

    private func present(_ message: String) {
        errorMessage = message
        phase = .capture
        showError = true
    }
}

// MARK: - Coach Review G0 interest card

/// Demand gate for the human Coach Review marketplace (docs/COACH-REVIEW-PLAN.md).
/// No purchase, no upload sharing, no backend — an honest "notify me" that
/// measures whether anyone wants a real coach's review before we build it.
private struct CoachReviewInterestCard: View {
    let source: String
    /// When a clip is in hand (the result screen), the card sells the REAL
    /// paid review instead of a waitlist signup.
    var orderVideoURL: URL? = nil
    var ensureSession: (() async throws -> SupabaseSession)? = nil
    var stroke: SwingStroke = .forehand
    var handedness: SwingHandedness? = nil
    @State private var showOrder = false
    @ObservedObject private var reviewManager = CoachReviewManager.shared
    @EnvironmentObject private var lang: LanguageManager
    @AppStorage("CourtIQ.CoachReview.Interested") private var interested = false
    @State private var showDetails = false
    /// Tier waitlists (locked roster): which future reviewer tiers this user
    /// queued for. Per-tier demand → the owner onboards real coaches to match.
    @State private var joinedTiers: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: "CourtIQ.CoachReview.Tiers") ?? [])

    var body: some View {
        Button {
            Haptics.tap()
            showDetails = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: interested ? "checkmark.seal.fill" : "person.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.goldText)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("coachreview.card_eyebrow"))
                        .font(.caption2.weight(.heavy)).kerning(0.8)
                        .foregroundStyle(AppPalette.goldText)
                    Text(interested ? lang.t("coachreview.card_joined")
                                    : lang.t("coachreview.card_title"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !interested {
                        Text(lang.t("coachreview.card_sub"))
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppPalette.goldText.opacity(0.7))
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.goldTint.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.gold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .sheet(isPresented: $showDetails) { detailsSheet }
        .task {
            await reviewManager.refreshProductAvailability(
                productID: AppConfiguration.shared.coachReviewProductID)
        }
        .navigationDestination(isPresented: $showOrder) {
            if let orderVideoURL, let ensureSession {
                CoachReviewOrderView(videoURL: orderVideoURL,
                                     stroke: stroke,
                                     handedness: handedness,
                                     ensureSession: ensureSession)
            }
        }
    }

    /// True only when we have a clip, a way to authenticate, AND StoreKit
    /// confirms the consumable is live. Until Apple approves the IAP the card
    /// stays an honest waitlist instead of a Buy button that cannot complete.
    private var canOrder: Bool {
        orderVideoURL != nil && ensureSession != nil && reviewManager.productAvailable
    }

    private var detailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(lang.t("coachreview.sheet_title"))
                        .font(.title2.bold())
                        .foregroundStyle(AppPalette.ink)

                    VStack(alignment: .leading, spacing: 12) {
                        bullet("waveform", lang.t("coachreview.point1"))
                        bullet("list.bullet.rectangle", lang.t("coachreview.point2"))
                        bullet("target", lang.t("coachreview.point3"))
                        bullet("clock.badge.checkmark", lang.t("coachreview.point4"))
                    }

                    // Anonymous by design: the founding coach reviews every
                    // video personally, but the persona stays "a real tennis
                    // coach" — no name, no identity (owner's call).
                    Text(lang.t("coachreview.coach_line"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(lang.t("coachreview.price"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.clayText)

                    // The privacy promise, stated BEFORE launch — the policy in
                    // docs/COACH-REVIEW-POLICY.md is the binding source.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppPalette.moss)
                        Text(lang.t("coachreview.privacy"))
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(AppPalette.mossTint.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        Haptics.success()
                        if canOrder {
                            showDetails = false
                            showOrder = true
                            return
                        }
                        if !interested {
                            interested = true
                            AppAnalytics.shared.log(AnalyticsEvent.coachReviewInterest,
                                                    ["source": source])
                        }
                        showDetails = false
                    } label: {
                        Text(canOrder ? lang.t("coachreview.order_cta")
                                      : (interested ? lang.t("coachreview.done")
                                                    : lang.t("coachreview.cta")))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppPalette.clay,
                                        in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableCardStyle())

                    Divider().padding(.vertical, 4)

                    // Locked roster: future reviewer tiers, unlocked by real
                    // demand. HONESTY RULE: tier labels only — no invented
                    // names, faces, or credentials. A tier goes live only when
                    // a real reviewer holding that qualification is onboarded.
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t("coachreview.roster_title"))
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                        tierRow(id: "player", icon: "figure.tennis",
                                title: lang.t("coachreview.tier_player"),
                                sub: lang.t("coachreview.tier_player_sub"),
                                cta: lang.t("coachreview.join_waitlist"))
                        tierRow(id: "level2", icon: "2.circle.fill",
                                title: lang.t("coachreview.tier_level2"),
                                sub: lang.t("coachreview.tier_level2_sub"),
                                cta: lang.t("coachreview.get_quote"))
                        tierRow(id: "level3", icon: "3.circle.fill",
                                title: lang.t("coachreview.tier_level3"),
                                sub: lang.t("coachreview.tier_level3_sub"),
                                cta: lang.t("coachreview.get_quote"))
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t("coachreview.done")) { showDetails = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tierRow(id: String, icon: String, title: String, sub: String, cta: String) -> some View {
        let joined = joinedTiers.contains(id)
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppPalette.inkSoft)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(AppPalette.inkSoft.opacity(0.6))
                }
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button {
                joinTier(id)
            } label: {
                Text(joined ? lang.t("coachreview.on_list") : cta)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(joined ? AppPalette.mossText : .white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(joined ? AppPalette.mossTint : AppPalette.ink,
                                in: Capsule())
            }
            .disabled(joined)
        }
        .padding(12)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }

    private func joinTier(_ id: String) {
        guard !joinedTiers.contains(id) else { return }
        Haptics.success()
        joinedTiers.insert(id)
        UserDefaults.standard.set(Array(joinedTiers), forKey: "CourtIQ.CoachReview.Tiers")
        AppAnalytics.shared.log(AnalyticsEvent.coachReviewInterest,
                                ["source": source, "tier": id])
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
