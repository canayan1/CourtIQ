import SwiftUI

// MARK: - TennisBall
// Radial-gradient yellow ball with two felt seams.
struct TennisBall: View {
    var withShadow: Bool = false

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                if withShadow {
                    Ellipse()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: s * 0.72, height: s * 0.08)
                        .offset(y: s * 0.42)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 245/255, green: 255/255, blue: 154/255),
                                Color(red: 216/255, green: 232/255, blue:  78/255),
                                Color(red: 126/255, green: 152/255, blue:  24/255)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: s * 0.78
                        )
                    )

                // Felt seams — two opposing curves
                FeltSeam(flipped: false)
                    .stroke(Color(red: 252/255, green: 250/255, blue: 234/255),
                            style: StrokeStyle(lineWidth: s * 0.024, lineCap: .round))
                    .opacity(0.95)
                FeltSeam(flipped: true)
                    .stroke(Color(red: 252/255, green: 250/255, blue: 234/255),
                            style: StrokeStyle(lineWidth: s * 0.024, lineCap: .round))
                    .opacity(0.95)

                // Highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                            center: UnitPoint(x: 0.32, y: 0.22),
                            startRadius: 0,
                            endRadius: s * 0.5
                        )
                    )

                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.8)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct FeltSeam: Shape {
    var flipped: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        if !flipped {
            p.move(to: CGPoint(x: 0.14 * w, y: 0.38 * h))
            p.addQuadCurve(to: CGPoint(x: 0.50 * w, y: 0.50 * h),
                           control: CGPoint(x: 0.32 * w, y: 0.50 * h))
            p.addQuadCurve(to: CGPoint(x: 0.86 * w, y: 0.64 * h),
                           control: CGPoint(x: 0.68 * w, y: 0.50 * h))
        } else {
            p.move(to: CGPoint(x: 0.14 * w, y: 0.64 * h))
            p.addQuadCurve(to: CGPoint(x: 0.50 * w, y: 0.50 * h),
                           control: CGPoint(x: 0.32 * w, y: 0.50 * h))
            p.addQuadCurve(to: CGPoint(x: 0.86 * w, y: 0.38 * h),
                           control: CGPoint(x: 0.68 * w, y: 0.50 * h))
        }
        return p
    }
}

// MARK: - TennisRacket
// Stylized racket with head, strings, throat, grip.
struct TennisRacket: View {
    var color: Color = AppPalette.ink
    var accent: Color = AppPalette.clay
    var angle: Double = -30

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Head
                Ellipse()
                    .stroke(color, lineWidth: max(2, w * 0.05))
                    .frame(width: w * 0.64, height: h * 0.55)
                    .position(x: w * 0.5, y: h * 0.32)

                // Strings
                ForEach(0..<6, id: \.self) { i in
                    let dx = (Double(i) - 2.5) * (w * 0.08)
                    Rectangle()
                        .fill(color.opacity(0.25))
                        .frame(width: 0.9, height: h * 0.5)
                        .position(x: w * 0.5 + dx, y: h * 0.32)
                }
                ForEach(0..<8, id: \.self) { i in
                    let dy = (Double(i) - 3.5) * (h * 0.06)
                    Rectangle()
                        .fill(color.opacity(0.25))
                        .frame(width: w * 0.55, height: 0.9)
                        .position(x: w * 0.5, y: h * 0.32 + dy)
                }

                // Throat
                Path { p in
                    p.move(to: CGPoint(x: w * 0.36, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.74))
                    p.move(to: CGPoint(x: w * 0.64, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.74))
                }
                .stroke(color, style: StrokeStyle(lineWidth: max(2, w * 0.05), lineCap: .round))

                // Grip
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: w * 0.08, height: h * 0.27)
                    .position(x: w * 0.5, y: h * 0.86)

                // Butt cap
                RoundedRectangle(cornerRadius: 1)
                    .fill(accent)
                    .frame(width: w * 0.12, height: 3)
                    .position(x: w * 0.5, y: h * 0.985)
            }
            .rotationEffect(.degrees(angle))
        }
    }
}

