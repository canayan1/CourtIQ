import SwiftUI

/// A lightweight PRE-MATCH mental check. The player gives three fast 1–5
/// self-ratings (energy, confidence, nerves) plus an optional one-line
/// context, then taps a primary button to get a short AI pre-match mental
/// routine.
///
/// Reuses the existing match plumbing end-to-end:
/// - `MatchAnalysisService` with `mode: .mental` (POSTs `{mode, summary}` to
///   the `match-analysis` edge function, attaching the Supabase session).
/// - `MatchAnalyzingView` for the labor-illusion loading beat (short ~3.5s
///   floor like the match flow).
/// - `MatchAnalysisCard` to render the AI plan with share/copy.
///
/// No persistence — the last result is only held in memory for the life of
/// the sheet. Honors Reduce Motion and Dynamic Type; all targets ≥44pt.
struct MentalCheckView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case form
        case analyzing
        case reveal(report: String?)   // nil report → failed, show retry
    }

    @State private var phase: Phase = .form

    // 1–5 inputs (default to a neutral 3).
    @State private var energy = 3
    @State private var confidence = 3
    @State private var nerves = 3
    @State private var context: String = ""

    /// First-run consent before any data is sent to Google (Gemini).
    @State private var showConsent = false

    /// Presents the deterministic, offline breathing exercise.
    @State private var showBreathing = false

    @FocusState private var contextFocused: Bool

    private let service = MatchAnalysisService()

    var body: some View {
        Group {
            switch phase {
            case .form:
                form
            case .analyzing:
                MatchAnalyzingView(
                    title: lang.t("mental.analyzing_title"),
                    stepLabels: analyzingSteps
                )
            case .reveal(let report):
                revealStep(report: report)
            }
        }
        .navigationTitle(lang.t("mental.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        // First-run disclosure before any answer leaves the device.
        .sheet(isPresented: $showConsent) {
            NavigationStack {
                AIConsentView(spec: .mental) { startAnalysis() }
            }
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(lang.t("mental.eyebrow"))
                    Text(lang.t("mental.headline"))
                        .appFont(26, weight: .heavy)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lang.t("mental.subhead"))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 14) {
                    ratingRow(
                        icon: "bolt.fill",
                        iconColor: AppPalette.gold,
                        label: lang.t("mental.energy"),
                        value: $energy
                    )
                    ratingRow(
                        icon: "flame.fill",
                        iconColor: AppPalette.clay,
                        label: lang.t("mental.confidence"),
                        value: $confidence
                    )
                    ratingRow(
                        icon: "wind",
                        iconColor: AppPalette.moss,
                        label: lang.t("mental.nerves"),
                        value: $nerves
                    )
                }
                .padding(18)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(AppPalette.inkSoft)
                            .font(.subheadline.weight(.bold))
                        Text(lang.t("mental.context_label"))
                            .font(.caption.weight(.heavy))
                            .tracking(0.6)
                            .foregroundStyle(AppPalette.inkSoft)
                            .textCase(.uppercase)
                    }
                    TextField(lang.t("mental.context_placeholder"), text: $context, axis: .vertical)
                        .focused($contextFocused)
                        .lineLimit(2, reservesSpace: true)
                        .font(.subheadline)
                        .padding(14)
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: context) { _, newValue in
                            if newValue.count > 160 { context = String(newValue.prefix(160)) }
                        }
                }

                Button {
                    Haptics.tap()
                    startAnalysis()
                } label: {
                    Text(lang.t("mental.get_plan_cta"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AppPalette.cream)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("common.cancel")) { dismiss() }
                    .foregroundStyle(AppPalette.inkSoft)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("common.done")) { contextFocused = false }
            }
        }
    }

    /// A labeled 1–5 selector. The label sits on its OWN line above the dot
    /// row: five 44pt targets take ~244pt, which on a narrow phone left the
    /// side-by-side label only ~90pt and squeezed localized words ("Özgüven",
    /// "Gerginlik") into an unreadable wrap. Stacking keeps the label full
    /// width and readable in any language. ≥44pt tap targets throughout.
    private func ratingRow(icon: String, iconColor: Color, label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline.weight(.bold))
                    .frame(width: 22)
                Text(label)
                    .appFont(14, weight: .bold)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { dot in
                    Button {
                        Haptics.tap()
                        value.wrappedValue = dot
                    } label: {
                        Circle()
                            .fill(value.wrappedValue >= dot ? AppPalette.clay : AppPalette.sand)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(
                                        value.wrappedValue == dot
                                            ? AppPalette.ink.opacity(0.5)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                            // Pad the hit area to ≥44pt without growing the dot.
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value.wrappedValue)")
    }

    // MARK: - Reveal step

    private func revealStep(report: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let report {
                    MatchAnalysisCard(title: lang.t("mental.plan_title"), report: report)
                } else {
                    failureCard
                }

                // A concrete thing to DO with the state they just reported —
                // works offline even if the AI routine failed.
                breathingCTA

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
        .sheet(isPresented: $showBreathing) {
            NavigationStack {
                BreathingExerciseView(pattern: breathingPattern)
                    .environmentObject(lang)
            }
        }
    }

    /// Tap-to-start card for the breathing exercise. The pattern is chosen
    /// from THIS player's inputs (see `breathingPattern`), so the "why" line
    /// tells them it's tailored — not a generic add-on.
    private var breathingCTA: some View {
        let pattern = breathingPattern
        return Button {
            Haptics.tap()
            showBreathing = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppPalette.moss.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: "wind")
                        .appFont(18, weight: .bold, design: .default)
                        .foregroundStyle(AppPalette.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("breathing.cta"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                    Text(lang.t(pattern.whyKey))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.moss.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Maps the three self-ratings to a breathing pattern: high nerves → long
    /// exhale to settle; low energy → brisk even breath to lift; otherwise a
    /// balanced box breath for steady focus.
    private var breathingPattern: BreathingPattern {
        if nerves >= 4 {
            return BreathingPattern(titleKey: "breathing.pattern_calm", whyKey: "breathing.why_calm",
                                    inhale: 4, hold: 4, exhale: 7, holdOut: 0, cycles: 4)
        } else if energy <= 2 {
            return BreathingPattern(titleKey: "breathing.pattern_energize", whyKey: "breathing.why_energize",
                                    inhale: 3, hold: 0, exhale: 3, holdOut: 0, cycles: 5)
        } else {
            return BreathingPattern(titleKey: "breathing.pattern_focus", whyKey: "breathing.why_focus",
                                    inhale: 4, hold: 4, exhale: 4, holdOut: 4, cycles: 4)
        }
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("mental.failed_title"))
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            Text(lang.t("mental.failed_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startAnalysis()
            } label: {
                Label(lang.t("mental.retry"), systemImage: "arrow.counterclockwise")
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
            lang.t("mental.step_reading"),
            lang.t("mental.step_settling"),
            lang.t("mental.step_writing")
        ]
    }

    // MARK: - Analysis

    /// Build a compact labeled summary and run the `.mental` analysis with a
    /// short minimum-display floor. Re-runnable from the failure card.
    private func startAnalysis() {
        contextFocused = false
        // Gate the third-party send on explicit consent.
        guard AIConsent.isAccepted(.mental) else { showConsent = true; return }
        phase = .analyzing

        Task {
            // Run the AI call and a SHORT minimum floor concurrently so the
            // labor-illusion still reads but a fast network reveals quickly.
            async let minHold: Void = Task.sleep(nanoseconds: 3_500_000_000) as Void
            let result: Result<String, Error>
            do {
                let supabaseSession = try await session.ensureSessionWithRetry()
                let summary = buildSummary()
                let report = try await service.analyze(
                    mode: .mental, summary: summary, session: supabaseSession
                )
                result = .success(report)
            } catch {
                result = .failure(error)
            }
            try? await minHold

            switch result {
            case .success(let report):
                Haptics.success()
                phase = .reveal(report: report)
            case .failure:
                Haptics.error()
                phase = .reveal(report: nil)
            }
        }
    }

    /// Compact summary string, e.g.
    /// "Energy 4/5, Confidence 2/5, Nerves 4/5. Context: …" plus a language
    /// hint so the function answers in the player's language.
    private func buildSummary() -> String {
        var lines: [String] = []
        lines.append("Language: \(lang.language.rawValue)")
        lines.append("Energy \(energy)/5, Confidence \(confidence)/5, Nerves \(nerves)/5.")
        // Ground the routine in the player's OWN profile so the plan is
        // specific to them — a nervy counterpuncher gets different advice than
        // a confident aggressive baseliner — instead of a generic pep-talk.
        // All read locally from the profile the user already built (rule-based,
        // no extra AI spend beyond a handful of tokens); the edge function
        // takes free-text `summary`, so nothing to deploy.
        if let profile = TennisProfileStore.shared.profile {
            let r = profile.result
            lines.append("Player level: \(String(describing: r.level)).")
            lines.append("Play style: \(String(describing: r.archetype)).")
            if let growth = r.growthAreas.first {
                lines.append("Top growth area: \(String(describing: growth)).")
            }
            lines.append("Under pressure tends to: \(String(describing: profile.answers.pressure)).")
        }
        let ctx = context.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ctx.isEmpty { lines.append("Context: \(ctx)") }
        return lines.joined(separator: "\n")
    }

}

// MARK: - Breathing exercise

/// A breathing rhythm in seconds. Phases with a 0 duration are skipped, so a
/// "4 · 4 · 7" calm breath (no hold-out) and a "4 · 4 · 4 · 4" box breath both
/// use the same type.
struct BreathingPattern: Equatable {
    let titleKey: String
    let whyKey: String
    let inhale: Double
    let hold: Double
    let exhale: Double
    let holdOut: Double
    let cycles: Int
}

/// Deterministic, offline breathing coach — the pattern is chosen from the
/// player's mental-check inputs (`MentalCheckView.breathingPattern`), so it
/// feels personal without spending anything. Pure tap + shape + color: an orb
/// that expands on the inhale and contracts on the exhale, a phase word, and
/// round dots per completed cycle. Honors Reduce Motion (smaller scale delta)
/// and the silent switch (no audio). No persistence.
struct BreathingExerciseView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pattern: BreathingPattern

    @State private var scale: CGFloat = 0.55
    @State private var glow: Double = 0.15
    @State private var stepLabel: String = ""
    @State private var currentCycle: Int = 0
    @State private var running = false
    @State private var finished = false
    @State private var runTask: Task<Void, Never>? = nil

    private var minScale: CGFloat { reduceMotion ? 0.72 : 0.55 }
    private let maxScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            VStack(spacing: 22) {
                header
                Spacer(minLength: 0)
                orb
                Text(finished ? lang.t("breathing.done") : stepLabel)
                    .appFont(22, weight: .heavy)
                    .foregroundStyle(AppPalette.clayText)
                    .animation(.easeInOut(duration: 0.2), value: stepLabel)
                    .animation(.easeInOut(duration: 0.2), value: finished)
                cycleDots
                Spacer(minLength: 0)
                controls
            }
            .padding(24)
        }
        .navigationTitle(lang.t(pattern.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.done")) { stop(); dismiss() }
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .onAppear { if !running && !finished { start() } }
        .onDisappear { runTask?.cancel() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(patternShape)
                .appFont(13, weight: .heavy)
                .tracking(1.4)
                .foregroundStyle(AppPalette.inkSoft)
            Text(lang.t(pattern.whyKey))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    /// "4 · 4 · 7" shape straight from the numbers (no localization needed).
    private var patternShape: String {
        var parts = [Int(pattern.inhale)]
        if pattern.hold > 0 { parts.append(Int(pattern.hold)) }
        parts.append(Int(pattern.exhale))
        if pattern.holdOut > 0 { parts.append(Int(pattern.holdOut)) }
        return parts.map(String.init).joined(separator: " · ")
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(AppPalette.clay.opacity(0.08 + glow * 0.22))
                .frame(width: 240, height: 240)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppPalette.clay.opacity(0.85), AppPalette.clay.opacity(0.45)],
                        center: .center, startRadius: 4, endRadius: 120
                    )
                )
                .frame(width: 180, height: 180)
                .scaleEffect(scale)
                .shadow(color: AppPalette.clay.opacity(0.35), radius: 24, y: 8)
        }
        .frame(height: 260)
        .accessibilityHidden(true)
    }

    private var cycleDots: some View {
        HStack(spacing: 8) {
            ForEach(1...max(1, pattern.cycles), id: \.self) { i in
                Circle()
                    .fill(i <= currentCycle ? AppPalette.clay : AppPalette.sand)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var controls: some View {
        if finished {
            HStack(spacing: 12) {
                Button { start() } label: {
                    Label(lang.t("breathing.again"), systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.clay)

                Button { dismiss() } label: {
                    Text(lang.t("breathing.finish"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
            }
        } else {
            Button { stop(); dismiss() } label: {
                Text(lang.t("breathing.stop"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.inkSoft)
        }
    }

    // MARK: - Run loop

    private func start() {
        runTask?.cancel()
        scale = minScale
        glow = 0.15
        finished = false
        currentCycle = 0
        running = true
        runTask = Task { await runLoop() }
    }

    private func stop() {
        running = false
        runTask?.cancel()
        runTask = nil
    }

    @MainActor
    private func runLoop() async {
        guard pattern.cycles > 0 else { return }
        for cycle in 1...pattern.cycles {
            if Task.isCancelled { return }
            currentCycle = cycle

            await breathe(lang.t("breathing.inhale"), duration: pattern.inhale,
                          target: maxScale, glowTarget: 0.5, haptic: true)
            if Task.isCancelled { return }
            if pattern.hold > 0 {
                await breathe(lang.t("breathing.hold"), duration: pattern.hold,
                              target: maxScale, glowTarget: 0.5, haptic: false)
                if Task.isCancelled { return }
            }
            await breathe(lang.t("breathing.exhale"), duration: pattern.exhale,
                          target: minScale, glowTarget: 0.15, haptic: true)
            if Task.isCancelled { return }
            if pattern.holdOut > 0 {
                await breathe(lang.t("breathing.hold"), duration: pattern.holdOut,
                              target: minScale, glowTarget: 0.15, haptic: false)
                if Task.isCancelled { return }
            }
        }
        finished = true
        running = false
        stepLabel = ""
        Haptics.success()
    }

    @MainActor
    private func breathe(_ label: String, duration: Double, target: CGFloat,
                         glowTarget: Double, haptic: Bool) async {
        stepLabel = label
        if haptic { Haptics.tap() }
        withAnimation(.easeInOut(duration: duration)) {
            scale = target
            glow = glowTarget
        }
        try? await Task.sleep(nanoseconds: UInt64(max(0.1, duration) * 1_000_000_000))
    }
}
