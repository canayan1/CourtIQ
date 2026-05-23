import SwiftUI

// MARK: - Public surface
//
// `MobilityAnimationPreview` is a development gallery that shows the
// production-grade procedural athlete figure across a handful of named
// tennis mobility moves. The same `AthleteFigureCanvas` + `AthletePose`
// types are wired into `MobilityFlowDetailView` so the gallery and the
// production surface render from the same source of truth.
//
// Design goals (post-Begum pivot):
//   • Looks intentional, not "stick figure".
//   • Uses only AppPalette tokens — palette/dark-mode just work.
//   • Zero image assets, zero bundle weight, infinite scale.
//   • Animates between poses with eased interpolation and a subtle
//     breath-driven micro-motion so the figure feels alive even at rest.

struct MobilityAnimationPreview: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                kicker
                heroAnimation
                otherMovesStrip
                stylenote
            }
            .padding(22)
            .padding(.bottom, 40)
        }
        .background(AppPalette.cream)
        .navigationTitle("Procedural figure")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("World's Greatest Stretch", systemImage: "figure.flexibility")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("A tennis warm-up classic — hip opener, hamstring, thoracic rotation.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    private var heroAnimation: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )

                // Soft court accent — matches the existing TodayView hero
                // pattern (CourtTopDown + opacity damper).
                CourtTopDown(surface: .clay, lineOpacity: 0.22)
                    .opacity(0.30)
                    .frame(width: 130, height: 200)
                    .offset(x: 95, y: 0)
                    .allowsHitTesting(false)

                AthleteFigureCanvas(
                    poseSequence: [.standing, .forwardFold, .lungeTwist],
                    loopDuration: 6.0
                )
                .frame(width: 280, height: 280)
            }
            .frame(height: 340)

            HStack(spacing: 8) {
                BreathDot()
                Text("Hold 3 breaths each side · 2 rounds")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
    }

    private var otherMovesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More moves — same style")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    moveThumb(title: "Hamstring",  pose: .forwardFold)
                    moveThumb(title: "Hip opener", pose: .lungeTwist)
                    moveThumb(title: "Calf wall",  pose: .calfWall)
                    moveThumb(title: "T-spine",    pose: .tSpineWindmill)
                    moveThumb(title: "90/90 hip",  pose: .nineNinety)
                    moveThumb(title: "Standing",   pose: .standing)
                }
            }
        }
    }

    private func moveThumb(title: String, pose: AthletePose) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                AthleteFigureCanvas(staticPose: pose)
                    .frame(width: 120, height: 120)
            }
            .frame(width: 140, height: 150)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
        }
    }

    private var stylenote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Procedural rendering — production grade")
                .font(.headline)
            Text("Each limb is a filled tapered ribbon (Bezier-driven, thicker proximal to thinner distal). Body silhouette is one continuous closed Path. Pose data is normalized [0,1] so the same figure scales from 90 pt thumbnail to full-screen detail. Breath modulation pulses the torso ±2% on a 4-second sine. Floor shadow follows foot spread. All colors come from AppPalette tokens — change clay or ink and every figure restyles automatically.")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Athlete figure renderer

/// Canvas-based athlete figure that interpolates between a sequence of
/// `AthletePose` keyframes on a loop, with an underlying breath-driven
/// micro-motion. Use the static-pose initializer when you want a still
/// thumbnail (e.g. in a card grid).
struct AthleteFigureCanvas: View {
    let poseSequence: [AthletePose]
    let loopDuration: TimeInterval
    let isStatic: Bool

    init(poseSequence: [AthletePose], loopDuration: TimeInterval) {
        self.poseSequence = poseSequence
        self.loopDuration = loopDuration
        self.isStatic = false
    }

