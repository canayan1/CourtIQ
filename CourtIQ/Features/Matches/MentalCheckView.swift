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
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
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

    /// A labeled 1–5 selector. Mirrors `MatchFormComponents.RatingsBlock`'s
    /// dot control so it shares the app's rating language; ≥44pt tap targets.
    private func ratingRow(icon: String, iconColor: Color, label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline.weight(.bold))
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value.wrappedValue) of 5")
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
                let supabaseSession = try await ensureSessionWithRetry()
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
        let ctx = context.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ctx.isEmpty { lines.append("Context: \(ctx)") }
        return lines.joined(separator: "\n")
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
