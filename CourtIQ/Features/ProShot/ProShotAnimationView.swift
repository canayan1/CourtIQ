import SwiftUI

/// Animated playback of a `ProShotPattern`. Renders the top-down court
/// + YOU / OP markers + a parabolic-arc'd ball that travels from each
/// shot's origin to its target, then snaps the markers to the new
/// configuration before the next shot.
///
/// State machine:
///   `phase = .idle`     → markers shown at initial positions, ball hidden
///   `phase = .shot(i)`  → ball animating along arc for shot i
///   `phase = .between`  → brief settle pause; markers + label refresh
///   `phase = .done`     → final position, replay button visible
///
/// Notable UX choices (informed by 2026-05 audit feedback "biraz karışık
/// ve anlaşılmaz"):
///
///   • Ball travels along a parabolic arc, not a straight line — height
///     proportional to the chord length, so short shots stay flat and
///     longer crosscourts visibly loft over the net. This gives the
///     viewer an immediate visual sense of "this is a real shot, not
///     just a geometry demo".
///   • The hitting player's marker briefly pulses + a small "YOU hit" /
///     "Opponent hit" caption flashes when each shot begins, so the
///     viewer never has to guess who's striking the ball.
///   • The shot label is set BEFORE the ball begins moving and held for
///     ~300 ms after it lands, giving readers time to actually parse it.
///   • A first-time intro overlay explains the legend (yellow ball,
///     YOU bottom, OP top, marker pulse = hitter) so the casual viewer
///     isn't dropped into an unexplained sequence.
///   • An "educational reference" footnote sits below the controls to
///     make the IP framing unambiguous to both users and reviewers
///     (Apple Guideline 3.1 — no implied endorsement).
struct ProShotAnimationView: View {
    let pattern: ProShotPattern

    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .idle
    @State private var youPosition: CGPoint = .zero
    @State private var opPosition: CGPoint = .zero
    @State private var labelOverlay: String = ""
    @State private var isPlaying = false

    /// Ball position is computed each frame from the active arc segment.
    /// Storing both the segment endpoints and a 0…1 progress lets us
    /// drive a parabolic interpolation manually rather than letting
    /// SwiftUI lerp straight between two points.
    @State private var arcFrom: CGPoint = .zero
    @State private var arcTo: CGPoint = .zero
    @State private var arcProgress: Double = 0
    @State private var arcTimer: Timer?

    /// Per-shot attribution. When set, we render a soft pulse on the
    /// matching marker + a small "YOU hit" / "Opponent hit" caption.
    @State private var hittingMarker: Hitter? = nil
    @State private var attributionVisible: Bool = false

    /// First-time intro overlay. Sticks across launches so returning
    /// users go straight into the pattern.
    @AppStorage("CourtIQ.ProShot.introSeen.v1") private var introSeen: Bool = false
    @State private var showIntro: Bool = false

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