    init(staticPose: AthletePose) {
        self.poseSequence = [staticPose]
        self.loopDuration = 1
        self.isStatic = true
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let pose: AthletePose = isStatic
                ? poseSequence[0]
                : interpolated(at: now)
            let breath = breathOffset(at: now)

            Canvas { ctx, size in
                draw(pose: pose, breath: breath, ctx: &ctx, size: size)
            }
        }
    }

    // MARK: Interpolation

    private func interpolated(at time: TimeInterval) -> AthletePose {
        guard poseSequence.count >= 2 else { return poseSequence.first ?? .standing }
        let step = loopDuration / Double(poseSequence.count)
        let phase = time.truncatingRemainder(dividingBy: loopDuration)
        let i = Int(phase / step)
        let localT = (phase - Double(i) * step) / step
        let eased = ease(localT)
        let a = poseSequence[i % poseSequence.count]
        let b = poseSequence[(i + 1) % poseSequence.count]
        return AthletePose.lerp(a, b, eased)
    }

    private func ease(_ t: Double) -> Double {
        // Smooth in/out — feels like a deliberate breath cycle.
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    /// ±2% torso compression on a 4-second sine wave. Even on a frozen
    /// pose the figure breathes; on an animated pose this layers on
    /// top of the keyframe interpolation.
    private func breathOffset(at time: TimeInterval) -> CGFloat {
        let omega = 2 * Double.pi / 4.0
        return CGFloat(sin(time * omega)) * 0.012
    }

    // MARK: Drawing

    private func draw(pose: AthletePose, breath: CGFloat, ctx: inout GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height)
        let absolute = pose.absolute(in: CGSize(width: s, height: s),
                                     breathBias: breath)
        let bodyColor = ink
        let accent = clay
        // Joint anchor + clothing strokes use a darker version of the
        // body color so they read as anatomical detail rather than noise.
        let jointColor = Color(red: 0.10, green: 0.07, blue: 0.04)

        // Spine geometry — shared between the body silhouette and the
        // clothing strokes so shorts/tank lines tilt with the torso
        // during folds and rotations.
        let spineDir = normalize(CGPoint(x: absolute.chest.x - absolute.pelvis.x,
                                         y: absolute.chest.y - absolute.pelvis.y))
        let spinePerp = CGPoint(x: -spineDir.y, y: spineDir.x)

        // 1. Ground shadow — soft ellipse under the feet, scales with foot spread.
        let leftFoot  = absolute.leftFoot
        let rightFoot = absolute.rightFoot
        let footCenter = CGPoint(x: (leftFoot.x + rightFoot.x) / 2,
                                 y: max(leftFoot.y, rightFoot.y) + s * 0.012)
        let spread = max(abs(rightFoot.x - leftFoot.x), s * 0.10)
        let shadowRect = CGRect(
            x: footCenter.x - spread * 0.9,
            y: footCenter.y - s * 0.012,
            width: spread * 1.8,
            height: s * 0.025
        )
        ctx.fill(Path(ellipseIn: shadowRect),
                 with: .color(bodyColor.opacity(0.18)))

        // 2. Back-side limbs (z-order behind body silhouette).
        drawLimb(ctx: &ctx, from: absolute.pelvis, mid: absolute.leftKnee, end: absolute.leftFoot,
                 widthStart: s * 0.075, widthMid: s * 0.045, widthEnd: s * 0.035, color: bodyColor.opacity(0.92))
        drawLimb(ctx: &ctx, from: absolute.chest, mid: absolute.leftElbow, end: absolute.leftHand,
                 widthStart: s * 0.055, widthMid: s * 0.038, widthEnd: s * 0.030, color: bodyColor.opacity(0.92))

        // 3. Body silhouette + head.
        drawBodySilhouette(ctx: &ctx, pose: absolute, size: s, color: bodyColor,
                           spinePerp: spinePerp)

        // 4. Front-side limbs in accent color for fore/back depth.
        drawLimb(ctx: &ctx, from: absolute.pelvis, mid: absolute.rightKnee, end: absolute.rightFoot,
                 widthStart: s * 0.075, widthMid: s * 0.045, widthEnd: s * 0.035, color: accent)
        drawLimb(ctx: &ctx, from: absolute.chest, mid: absolute.rightElbow, end: absolute.rightHand,
                 widthStart: s * 0.055, widthMid: s * 0.038, widthEnd: s * 0.030, color: accent)

        // 5. Clothing hints — tank top hem across the chest, shorts hem
        //    across the pelvis. Both tilt with the spine perpendicular.
        drawClothing(ctx: &ctx, pose: absolute, size: s,
                     spinePerp: spinePerp, lineColor: jointColor.opacity(0.55))

        // 6. Joint anchor dots — small filled circles at elbow + knee
        //    give the figure recognizable anatomy at thumbnail scale.
        let jointR = s * 0.018
        for joint in [absolute.leftElbow, absolute.rightElbow,
                      absolute.leftKnee, absolute.rightKnee] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: joint.x - jointR, y: joint.y - jointR,
                                       width: jointR * 2, height: jointR * 2)),
                with: .color(jointColor.opacity(0.85))
            )
        }

        // 7. Head highlight — small parchment-tinted oval offset toward
        //    upper-left so the head reads as a 3D sphere lit from above.
        let headR: CGFloat = s * 0.080
        let highlightR = headR * 0.35
        let hx = absolute.head.x - headR * 0.30
        let hy = absolute.head.y - headR * 0.35
        let highlightRect = CGRect(x: hx - highlightR,
                                   y: hy - highlightR,
                                   width: highlightR * 2,
                                   height: highlightR * 2)
        ctx.fill(Path(ellipseIn: highlightRect),
                 with: .color(Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.18)))

        // 8. Subtle dashed ground line — spatial grounding.
        var ground = Path()
        let groundY = s * 0.94
        ground.move(to: CGPoint(x: s * 0.08, y: groundY))
        ground.addLine(to: CGPoint(x: s * 0.92, y: groundY))
        ctx.stroke(ground, with: .color(bodyColor.opacity(0.18)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
    }

    /// Draws thin contour lines suggesting a tank top hem (just below
    /// the chest) and a shorts hem (just below the pelvis). Both tilt
    /// with the spine so the figure looks dressed even mid-rotation.
    private func drawClothing(ctx: inout GraphicsContext, pose: AthletePose,
                              size s: CGFloat, spinePerp: CGPoint, lineColor: Color) {
        let chest = pose.chest
        let pelvis = pose.pelvis

        // Tank top hem — slight curve across the upper torso.
        let chestHalfW = s * 0.080
        let tankCenter = CGPoint(x: chest.x + spinePerp.y * s * 0.04,
                                 y: chest.y + spinePerp.x * s * 0.04 * -1)
        // Simpler: keep the hem at the chest's vertical band, tilted
        // perpendicular to the spine.
        let _ = tankCenter
        let tankL = offset(chest, by: spinePerp, mag: chestHalfW * 0.85)
        let tankR = offset(chest, by: spinePerp, mag: -chestHalfW * 0.85)
        var tank = Path()
        tank.move(to: tankL)
        // Gentle dip toward the center (suggests neckline curve).
        let dip = CGPoint(
            x: (tankL.x + tankR.x) / 2 + spinePerp.x * s * 0.02 * -1,
            y: (tankL.y + tankR.y) / 2 + spinePerp.y * s * 0.02 * -1
        )
        tank.addQuadCurve(to: tankR, control: dip)
        ctx.stroke(tank, with: .color(lineColor),
                   style: StrokeStyle(lineWidth: max(1.2, s * 0.008), lineCap: .round))

        // Shorts hem — straight perpendicular line just below the pelvis.
        let hipHalfW = s * 0.060
        let shortsOffsetAlongSpine = s * 0.06
        // Move slightly downward along the spine (toward the legs).
        let spineDown = CGPoint(x: -spinePerp.y, y: spinePerp.x)
        let shortsCenter = offset(pelvis, by: spineDown, mag: shortsOffsetAlongSpine)
        let shortsL = offset(shortsCenter, by: spinePerp, mag: hipHalfW * 1.05)
        let shortsR = offset(shortsCenter, by: spinePerp, mag: -hipHalfW * 1.05)
        var shorts = Path()
        shorts.move(to: shortsL)
        shorts.addLine(to: shortsR)
        ctx.stroke(shorts, with: .color(lineColor),
                   style: StrokeStyle(lineWidth: max(1.2, s * 0.008), lineCap: .round))
    }

    /// Tapered limb — three control points (origin, joint, end) with
    /// per-point width. Renders as a filled closed ribbon: trace one
    /// side from origin → joint → end (smoothed with quadratics), add
    /// a rounded end cap, trace back along the other side, and close.
    private func drawLimb(ctx: inout GraphicsContext,
                          from a: CGPoint, mid b: CGPoint, end c: CGPoint,
                          widthStart wA: CGFloat, widthMid wB: CGFloat, widthEnd wC: CGFloat,
                          color: Color) {
        // Two segments: a→b, b→c. Compute perpendicular offsets at
        // each control point so the outline curves with the limb.
        let nAB = perpendicular(from: a, to: b)
        let nBC = perpendicular(from: b, to: c)

        // At the joint, average the two perpendiculars so the seam
        // looks continuous rather than kinked.
        let nB = normalize(CGPoint(x: (nAB.x + nBC.x) / 2,
                                   y: (nAB.y + nBC.y) / 2))

        let aHi = offset(a, by: nAB, mag: wA / 2)
        let aLo = offset(a, by: nAB, mag: -wA / 2)
        let bHi = offset(b, by: nB, mag: wB / 2)
        let bLo = offset(b, by: nB, mag: -wB / 2)
        let cHi = offset(c, by: nBC, mag: wC / 2)
        let cLo = offset(c, by: nBC, mag: -wC / 2)

        var path = Path()
        path.move(to: aHi)
        path.addQuadCurve(to: cHi,
                          control: CGPoint(x: bHi.x, y: bHi.y))
        // Rounded end cap at c.
        path.addArc(center: c, radius: wC / 2,
                    startAngle: angle(nBC),
                    endAngle: angle(CGPoint(x: -nBC.x, y: -nBC.y)),
                    clockwise: false)
        path.addQuadCurve(to: aLo,
                          control: CGPoint(x: bLo.x, y: bLo.y))
        path.addArc(center: a, radius: wA / 2,
                    startAngle: angle(CGPoint(x: -nAB.x, y: -nAB.y)),
                    endAngle: angle(nAB),
                    clockwise: false)
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    /// Continuous closed silhouette for the torso (pelvis ↔ chest ↔ neck
    /// stub) drawn as one filled shape. Head is rendered as a separate
    /// filled ellipse on top so the geometry stays predictable across
    /// any pose orientation (no fragile arc-direction math).
    private func drawBodySilhouette(ctx: inout GraphicsContext, pose: AthletePose,
                                    size: CGFloat, color: Color, spinePerp: CGPoint) {
        let pelvis = pose.pelvis
        let chest = pose.chest
        let head = pose.head

        // Shoulder width tapers slightly wider than hip width.
        let hipHalfW: CGFloat = size * 0.058
        let chestHalfW: CGFloat = size * 0.080
        let neckHalfW: CGFloat = size * 0.028

        let pelvisL = offset(pelvis, by: spinePerp, mag: hipHalfW)
        let pelvisR = offset(pelvis, by: spinePerp, mag: -hipHalfW)
        let chestL = offset(chest, by: spinePerp, mag: chestHalfW)
        let chestR = offset(chest, by: spinePerp, mag: -chestHalfW)

        // Neck base is closer to the chest than to the head — the head
        // floats above the neck stub with a small gap for visual breathing.
        let neckBase = lerpPoint(chest, head, 0.55)
        let neckL = offset(neckBase, by: spinePerp, mag: neckHalfW)
        let neckR = offset(neckBase, by: spinePerp, mag: -neckHalfW)

        // 1. Torso silhouette (pelvis → chest → neck on both sides).
        var torso = Path()
        torso.move(to: pelvisL)
        torso.addQuadCurve(to: chestL, control: lerpPoint(pelvisL, chestL, 0.5))
        torso.addQuadCurve(to: neckL,
                           control: lerpPoint(chestL, neckL, 0.5))
        torso.addLine(to: neckR)
        torso.addQuadCurve(to: chestR, control: lerpPoint(neckR, chestR, 0.5))
        torso.addQuadCurve(to: pelvisR, control: lerpPoint(chestR, pelvisR, 0.5))
        torso.closeSubpath()
        ctx.fill(torso, with: .color(color))

        // 2. Head as separate filled circle. Sized to feel proportional
        //    to the torso width — slightly wider than the chestHalfW.
        let headR: CGFloat = size * 0.080
        let headRect = CGRect(x: head.x - headR,
                              y: head.y - headR,
                              width: headR * 2,
                              height: headR * 2)
        ctx.fill(Path(ellipseIn: headRect), with: .color(color))
    }

    // MARK: Math helpers

    private func perpendicular(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let n = normalize(CGPoint(x: -dy, y: dx))
        return n
    }

    private func normalize(_ p: CGPoint) -> CGPoint {
        let len = sqrt(p.x * p.x + p.y * p.y)
        guard len > 0.0001 else { return .zero }
        return CGPoint(x: p.x / len, y: p.y / len)
    }

    private func offset(_ p: CGPoint, by direction: CGPoint, mag: CGFloat) -> CGPoint {
        CGPoint(x: p.x + direction.x * mag, y: p.y + direction.y * mag)
    }

    private func angle(_ p: CGPoint) -> Angle {
        .radians(atan2(p.y, p.x))
    }

    private func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // Local color helpers — pulls from AppPalette but keeps these
    // accessible inside Canvas closures without environment lookup.
    private var ink: Color { AppPalette.ink }
    private var clay: Color { AppPalette.clay }
}

// MARK: - Breath tempo strip

/// Visual companion to the figure's breath modulation. Renders a row
/// of small dots that progressively fill on each breath cycle — three
/// breaths in, then resets. The active dot pulses in sync with the
/// figure's chest expansion so the user can use the strip as a tempo
/// metronome ("hold until all three light up").
struct BreathDot: View {
    /// Total dots displayed. Three matches the "Hold 3 breaths" copy
    /// in the hero hint.
    let count: Int = 3
    /// Seconds per breath — matches `AthleteFigureCanvas.breathOffset`
    /// (4s sine), so the dot pulse stays phase-locked with the figure.
    let breathDuration: TimeInterval = 4.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Determine which dot is "active" — completes one breath each
            // breathDuration, wraps after `count` breaths.
            let cyclePosition = t.truncatingRemainder(dividingBy: Double(count) * breathDuration)
            let activeIndex = Int(cyclePosition / breathDuration)
            let activePulse = 0.7 + 0.3 * abs(sin(t * 2 * .pi / breathDuration))

            HStack(spacing: 5) {
                ForEach(0..<count, id: \.self) { i in
                    let isActive = i == activeIndex
                    let isFilled = i <= activeIndex
                    Circle()
                        .fill(isFilled ? AppPalette.clay : AppPalette.sand)
                        .frame(width: 7, height: 7)
                        .scaleEffect(isActive ? activePulse : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: activeIndex)
                }
            }
        }
    }
}