// MARK: - CourtPerspective
// Low-angle court trapezoid hero (sky + floor gradient + lines + net).
struct CourtPerspective: View {
    var surface: AppPalette.CourtSurface = .clay

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Sky
                LinearGradient(colors: [surface.sky, surface.base],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h * 0.4)
                    .position(x: w / 2, y: h * 0.2)

                // Floor
                LinearGradient(colors: [surface.base, surface.dark],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h * 0.6)
                    .position(x: w / 2, y: h * 0.7)

                // Court trapezoid lines
                Path { p in
                    let baseY = h * 0.4
                    let leftTop = w * 0.2, rightTop = w * 0.8
                    let leftBot = -w * 0.15, rightBot = w * 1.15

                    // Far baseline
                    p.move(to: CGPoint(x: leftTop, y: baseY))
                    p.addLine(to: CGPoint(x: rightTop, y: baseY))
                    // Sidelines
                    p.move(to: CGPoint(x: leftTop, y: baseY))
                    p.addLine(to: CGPoint(x: leftBot, y: h))
                    p.move(to: CGPoint(x: rightTop, y: baseY))
                    p.addLine(to: CGPoint(x: rightBot, y: h))
                    // Service line
                    p.move(to: CGPoint(x: w * 0.3, y: h * 0.57))
                    p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.57))
                    // Center service line
                    p.move(to: CGPoint(x: w / 2, y: baseY))
                    p.addLine(to: CGPoint(x: w / 2, y: h * 0.57))
                }
                .stroke(surface.line.opacity(0.85), lineWidth: 1.6)

                // Front baseline
                Rectangle()
                    .fill(surface.line)
                    .frame(width: w * 1.4, height: 3)
                    .position(x: w / 2, y: h - 1.5)

                // Net suggestion (top of trapezoid)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: w * 0.6, height: 10)
                    .position(x: w / 2, y: h * 0.4)
                Rectangle()
                    .fill(surface.line.opacity(0.9))
                    .frame(width: w * 0.6, height: 3)
                    .position(x: w / 2, y: h * 0.4)
            }
            .clipped()
        }
    }
}

// MARK: - CourtTopDown
// Full singles+doubles court diagram with net mesh.
struct CourtTopDown: View {
    var surface: AppPalette.CourtSurface = .clay
    var lineOpacity: Double = 1.0

