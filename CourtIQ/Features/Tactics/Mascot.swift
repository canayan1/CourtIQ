import SwiftUI

/// What Rocco is feeling. Drives eyes, brows, mouth and ear angle together —
/// callers set a mood, never individual features, so he can never end up with a
/// grin and panicked eyes at the same time.
enum Mood: String, Codable, CaseIterable {
    /// Neutral, listening.
    case idle
    /// Pleased, mid-explanation.
    case happy
    /// Posing a question.
    case thinking
    /// The player just picked a losing tactic.
    case oops
    /// Lesson finished, level up, streak milestone.
    case cheer
}

/// Rocco, the raccoon coach — drawn entirely with SwiftUI shapes.
///
/// Vector rather than an image set or a Rive file, for three reasons that matter
/// to this app: it adds no dependency and no bytes to a binary that must work
/// offline, every feature is animatable (blink, breathe, ear twitch, tail sway)
/// instead of needing one asset per expression, and expressions stay consistent
/// because they are all the same geometry with different parameters.
///
/// Everything is authored inside a 120×120 canvas and scaled by the caller, so
/// the proportions never drift between a small header and a big reward screen.
struct RaccoonView: View {
    var mood: Mood = .idle
    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1 = wide open, 0.08 = shut. Animated by the blink loop.
    @State private var eyeOpen: CGFloat = 1
    /// Gentle chest rise, so he never looks frozen.
    @State private var breathe: CGFloat = 1
    private static let canvas: CGFloat = 120

    var body: some View {
        head
        .frame(width: Self.canvas, height: Self.canvas)
        .scaleEffect(breathe)
        .scaleEffect(size / Self.canvas)
        .frame(width: size, height: size)
        .animation(Motion.entrance, value: mood)
        .onAppear(perform: startIdleLoops)
        .accessibilityHidden(true)
    }

    // MARK: - Head

    private var head: some View {
        ZStack {
            ears

            // Skull.
            Ellipse()
                .fill(Fur.gradient)
                .frame(width: 88, height: 78)
                .overlay(
                    Ellipse().stroke(Fur.dark.opacity(0.25), lineWidth: 1.5)
                )

            // The pale blaze up the middle of the forehead, between the mask
            // patches — the single feature that makes the silhouette read
            // "raccoon" and not "cat".
            Ellipse()
                .fill(Fur.blaze)
                .frame(width: 20, height: 40)
                .offset(y: -18)

            maskPatch(side: -1)
            maskPatch(side: 1)

            if isDelighted {
                blush(side: -1)
                blush(side: 1)
            }

            muzzle

            eye(side: -1)
            eye(side: 1)

            brow(side: -1)
            brow(side: 1)
        }
        .rotationEffect(.degrees(headTilt))
    }