// MARK: - Pose model

/// Normalized [0,1] joint positions for the athlete figure. All poses
/// face the viewer in profile (left-foot first when reading L→R).
/// `lerp` blends two poses; `absolute(in:breathBias:)` projects into
/// pixel coordinates and applies the breath micro-modulation.
struct AthletePose {
    var head: CGPoint
    var chest: CGPoint
    var pelvis: CGPoint
    var leftElbow: CGPoint
    var rightElbow: CGPoint
    var leftHand: CGPoint
    var rightHand: CGPoint
    var leftKnee: CGPoint
    var rightKnee: CGPoint
    var leftFoot: CGPoint
    var rightFoot: CGPoint

    func absolute(in size: CGSize, breathBias: CGFloat) -> AthletePose {
        // Breath modulates only the chest+head (ribs expand). Adds a
        // tiny upward push proportional to bias.
        let breathLift = CGPoint(x: 0, y: breathBias * -1)
        return AthletePose(
            head: scaled(addBias(head, by: breathLift), size),
            chest: scaled(addBias(chest, by: breathLift), size),
            pelvis: scaled(pelvis, size),
            leftElbow: scaled(leftElbow, size),
            rightElbow: scaled(rightElbow, size),
            leftHand: scaled(leftHand, size),
            rightHand: scaled(rightHand, size),
            leftKnee: scaled(leftKnee, size),
            rightKnee: scaled(rightKnee, size),
            leftFoot: scaled(leftFoot, size),
            rightFoot: scaled(rightFoot, size)
        )
    }

