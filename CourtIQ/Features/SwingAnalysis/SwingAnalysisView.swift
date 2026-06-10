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
        case result(String)
    }

    @State private var phase: Phase = .setup
    @State private var stroke: SwingStroke = .forehand
    @State private var handedness: SwingHandedness = .right

    @State private var pickerSource: UIImagePickerController.SourceType?
    @State private var pendingVideoURL: URL?      // selected but awaiting consent
    @State private var showConsent = false

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
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
        case .result(let text): resultStep(text)
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
                Text(copy.filmingTipBody)
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

    private func resultStep(_ text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.headline).foregroundStyle(AppPalette.clay)
                    Text(copy.resultTitle)
                        .font(.title3.bold()).foregroundStyle(AppPalette.ink)
                }

                AnalysisTextView(text: text)
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
                let analysis = try await service.analyze(
                    videoURL: videoURL,
                    stroke: stroke,
                    handedness: handedness,
                    session: supabaseSession
                )
                phase = .result(analysis)
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
            .font(.caption.weight(.heavy))
            .foregroundStyle(AppPalette.clay)
            .textCase(.uppercase)
            .tracking(0.5)
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
        .buttonStyle(.plain)
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

// MARK: - Markdown-ish renderer

/// Renders the AI analysis text. The function emits **bold headers** and
/// bullet "•" lines. We render line-by-line: blank lines become spacing,
/// bullet lines get a hanging "•", and inline `**bold**` spans are parsed to
/// bold via AttributedString (with a graceful plain-text fallback).
private struct AnalysisTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
    }

    private var lines: [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
    }

    @ViewBuilder
    private func lineView(_ raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 4)
        } else if trimmed.hasPrefix("•") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let body = String(trimmed.dropFirst(trimmed.hasPrefix("•") ? 1 : 2))
                .trimmingCharacters(in: .whitespaces)
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                styled(body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            styled(trimmed)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Parse `**bold**` inline spans. Falls back to plain text if the markdown
    /// parser can't handle the string.
    private func styled(_ s: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
                .font(.subheadline)
                .foregroundColor(AppPalette.ink)
        }
        return Text(s)
            .font(.subheadline)
            .foregroundColor(AppPalette.ink)
    }
}

// MARK: - Sheet item conformance

extension UIImagePickerController.SourceType: Identifiable {
    public var id: Int { rawValue }
}