    /// Coordinate convention (CRITICAL — drill JSON depends on it):
    ///
    ///   The doubles-court rectangle FILLS the rendered container so
    ///   that callers can position markers (YOU / OP / ball) in
    ///   normalized [0, 1] coordinates that map cleanly onto the court:
    ///
    ///     y = 0.000  top baseline (opponent's end)
    ///     y = 0.231  top service line   (6.40m of 11.89m = 53.8%)
    ///     y = 0.500  net
    ///     y = 0.769  bottom service line
    ///     y = 1.000  bottom baseline (your end)
    ///
    ///     x = 0.000  left doubles sideline
    ///     x = 0.125  left singles sideline   (8.23m / 10.97m = 75%)
    ///     x = 0.500  centre mark
    ///     x = 0.875  right singles sideline
    ///     x = 1.000  right doubles sideline
    ///
    ///   These ratios mirror ITF singles-court geometry — singles
    ///   service line is 6.40m from a 11.89m half-court, singles court
    ///   width is 8.23m of the 10.97m doubles total. The 1:2.17 aspect
    ///   ratio (10.97/23.77 = 0.462 → height/width = 2.17) of a true
    ///   doubles court is best honoured by sizing the container at a
    ///   width:height of roughly 140:303 (drill view uses 140×360 to
    ///   allow some letterbox).
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [surface.base, surface.dark],
                               startPoint: .top, endPoint: .bottom)

                Canvas { ctx, size in
                    let line = surface.line.opacity(lineOpacity)
                    let w = size.width, h = size.height

                    // Outer doubles court — the rectangle fills the
                    // entire container so external markers can rely on
                    // [0,1] normalized coords.
                    let outer = CGRect(x: 0, y: 0, width: w, height: h)
                    ctx.stroke(Path(outer), with: .color(line), lineWidth: 2)

                    // Singles sidelines (inset 12.5% from each side).
                    let leftSingles = w * 0.125
                    let rightSingles = w * 0.875
                    var sidelines = Path()
                    sidelines.move(to: CGPoint(x: leftSingles, y: 0))
                    sidelines.addLine(to: CGPoint(x: leftSingles, y: h))
                    sidelines.move(to: CGPoint(x: rightSingles, y: 0))
                    sidelines.addLine(to: CGPoint(x: rightSingles, y: h))
                    ctx.stroke(sidelines, with: .color(line), lineWidth: 1.6)

                    // Service lines at ITF-correct 53.8% of half-court
                    // distance from the net (= 6.40m of 11.89m).
                    let topServiceY = h * 0.231
                    let bottomServiceY = h * 0.769
                    var service = Path()
                    service.move(to: CGPoint(x: leftSingles, y: topServiceY))
                    service.addLine(to: CGPoint(x: rightSingles, y: topServiceY))
                    service.move(to: CGPoint(x: leftSingles, y: bottomServiceY))
                    service.addLine(to: CGPoint(x: rightSingles, y: bottomServiceY))
                    // Centre service line runs net-to-service-line on
                    // both sides; the gap in the middle is the net itself.
                    service.move(to: CGPoint(x: w / 2, y: topServiceY))
                    service.addLine(to: CGPoint(x: w / 2, y: bottomServiceY))
                    ctx.stroke(service, with: .color(line), lineWidth: 1.4)

                    // Centre marks on both baselines — small 4 pt ticks.
                    var centreMarks = Path()
                    centreMarks.move(to: CGPoint(x: w / 2, y: 0))
                    centreMarks.addLine(to: CGPoint(x: w / 2, y: 4))
                    centreMarks.move(to: CGPoint(x: w / 2, y: h - 4))
                    centreMarks.addLine(to: CGPoint(x: w / 2, y: h))
                    ctx.stroke(centreMarks, with: .color(line), lineWidth: 2)

                    // Net — thicker line + soft mesh band.
                    var net = Path()
                    net.move(to: CGPoint(x: 0, y: h / 2))
                    net.addLine(to: CGPoint(x: w, y: h / 2))
                    ctx.stroke(net, with: .color(line), lineWidth: 3)
                    let mesh = CGRect(x: 0, y: h / 2 - 6, width: w, height: 12)
                    ctx.fill(Path(mesh), with: .color(.white.opacity(0.07)))
                }
            }
        }
    }
}

// MARK: - CourtLinesBg
// Decorative low-opacity court lines (no fill, used as watermark).
struct CourtLinesBg: View {
    var color: Color = .white.opacity(0.12)
    var orientation: Axis = .vertical

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Canvas { ctx, size in
                if orientation == .horizontal {
                    let outer = CGRect(x: size.width * 0.05, y: size.height * 0.07,
                                       width: size.width * 0.9, height: size.height * 0.86)
                    ctx.stroke(Path(outer), with: .color(color), lineWidth: 1.5)
                    let inner = outer.insetBy(dx: 0, dy: size.height * 0.14)
                    ctx.stroke(Path(inner), with: .color(color), lineWidth: 1.2)
                    var p = Path()
                    p.move(to: CGPoint(x: size.width / 2, y: inner.minY))
                    p.addLine(to: CGPoint(x: size.width / 2, y: inner.maxY))
                    p.move(to: CGPoint(x: outer.minX, y: size.height / 2))
                    p.addLine(to: CGPoint(x: outer.maxX, y: size.height / 2))
                    ctx.stroke(p, with: .color(color), lineWidth: 1.5)
                } else {
                    let outer = CGRect(x: size.width * 0.07, y: size.height * 0.04,
                                       width: size.width * 0.86, height: size.height * 0.92)
                    ctx.stroke(Path(outer), with: .color(color), lineWidth: 1.5)
                    let inner = outer.insetBy(dx: 0, dy: size.height * 0.12)
                    ctx.stroke(Path(inner), with: .color(color), lineWidth: 1.2)
                    var p = Path()
                    p.move(to: CGPoint(x: size.width / 2, y: inner.minY))
                    p.addLine(to: CGPoint(x: size.width / 2, y: inner.maxY))
                    p.move(to: CGPoint(x: outer.minX, y: size.height / 2))
                    p.addLine(to: CGPoint(x: outer.maxX, y: size.height / 2))
                    ctx.stroke(p, with: .color(color), lineWidth: 1.5)
                }
                _ = w; _ = h
            }
        }
    }
}