    private func addBias(_ p: CGPoint, by b: CGPoint) -> CGPoint {
        CGPoint(x: p.x + b.x, y: p.y + b.y)
    }

    private func scaled(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    static func lerp(_ a: AthletePose, _ b: AthletePose, _ t: Double) -> AthletePose {
        AthletePose(
            head: lerpPt(a.head, b.head, t),
            chest: lerpPt(a.chest, b.chest, t),
            pelvis: lerpPt(a.pelvis, b.pelvis, t),
            leftElbow: lerpPt(a.leftElbow, b.leftElbow, t),
            rightElbow: lerpPt(a.rightElbow, b.rightElbow, t),
            leftHand: lerpPt(a.leftHand, b.leftHand, t),
            rightHand: lerpPt(a.rightHand, b.rightHand, t),
            leftKnee: lerpPt(a.leftKnee, b.leftKnee, t),
            rightKnee: lerpPt(a.rightKnee, b.rightKnee, t),
            leftFoot: lerpPt(a.leftFoot, b.leftFoot, t),
            rightFoot: lerpPt(a.rightFoot, b.rightFoot, t)
        )
    }

    private static func lerpPt(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t)
    }

    // MARK: - Canned poses (tennis mobility library)

    /// Standing neutral — head over pelvis, arms relaxed alongside hips.
    static let standing = AthletePose(
        head:        .init(x: 0.50, y: 0.18),
        chest:       .init(x: 0.50, y: 0.34),
        pelvis:      .init(x: 0.50, y: 0.55),
        leftElbow:   .init(x: 0.41, y: 0.50),
        rightElbow:  .init(x: 0.59, y: 0.50),
        leftHand:    .init(x: 0.38, y: 0.66),
        rightHand:   .init(x: 0.62, y: 0.66),
        leftKnee:    .init(x: 0.46, y: 0.75),
        rightKnee:   .init(x: 0.54, y: 0.75),
        leftFoot:    .init(x: 0.44, y: 0.92),
        rightFoot:   .init(x: 0.56, y: 0.92)
    )