    private var ears: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            ZStack {
                Circle()
                    .fill(Fur.mid)
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(Fur.inner)
                    .frame(width: 15, height: 15)
            }
            .offset(x: side * 32, y: -28)
            // Ears prick up when he is pleased and flatten when he is not.
            .rotationEffect(.degrees(side * earFlare), anchor: .bottom)
        }
    }

    /// The dark bandit patch around one eye.
    private func maskPatch(side: CGFloat) -> some View {
        Ellipse()
            .fill(Fur.mask)
            .frame(width: 32, height: 27)
            .rotationEffect(.degrees(side * 12))
            .offset(x: side * 19, y: -6)
    }

    private var muzzle: some View {
        ZStack {
            Ellipse()
                .fill(Fur.blaze)
                .frame(width: 44, height: 32)

            // Nose.
            Ellipse()
                .fill(Fur.mask)
                .frame(width: 13, height: 10)
                .offset(y: -6)

            mouth
        }
        .offset(y: 21)
    }

    /// Cheeks flush on the two positive moods — the cheapest single cue that
    /// separates "pleased" from "neutral" at a 44pt header size, where a few
    /// points of mouth curvature are invisible.
    private func blush(side: CGFloat) -> some View {
        Ellipse()
            .fill(Fur.blush)
            .frame(width: 13, height: 8)
            .offset(x: side * 33, y: 14)
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .cheer:
            // Open, delighted.
            Ellipse()
                .fill(Fur.mask)
                .frame(width: 18, height: 13)
                .offset(y: 7)
        case .happy:
            // A wide open grin, not a thicker line. `happy` is the mood Rocco
            // spends most of the lesson in, so it has to read as pleased at a
            // glance — a stroked curve only a few points wider than `idle` did
            // not. Still clearly not `cheer`, which closes the eyes and rounds
            // the mouth into an O.
            GrinShape()
                .fill(Fur.mask)
                .frame(width: 25, height: 14)
                .overlay(alignment: .top) {
                    // A sliver of tongue, which is what makes a filled mouth
                    // read as a grin rather than a hole.
                    Ellipse()
                        .fill(Fur.tongue)
                        .frame(width: 13, height: 7)
                        .offset(y: 6)
                        .clipped()
                }
                .clipShape(GrinShape())
                // Sits 3pt clear of the nose: at y=6 the grin's flat top met the
                // nose's underside exactly and the two merged into one dark blob,
                // which at 46pt read as a smudge rather than a face.
                .offset(y: 9)
        case .oops:
            // Small flat grimace.
            Capsule()
                .fill(Fur.mask)
                .frame(width: 14, height: 3)
                .offset(y: 7)
        case .thinking:
            // Off-centre, pursed.
            Capsule()
                .fill(Fur.mask)
                .frame(width: 11, height: 3)
                .offset(x: 6, y: 7)
        case .idle:
            SmileShape()
                .stroke(Fur.mask, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 17, height: 9)
                .offset(y: 5)
        }
    }

    private func eye(side: CGFloat) -> some View {
        ZStack {
            if mood == .cheer {
                // Happy closed arcs.
                SmileShape()
                    .stroke(Fur.blaze, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 15, height: 6)
            } else {
                Capsule()
                    .fill(.white)
                    .frame(width: 15 * eyeScale, height: 15 * eyeScale * eyeSquint * eyeOpen)
                    .overlay(alignment: pupilAlignment) {
                        Circle()
                            .fill(Fur.mask)
                            .frame(width: 8, height: 8)
                            .opacity(eyeOpen > 0.4 ? 1 : 0)
                    }
            }
        }
        .frame(width: 15, height: 15)
        .offset(x: side * 19, y: -6)
    }

    /// A raised brow above the mask, used to sell "thinking" and "oops".
    @ViewBuilder
    private func brow(side: CGFloat) -> some View {
        if mood == .thinking || mood == .oops {
            Capsule()
                .fill(Fur.blaze)
                .frame(width: 15, height: 3)
                // On `thinking` only the left brow lifts, which reads as a
                // question rather than as alarm.
                .rotationEffect(.degrees(mood == .thinking ? (side < 0 ? -18 : 4) : side * 14))
                .offset(x: side * 19, y: mood == .thinking && side < 0 ? -22 : -19)
        }
    }

    // MARK: - Mood parameters

    /// Uniform eye size. Wider eyes on `happy` push it further from `idle`.
    private var eyeScale: CGFloat {
        mood == .happy ? 1.1 : 1
    }

    /// True for the two moods that get flushed cheeks.
    private var isDelighted: Bool {
        mood == .happy || mood == .cheer
    }

    /// Vertical squash of the eye, before blinking is applied.
    private var eyeSquint: CGFloat {
        switch mood {
        case .oops:     return 0.55
        case .thinking: return 0.85
        default:        return 1
        }
    }

    /// Where the pupil sits — looking up and away while thinking.
    private var pupilAlignment: Alignment {
        switch mood {
        case .thinking: return .topLeading
        case .oops:     return .bottom
        default:        return .center
        }
    }

    private var earFlare: Double {
        switch mood {
        case .happy:         return -18
        case .cheer:         return -10
        case .oops:          return 14
        default:             return 0
        }
    }

    private var headTilt: Double {
        switch mood {
        case .thinking: return -6
        case .happy:    return 3
        case .cheer:    return 5
        default:        return 0
        }
    }

    // MARK: - Idle loops

    private func startIdleLoops() {
        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathe = 1.025
        }
        blinkLoop()
    }

    /// Blinks on an irregular interval. A metronome blink looks mechanical, so
    /// the gap between blinks is randomised inside a natural range.
    private func blinkLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(.random(in: 2.4...5.5)))
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.09)) { eyeOpen = 0.08 }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeInOut(duration: 0.11)) { eyeOpen = 1 }
            }
        }
    }

    // MARK: - Fur palette

    private enum Fur {
        static let mid = Color(red: 146 / 255, green: 138 / 255, blue: 130 / 255)
        static let dark = Color(red: 96 / 255, green: 90 / 255, blue: 84 / 255)
        static let mask = AppPalette.ink
        static let blaze = Color(red: 249 / 255, green: 244 / 255, blue: 236 / 255)
        static let inner = Color(red: 206 / 255, green: 176 / 255, blue: 166 / 255)
        static let blush = Color(red: 216 / 255, green: 141 / 255, blue: 118 / 255).opacity(0.55)
        static let tongue = Color(red: 214 / 255, green: 122 / 255, blue: 118 / 255)

        static let gradient = LinearGradient(
            colors: [Color(red: 162 / 255, green: 154 / 255, blue: 145 / 255), mid],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A filled open grin: flat along the top, curving down to a rounded bottom.
private struct GrinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.7)
        )
        path.closeSubpath()
        return path
    }
}

/// A shallow upward arc — used for both the smile and the closed happy eyes.
private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 2)
        )
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ForEach(Mood.allCases, id: \.self) { mood in
                VStack {
                    RaccoonView(mood: mood, size: 82)
                    Text(mood.rawValue).font(.caption2)
                }
            }
        }
        RaccoonView(mood: .happy, size: 160)
    }
    .padding(24)
    .background(AppPalette.cream)
}