// MARK: - TrajectoryArc
// Dashed parabolic arc (for hero / quiz scenarios).
struct TrajectoryArc: View {
    var color: Color = .white
    var dashed: Bool = true
    var lineWidth: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width, h = geo.size.height
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.9))
                p.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.5),
                               control: CGPoint(x: w * 0.5, y: -h * 0.15))
            }
            .stroke(color.opacity(0.85),
                    style: StrokeStyle(lineWidth: lineWidth,
                                       lineCap: .round,
                                       dash: dashed ? [2, 10] : []))
        }
    }
}

// MARK: - StreakRing
struct StreakRing: View {
    var value: Int
    var maxValue: Int = 30
    var color: Color = AppPalette.clay
    var trackColor: Color = Color.white.opacity(0.18)

    private var fraction: CGFloat {
        CGFloat(min(max(value, 0), maxValue)) / CGFloat(maxValue)
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: s * 0.06)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: s * 0.06, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: s * 0.32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("DAYS")
                        .appFont(10, weight: .heavy)
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - QuizCourtDiagramView
//
// Editorial-style quiz court header. A single dimensionally-honest (doubles
// ratio 1:2.17) top-down court rendered at 120×260pt, centered horizontally
// inside a parchment frame. Side margins are intentional whitespace so the
// court reads as an illustration, not a wallpaper.
//
// Normalized diagram coordinates (youX/Y, opponentX/Y, ballOriginX/Y,
// ballTargetX/Y in [0,1]) are interpreted against the 120×260 court box,
// not the wider parchment region. The score chip lives in the parchment
// side margin (top-left) so it never overlaps the court.
struct QuizCourtDiagramView: View {
    var diagram: QuizCourtDiagram

    // Dimensional constants — the court is the focal element, parchment
    // simply gives it room to breathe.
    private let courtWidth: CGFloat = 120
    private let courtHeight: CGFloat = 260
    private let topPadding: CGFloat = 14
    private let bottomPadding: CGFloat = 14

    private var surface: AppPalette.CourtSurface {
        switch diagram.surface {
        case "grass": return .grass
        case "hard":  return .hard
        case "night": return .night
        case "cream": return .cream
        default:      return .clay
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Parchment fills the diagram region. The card itself is also
            // parchment, so visually this is one continuous surface.
            AppPalette.parchment

            // The court — rounded, shadowed, centered.
            courtIllustration
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Score chip lives in the parchment side margin (top-left).
            if let chip = diagram.scoreChip, !chip.isEmpty {
                Text(chip)
                    .appFont(10, weight: .heavy)
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(AppPalette.ink.opacity(0.85))
                    )
                    .padding(.leading, 16)
                    .padding(.top, 16)
            }
        }
        .frame(height: courtHeight + topPadding + bottomPadding)
    }