    /// Forward fold — hip-hinge, hands sweeping toward the floor.
    static let forwardFold = AthletePose(
        head:        .init(x: 0.50, y: 0.66),
        chest:       .init(x: 0.50, y: 0.55),
        pelvis:      .init(x: 0.50, y: 0.40),
        leftElbow:   .init(x: 0.45, y: 0.72),
        rightElbow:  .init(x: 0.55, y: 0.72),
        leftHand:    .init(x: 0.46, y: 0.88),
        rightHand:   .init(x: 0.54, y: 0.88),
        leftKnee:    .init(x: 0.47, y: 0.68),
        rightKnee:   .init(x: 0.53, y: 0.68),
        leftFoot:    .init(x: 0.45, y: 0.92),
        rightFoot:   .init(x: 0.55, y: 0.92)
    )

    /// World's Greatest Stretch — front (right) leg in a deep 90° lunge,
    /// back (left) leg straight behind, right arm rotated up and out,
    /// left hand planted on the floor inside the front foot.
    static let lungeTwist = AthletePose(
        head:        .init(x: 0.55, y: 0.36),
        chest:       .init(x: 0.55, y: 0.52),
        pelvis:      .init(x: 0.52, y: 0.68),
        leftElbow:   .init(x: 0.46, y: 0.78),
        rightElbow:  .init(x: 0.68, y: 0.38),
        leftHand:    .init(x: 0.40, y: 0.88),
        rightHand:   .init(x: 0.84, y: 0.16),
        leftKnee:    .init(x: 0.32, y: 0.84),
        rightKnee:   .init(x: 0.66, y: 0.78),
        leftFoot:    .init(x: 0.18, y: 0.92),
        rightFoot:   .init(x: 0.70, y: 0.92)
    )