    enum Hitter { case you, op }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                headerInfo
                court
                controls
                educationalFootnote
                Spacer(minLength: 0)
            }
            .background(AppPalette.cream)

            if showIntro {
                introOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            prime()
            if !introSeen { showIntro = true }
        }
        .onDisappear { arcTimer?.invalidate(); arcTimer = nil }
    }

    // MARK: - Top bar + header

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
        .frame(height: 360)
    }

    private struct Layout {
        let size: CGSize
    }

    private func layout(in region: CGSize) -> Layout {
        // Doubles 1 : 2.17 — same convention as `QuizCourtDiagramView`.
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

            // OP marker
            markerWithAttribution(
                label: "OP",
                fill: AppPalette.ink.opacity(0.88),
                pulse: hittingMarker == .op && attributionVisible,
                hitCaption: hittingMarker == .op && attributionVisible
                    ? lang.t("pro_shot.op_hit")
                    : nil
            )
            .position(x: opPosition.x * layoutSize.width,
                      y: opPosition.y * layoutSize.height)

            // YOU marker
            markerWithAttribution(
                label: "YOU",
                fill: AppPalette.clay,
                pulse: hittingMarker == .you && attributionVisible,
                hitCaption: hittingMarker == .you && attributionVisible
                    ? lang.t("pro_shot.you_hit")
                    : nil
            )
            .position(x: youPosition.x * layoutSize.width,
                      y: youPosition.y * layoutSize.height)

            // Ball — visible whenever we're not in idle.
            let ballVisible: Bool = (phase != .idle)
            let ballPos = arcPoint(from: arcFrom, to: arcTo, t: arcProgress)
            Circle()
                .fill(Color.yellow)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.4))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
                .position(x: ballPos.x * layoutSize.width,
                          y: ballPos.y * layoutSize.height)
                .opacity(ballVisible ? 1 : 0)
        }
    }

    /// Marker + optional pulse halo + optional micro-caption above the
    /// marker. Pulse uses two stacked circles that scale + fade.
    @ViewBuilder
    private func markerWithAttribution(
        label: String,
        fill: Color,
        pulse: Bool,
        hitCaption: String?
    ) -> some View {
        ZStack {
            if pulse {
                Circle()
                    .stroke(fill, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .scaleEffect(2.0)
                    .opacity(0)
                    .animation(.easeOut(duration: 0.65).repeatCount(2, autoreverses: false),
                               value: pulse)
                Circle()
                    .stroke(fill.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(1.45)
                    .opacity(0.6)
                    .animation(.easeOut(duration: 0.45).repeatCount(2, autoreverses: false),
                               value: pulse)
            }
            // Base marker
            Circle()
                .fill(fill)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1.6))
                .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white)
            if let caption = hitCaption {
                Text(caption)
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(fill))
                    .offset(y: -22)
                    .transition(.opacity)
            }
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

    // MARK: - Arc math

    /// Parabolic interpolation between `from` and `to`. The apex is
    /// raised above the linear chord by an amount proportional to the
    /// horizontal distance, so short flat shots stay close to straight
    /// while long crosscourts visibly loft. The "up" direction on our
    /// top-down court is `-y`, so we subtract the apex offset.
    private func arcPoint(from a: CGPoint, to b: CGPoint, t: Double) -> CGPoint {
        let tc = max(0, min(1, t))
        let x = a.x + (b.x - a.x) * tc
        let yLinear = a.y + (b.y - a.y) * tc

        let dx = abs(b.x - a.x)
        let dy = abs(b.y - a.y)
        let dist = sqrt(dx * dx + dy * dy)
        // Arc height: ~16 % of chord length, capped at 0.12 of court
        // height (so a full baseline-to-baseline shot doesn't loft so
        // far it disappears off the side of the diagram).
        let arcHeight = min(0.12, dist * 0.18)
        // 4t(1-t) is the unit parabola peaking at t=0.5
        let apexOffset = 4 * tc * (1 - tc) * arcHeight
        return CGPoint(x: x, y: yLinear - apexOffset)
    }

    // MARK: - Controls + footnote

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
        .padding(.top, 18)
    }

    /// Mandatory IP framing — player names appear nominatively (no
    /// likeness, no logo, no audio) but Apple Guideline 3.1 flags any
    /// implied endorsement, and this line removes the ambiguity for
    /// reviewers + users.
    private var educationalFootnote: some View {
        Text(lang.t("pro_shot.educational"))
            .font(.caption2)
            .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: - First-time intro overlay

    private var introOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismissIntro() }
            VStack(alignment: .leading, spacing: 14) {
                Label(lang.t("pro_shot.intro_kicker"), systemImage: "info.circle.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppPalette.clay)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(lang.t("pro_shot.intro_title"))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                Text(lang.t("pro_shot.intro_body"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: dismissIntro) {
                    Text(lang.t("pro_shot.intro_cta"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppPalette.clay)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(AppPalette.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        }
    }

    private func dismissIntro() {
        introSeen = true
        withAnimation(.easeOut(duration: 0.2)) { showIntro = false }
    }

    // MARK: - Animation engine

    private func prime() {
        youPosition = pattern.initialYou
        opPosition = pattern.initialOp
        if let first = pattern.shots.first {
            arcFrom = first.from
            arcTo = first.from
            arcProgress = 0
        }
        labelOverlay = ""
        hittingMarker = nil
        attributionVisible = false
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
            // 1. Snap markers + show label BEFORE the ball moves, so the
            //    viewer always reads the label that describes what's
            //    about to happen.
            withAnimation(.easeInOut(duration: 0.22)) {
                youPosition = shot.you
                opPosition = shot.op
                labelOverlay = shot.localizedLabel(for: lang.language)
            }
            phase = .between(idx)
            try? await Task.sleep(nanoseconds: 380_000_000) // 0.38s read window

            // 2. Pulse the hitting player's marker + show "YOU hit" or
            //    "Opponent hit" microlabel for a beat.
            hittingMarker = inferHitter(shot: shot)
            withAnimation(.easeOut(duration: 0.15)) { attributionVisible = true }
            try? await Task.sleep(nanoseconds: 220_000_000)

            // 3. Run the arc.
            phase = .shot(idx)
            await animateArc(from: shot.from, to: shot.to, duration: shot.duration)

            // 4. Hold the label briefly after the ball lands, then fade
            //    the attribution out before the next shot.
            withAnimation(.easeOut(duration: 0.2)) { attributionVisible = false }
            try? await Task.sleep(nanoseconds: 280_000_000)
        }
        phase = .done
        hittingMarker = nil
        isPlaying = false
        ProShotPatternsManager.shared.markViewed(pattern.id)
    }

    /// Drive `arcProgress` from 0 → 1 over `duration` seconds at ~60 Hz.
    /// We can't use `withAnimation` here because the parabolic offset
    /// is computed from `arcProgress` inside the view body — SwiftUI's
    /// implicit lerp would only sample at start + end. A frame timer
    /// gives us smooth real interpolation.
    @MainActor
    private func animateArc(from a: CGPoint, to b: CGPoint, duration: Double) async {
        arcFrom = a
        arcTo = b
        arcProgress = 0
        let start = Date()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            arcTimer?.invalidate()
            arcTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
                let t = min(1.0, Date().timeIntervalSince(start) / duration)
                Task { @MainActor in
                    self.arcProgress = t
                    if t >= 1.0 {
                        timer.invalidate()
                        self.arcTimer = nil
                        cont.resume()
                    }
                }
            }
        }
    }

    /// Whoever's standing where the ball starts must be hitting it.
    /// Uses a small tolerance because hand-authored coords aren't pixel
    /// perfect — 0.12 of court width is roughly "within an arm + racquet
    /// reach", which is enough to disambiguate cleanly.
    private func inferHitter(shot: ProShotEvent) -> Hitter {
        let toYou = hypot(shot.from.x - shot.you.x, shot.from.y - shot.you.y)
        let toOp  = hypot(shot.from.x - shot.op.x,  shot.from.y - shot.op.y)
        return toYou <= toOp ? .you : .op
    }
}