    /// The court block itself — fixed 120×260, surface fill via
    /// `CourtTopDown`, rounded with a soft shadow, and overlaid with
    /// markers + dashed trajectory positioned in the same 120×260 frame.
    private var courtIllustration: some View {
        ZStack(alignment: .topLeading) {
            CourtTopDown(surface: surface, lineOpacity: 0.95)
                .frame(width: courtWidth, height: courtHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(surface.line.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: AppPalette.ink.opacity(0.18), radius: 14, x: 0, y: 6)

            // Marker + trajectory layer — same 120×260 frame so normalized
            // coords land correctly on the court.
            markerOverlay
                .frame(width: courtWidth, height: courtHeight)
        }
        .frame(width: courtWidth, height: courtHeight)
    }

    @ViewBuilder
    private var markerOverlay: some View {
        ZStack {
            // Dashed incoming-ball trajectory — drawn only when all four
            // origin/target coords are non-nil (mental category default
            // has nil here and we render nothing).
            if let ox = diagram.ballOriginX, let oy = diagram.ballOriginY,
               let tx = diagram.ballTargetX, let ty = diagram.ballTargetY {
                Path { p in
                    p.move(to: CGPoint(x: ox * courtWidth, y: oy * courtHeight))
                    p.addQuadCurve(
                        to: CGPoint(x: tx * courtWidth, y: ty * courtHeight),
                        control: CGPoint(x: ((ox + tx) / 2) * courtWidth,
                                         y: (min(oy, ty) - 0.20) * courtHeight)
                    )
                }
                .stroke(Color.white.opacity(0.88),
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [3, 7]))
                .shadow(color: .black.opacity(0.25), radius: 1.5)
            }

            // Opponent marker — only when authored (mental questions skip it)
            if let ox = diagram.opponentX, let oy = diagram.opponentY {
                courtMarker(label: "OP",
                            color: .white,
                            fill: AppPalette.ink.opacity(0.88))
                    .position(x: ox * courtWidth, y: oy * courtHeight)
            }

            // YOU marker — always rendered
            courtMarker(label: "YOU",
                        color: .white,
                        fill: AppPalette.clay)
                .position(x: diagram.youX * courtWidth, y: diagram.youY * courtHeight)
        }
    }

    private func courtMarker(label: String, color: Color, fill: Color) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1.6))
                .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 2)
            Text(label)
                .appFont(9, weight: .heavy)
                .tracking(0.5)
                .foregroundStyle(color)
        }
    }
}

// MARK: - TennisGlyph
// Sport-specific iconography. Use as a `View`.
enum TennisGlyphKind {
    case court, racket, ball, serve, forehand, backhand, volley, mobility, flame, trophy, target
}