    /// Standing calf wall press — back leg straight, heel pressed back
    /// toward the ground, hands on an implied wall ahead.
    static let calfWall = AthletePose(
        head:        .init(x: 0.50, y: 0.20),
        chest:       .init(x: 0.50, y: 0.36),
        pelvis:      .init(x: 0.52, y: 0.55),
        leftElbow:   .init(x: 0.40, y: 0.44),
        rightElbow:  .init(x: 0.60, y: 0.46),
        leftHand:    .init(x: 0.30, y: 0.32),
        rightHand:   .init(x: 0.70, y: 0.34),
        leftKnee:    .init(x: 0.60, y: 0.72),
        rightKnee:   .init(x: 0.36, y: 0.78),
        leftFoot:    .init(x: 0.64, y: 0.92),
        rightFoot:   .init(x: 0.20, y: 0.92)
    )

    /// Side-lying T-spine windmill — torso open to the ceiling, top arm
    /// reaching out and back. Approximated as a deep cross-body
    /// rotation for the side profile renderer.
    static let tSpineWindmill = AthletePose(
        head:        .init(x: 0.45, y: 0.32),
        chest:       .init(x: 0.52, y: 0.46),
        pelvis:      .init(x: 0.55, y: 0.66),
        leftElbow:   .init(x: 0.36, y: 0.52),
        rightElbow:  .init(x: 0.74, y: 0.42),
        leftHand:    .init(x: 0.22, y: 0.42),
        rightHand:   .init(x: 0.88, y: 0.22),
        leftKnee:    .init(x: 0.48, y: 0.78),
        rightKnee:   .init(x: 0.60, y: 0.78),
        leftFoot:    .init(x: 0.42, y: 0.92),
        rightFoot:   .init(x: 0.62, y: 0.92)
    )

    /// 90/90 hip seat — front and back legs both at 90°, torso upright.
    /// Side profile shows the front knee out, back knee tucked behind.
    static let nineNinety = AthletePose(
        head:        .init(x: 0.50, y: 0.22),
        chest:       .init(x: 0.50, y: 0.40),
        pelvis:      .init(x: 0.50, y: 0.62),
        leftElbow:   .init(x: 0.40, y: 0.58),
        rightElbow:  .init(x: 0.60, y: 0.58),
        leftHand:    .init(x: 0.32, y: 0.72),
        rightHand:   .init(x: 0.68, y: 0.72),
        leftKnee:    .init(x: 0.32, y: 0.78),
        rightKnee:   .init(x: 0.74, y: 0.74),
        leftFoot:    .init(x: 0.18, y: 0.92),
        rightFoot:   .init(x: 0.84, y: 0.84)
    )
}

#Preview {
    NavigationStack {
        MobilityAnimationPreview()
            .environmentObject(LanguageManager.shared)
    }
}
