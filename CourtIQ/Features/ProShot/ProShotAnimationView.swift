import SwiftUI

/// Animated playback of a `ProShotPattern`. Renders the top-down court
/// + YOU/OP markers + an animated ball that arcs from each shot's
/// origin to its target, then snaps the markers to the new positions
/// before the next shot.
///
/// State machine:
///   `phase = .idle`     → markers shown at initial positions, ball hidden
///   `phase = .shot(i)`  → ball animating along arc for shot i
///   `phase = .between`  → brief 0.25s pause, markers snap to next config
///   `phase = .done`     → final position, replay button visible
struct ProShotAnimationView: View {
    let pattern: ProShotPattern

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .idle
    @State private var ballPosition: CGPoint = .zero
    @State private var youPosition: CGPoint = .zero
    @State private var opPosition: CGPoint = .zero
    @State private var labelOverlay: String = ""
    @State private var isPlaying = false

    enum Phase: Equatable {
        case idle
        case shot(Int)
        case between(Int)
        case done

        var isIdleOrDone: Bool {
            switch self {
            case .idle, .done: return true
            default:           return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            headerInfo
            court
            controls
            Spacer(minLength: 0)
        }
        .background(AppPalette.cream)
        .onAppear(perform: prime)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            Spacer()
            Text(pattern.playerName)
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, 18)
        .padding(.top, 62)
        .padding(.bottom, 12)
    }

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pattern.localizedTitle(for: lang.language))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
            Text(pattern.localizedTagline(for: lang.language))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Court

    private var court: some View {
        GeometryReader { geo in
            let layout = layout(in: geo.size)
            ZStack {
                AppPalette.parchment

                courtIllustration
                    .frame(width: layout.size.width, height: layout.size.height)
                    .position(x: geo.size.width / 2,
                              y: layout.size.height / 2 + 10)

                if !labelOverlay.isEmpty {
                    Text(labelOverlay)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppPalette.ink.opacity(0.88)))
                        .position(x: geo.size.width / 2,
                                  y: layout.size.height + 32)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: 330)
    }

    private struct Layout {
        let size: CGSize
    }

    private func layout(in region: CGSize) -> Layout {
        // Doubles 1 : 2.17 — same convention as `QuizCourtDiagramView`
        let height: CGFloat = 280
        let width: CGFloat = height / 2.17
        return Layout(size: CGSize(width: width, height: height))
    }

    private var courtIllustration: some View {
        let layoutSize = layout(in: .zero).size
        return ZStack {
            CourtTopDown(surface: surfaceFor(pattern: pattern), lineOpacity: 0.95)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(surfaceFor(pattern: pattern).line.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: AppPalette.ink.opacity(0.18), radius: 14, x: 0, y: 6)

            // OP marker (animates between shots)
            marker(label: "OP", fill: AppPalette.ink.opacity(0.88))
                .position(x: opPosition.x * layoutSize.width,
                          y: opPosition.y * layoutSize.height)

            // YOU marker
            marker(label: "YOU", fill: AppPalette.clay)
                .position(x: youPosition.x * layoutSize.width,
                          y: youPosition.y * layoutSize.height)

            // Ball — visible whenever we're not in idle state.
            let ballVisible: Bool = (phase != .idle)
            Circle()
                .fill(Color.yellow)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.4))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
                .position(x: ballPosition.x * layoutSize.width,
                          y: ballPosition.y * layoutSize.height)
                .opacity(ballVisible ? 1 : 0)
        }
    }

    private func marker(label: String, fill: Color) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1.6))
                .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
    }

    private func surfaceFor(pattern: ProShotPattern) -> AppPalette.CourtSurface {
        switch pattern.surface {
        case "grass": return .grass
        case "hard":  return .hard
        case "night": return .night
        default:      return .clay
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        Button {
            phase == .done ? play() : (isPlaying ? () : play())
        } label: {
            HStack(spacing: 8) {
                Image(systemName: phase == .done ? "arrow.clockwise" : "play.fill")
                Text(phase == .done ? lang.t("pro_shot.replay") : lang.t("pro_shot.play"))
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppPalette.clay)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPlaying && phase != .done)
        .padding(.horizontal, 22)
        .padding(.top, 28)
    }

    // MARK: - Animation engine

    private func prime() {
        youPosition = pattern.initialYou
        opPosition = pattern.initialOp
        if let first = pattern.shots.first {
            ballPosition = first.from
        }
        labelOverlay = ""
        phase = .idle
    }

    private func play() {
        guard !isPlaying else { return }
        isPlaying = true
        prime()
        Task { await runSequence() }
    }

    @MainActor
    private func runSequence() async {
        for (idx, shot) in pattern.shots.enumerated() {
            // Snap markers and ball start
            withAnimation(.easeInOut(duration: 0.25)) {
                youPosition = shot.you
                opPosition = shot.op
                ballPosition = shot.from
                labelOverlay = shot.localizedLabel(for: lang.language)
            }
            phase = .between(idx)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Animate the ball along the arc.
            phase = .shot(idx)
            withAnimation(.easeInOut(duration: shot.duration)) {
                ballPosition = shot.to
            }
            try? await Task.sleep(nanoseconds: UInt64(shot.duration * 1_000_000_000))
        }
        phase = .done
        isPlaying = false
        ProShotPatternsManager.shared.markViewed(pattern.id)
    }
}