struct TennisGlyph: View {
    var kind: TennisGlyphKind
    var color: Color = AppPalette.ink
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch kind {
            case .court:    courtGlyph
            case .racket:   racketGlyph
            case .ball:     ballGlyph
            case .serve:    serveGlyph
            case .forehand: forehandGlyph
            case .backhand: backhandGlyph
            case .volley:   volleyGlyph
            case .mobility: mobilityGlyph
            case .flame:    flameGlyph
            case .trophy:   trophyGlyph
            case .target:   targetGlyph
            }
        }
        .frame(width: size, height: size)
    }

    // 24x24 viewBox conventions
    private var courtGlyph: some View {
        Canvas { ctx, sz in
            let r = CGRect(x: sz.width * 0.125, y: sz.height * 0.125,
                           width: sz.width * 0.75, height: sz.height * 0.75)
            ctx.stroke(Path(roundedRect: r, cornerRadius: sz.width * 0.06),
                       with: .color(color), lineWidth: 1.7)
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            ctx.stroke(p, with: .color(color), lineWidth: 2)
            ctx.stroke(Path(CGRect(x: r.minX + r.width * 0.17, y: r.minY + r.height * 0.17,
                                   width: r.width * 0.66, height: r.height * 0.33)),
                       with: .color(color), lineWidth: 1.7)
            ctx.stroke(Path(CGRect(x: r.minX + r.width * 0.17, y: r.midY,
                                   width: r.width * 0.66, height: r.height * 0.33)),
                       with: .color(color), lineWidth: 1.7)
            var c = Path()
            c.move(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.17))
            c.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.17))
            ctx.stroke(c, with: .color(color), lineWidth: 1.7)
        }
    }

    private var racketGlyph: some View {
        Canvas { ctx, sz in
            let cx = sz.width * 0.4, cy = sz.height * 0.38
            let rx = sz.width * 0.27, ry = sz.height * 0.29
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)),
                       with: .color(color), lineWidth: 1.7)
            var strings = Path()
            for dx in stride(from: -rx + 4, through: rx - 4, by: rx / 3) {
                strings.move(to: CGPoint(x: cx + dx, y: cy - ry + 4))
                strings.addLine(to: CGPoint(x: cx + dx, y: cy + ry - 4))
            }
            for dy in stride(from: -ry + 4, through: ry - 4, by: ry / 3) {
                strings.move(to: CGPoint(x: cx - rx + 4, y: cy + dy))
                strings.addLine(to: CGPoint(x: cx + rx - 4, y: cy + dy))
            }
            ctx.stroke(strings, with: .color(color.opacity(0.5)), lineWidth: 0.8)

            // Handle to bottom-right corner
            var handle = Path()
            handle.move(to: CGPoint(x: cx + rx * 0.7, y: cy + ry * 0.7))
            handle.addLine(to: CGPoint(x: sz.width * 0.88, y: sz.height * 0.88))
            ctx.stroke(handle, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    private var ballGlyph: some View {
        Canvas { ctx, sz in
            let r = CGRect(x: sz.width * 0.125, y: sz.height * 0.125,
                           width: sz.width * 0.75, height: sz.height * 0.75)
            ctx.fill(Path(ellipseIn: r), with: .color(color))
            var seam = Path()
            seam.move(to: CGPoint(x: r.minX, y: r.midY - r.height * 0.15))
            seam.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY + r.height * 0.07),
                              control: CGPoint(x: r.midX, y: r.midY + r.height * 0.05))
            seam.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.15))
            seam.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY - r.height * 0.07),
                              control: CGPoint(x: r.midX, y: r.midY - r.height * 0.05))
            ctx.stroke(seam, with: .color(.white.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    private var serveGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.18, y: sz.height * 0.83))
            p.addQuadCurve(to: CGPoint(x: sz.width * 0.83, y: sz.height * 0.33),
                           control: CGPoint(x: sz.width * 0.5, y: sz.height * 0.25))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.72, y: sz.height * 0.22,
                                            width: sz.width * 0.22, height: sz.width * 0.22)),
                     with: .color(color))
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.12, y: sz.height * 0.78,
                                            width: sz.width * 0.12, height: sz.width * 0.12)),
                     with: .color(color))
        }
    }

    private var forehandGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.13, y: sz.height * 0.75))
            p.addQuadCurve(to: CGPoint(x: sz.width * 0.58, y: sz.height * 0.21),
                           control: CGPoint(x: sz.width * 0.3, y: sz.height * 0.33))
            p.addLine(to: CGPoint(x: sz.width * 0.88, y: sz.height * 0.38))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.07, y: sz.height * 0.69,
                                            width: sz.width * 0.13, height: sz.width * 0.13)),
                     with: .color(color))
        }
    }

    private var backhandGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.13, y: sz.height * 0.38))
            p.addQuadCurve(to: CGPoint(x: sz.width * 0.88, y: sz.height * 0.75),
                           control: CGPoint(x: sz.width * 0.5, y: sz.height * 0.21))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.07, y: sz.height * 0.32,
                                            width: sz.width * 0.13, height: sz.width * 0.13)),
                     with: .color(color))
        }
    }

    private var volleyGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.17, y: sz.height * 0.5))
            p.addLine(to: CGPoint(x: sz.width * 0.42, y: sz.height * 0.5))
            p.addLine(to: CGPoint(x: sz.width * 0.58, y: sz.height * 0.33))
            p.addLine(to: CGPoint(x: sz.width * 0.58, y: sz.height * 0.67))
            p.addLine(to: CGPoint(x: sz.width * 0.42, y: sz.height * 0.5))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            var line = Path()
            line.move(to: CGPoint(x: sz.width * 0.58, y: sz.height * 0.5))
            line.addLine(to: CGPoint(x: sz.width * 0.83, y: sz.height * 0.5))
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.78, y: sz.height * 0.44,
                                            width: sz.width * 0.13, height: sz.width * 0.13)),
                     with: .color(color))
        }
    }

    private var mobilityGlyph: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.42, y: sz.height * 0.08,
                                            width: sz.width * 0.16, height: sz.width * 0.16)),
                     with: .color(color))
            var body = Path()
            body.move(to: CGPoint(x: sz.width * 0.33, y: sz.height * 0.33))
            body.addLine(to: CGPoint(x: sz.width * 0.5,  y: sz.height * 0.29))
            body.addLine(to: CGPoint(x: sz.width * 0.66, y: sz.height * 0.33))
            body.move(to: CGPoint(x: sz.width * 0.5, y: sz.height * 0.29))
            body.addLine(to: CGPoint(x: sz.width * 0.5, y: sz.height * 0.58))
            body.addLine(to: CGPoint(x: sz.width * 0.33, y: sz.height * 0.83))
            body.move(to: CGPoint(x: sz.width * 0.5, y: sz.height * 0.58))
            body.addLine(to: CGPoint(x: sz.width * 0.66, y: sz.height * 0.83))
            ctx.stroke(body, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    private var flameGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.5, y: sz.height * 0.13))
            p.addCurve(to: CGPoint(x: sz.width * 0.67, y: sz.height * 0.54),
                       control1: CGPoint(x: sz.width * 0.5, y: sz.height * 0.33),
                       control2: CGPoint(x: sz.width * 0.67, y: sz.height * 0.38))
            p.addArc(center: CGPoint(x: sz.width * 0.5, y: sz.height * 0.65),
                     radius: sz.width * 0.17,
                     startAngle: .degrees(-30), endAngle: .degrees(210), clockwise: false)
            p.addCurve(to: CGPoint(x: sz.width * 0.42, y: sz.height * 0.33),
                       control1: CGPoint(x: sz.width * 0.33, y: sz.height * 0.46),
                       control2: CGPoint(x: sz.width * 0.42, y: sz.height * 0.42))
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
        }
    }

    private var trophyGlyph: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: sz.width * 0.29, y: sz.height * 0.13))
            p.addLine(to: CGPoint(x: sz.width * 0.71, y: sz.height * 0.13))
            p.addLine(to: CGPoint(x: sz.width * 0.71, y: sz.height * 0.38))
            p.addArc(center: CGPoint(x: sz.width * 0.5, y: sz.height * 0.38),
                     radius: sz.width * 0.21,
                     startAngle: .zero, endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
            ctx.fill(p, with: .color(color))
            ctx.fill(Path(CGRect(x: sz.width * 0.42, y: sz.height * 0.58,
                                 width: sz.width * 0.16, height: sz.height * 0.13)),
                     with: .color(color))
            ctx.fill(Path(roundedRect: CGRect(x: sz.width * 0.29, y: sz.height * 0.71,
                                              width: sz.width * 0.42, height: sz.height * 0.13),
                          cornerRadius: 2),
                     with: .color(color))
        }
    }

    private var targetGlyph: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            for r in [sz.width * 0.38, sz.width * 0.23] {
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r,
                                                  width: r * 2, height: r * 2)),
                           with: .color(color), lineWidth: 1.6)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)),
                     with: .color(color))
        }
    }
}
