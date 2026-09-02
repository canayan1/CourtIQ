import SwiftUI

/// Renders a `CourtScene` as a tennis court seen from behind the player's
/// baseline — the way tactics are actually drawn on a clipboard.
///
/// This is the app's teaching surface: a beginner learns "recover toward the
/// middle of the angles" from a picture far faster than from a paragraph, so
/// every geometric lesson ships a scene and the text only names what the picture
/// already shows.
///
/// Proportions are compressed lengthwise (a real court is 36×78ft, i.e. an 0.46
/// width/height ratio, which would be a 760pt-tall card on a phone). The
/// compressed 0.8 ratio matches how a court looks through a TV camera and keeps
/// the whole picture on screen without scrolling.
struct CourtDiagram: View {
    let scene: CourtScene
    /// Width / height of the court rectangle.
    var aspect: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size)
                ZStack {
                    surface
                    zoneLayer(in: rect)
                    CourtLines()
                        .stroke(AppPalette.Court.line.opacity(0.95), lineWidth: 1.5)
                    net(in: rect)
                    arrowLayer(in: rect)
                    ballLayer(in: rect)
                    playerLayer(in: rect)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .aspectRatio(aspect, contentMode: .fit)

            if let caption = scene.caption {
                Text(caption)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppPalette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: Layers

    private var surface: some View {
        LinearGradient(
            colors: [AppPalette.Court.surface, AppPalette.Court.surfaceDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func zoneLayer(in rect: CGRect) -> some View {
        ForEach(Array(scene.zones.enumerated()), id: \.offset) { _, zone in
            let frame = CGRect(
                x: zone.x * rect.width,
                y: zone.y * rect.height,
                width: zone.w * rect.width,
                height: zone.h * rect.height
            )
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(zone.tone.color.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(zone.tone.color.opacity(0.95), lineWidth: 2)
                )
                // Label pinned to the top of the zone rather than centred: a
                // centred caption lands on whatever player marker the zone was
                // drawn around, which is exactly the case zones are used for.
                .overlay(alignment: .top) {
                    if let label = zone.label {
                        Text(label)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            .padding(.top, 5)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    private func net(in rect: CGRect) -> some View {
        let y = rect.height * 0.5
        return ZStack {
            Rectangle()
                .fill(AppPalette.Court.net.opacity(0.9))
                .frame(height: 4)
                .position(x: rect.midX, y: y)
            // Posts sit just outside the doubles sidelines.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle()
                    .fill(AppPalette.Court.net)
                    .frame(width: 6, height: 6)
                    .position(x: rect.midX + side * (rect.width / 2 - 1), y: y)
            }
        }
    }

    @ViewBuilder
    private func arrowLayer(in rect: CGRect) -> some View {
        ForEach(Array(scene.arrows.enumerated()), id: \.offset) { index, arrow in
            let from = point(arrow.from, in: rect)
            let to = point(arrow.to, in: rect)

            ArrowShape(from: from, to: to, curved: arrow.kind == .shot)
                .stroke(
                    arrowColor(arrow),
                    style: StrokeStyle(
                        lineWidth: arrow.kind == .shot ? 3.5 : 2.5,
                        lineCap: .round,
                        dash: arrow.kind == .move ? [6, 5] : []
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)

            if let label = arrow.label {
                // Labels are spread along their arrow rather than all sitting at
                // the midpoint: scenes routinely draw two or three shots from the
                // same contact point, and midpoint labels would stack on top of
                // each other.
                let t = Self.labelPositions[index % Self.labelPositions.count]
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppPalette.parchment.opacity(0.94))
                    .clipShape(Capsule())
                    .position(
                        x: from.x + (to.x - from.x) * t,
                        y: from.y + (to.y - from.y) * t
                    )
            }
        }
    }

    /// Fractions along an arrow where its label is placed, cycled by index.
    private static let labelPositions: [CGFloat] = [0.62, 0.36, 0.5, 0.74]

    /// Arrows are drawn on clay, so `neutral` means the court's white line color
    /// rather than a transparent gray that would disappear into the surface.
    private func arrowColor(_ arrow: CourtScene.Arrow) -> Color {
        arrow.tone == .neutral ? AppPalette.Court.line : arrow.tone.color
    }

    @ViewBuilder
    private func ballLayer(in rect: CGRect) -> some View {
        ForEach(Array(scene.balls.enumerated()), id: \.offset) { _, ball in
            let p = point(CourtScene.Point(x: ball.x, y: ball.y), in: rect)
            Circle()
                .fill(AppPalette.gold)
                .overlay(Circle().stroke(AppPalette.ink.opacity(0.7), lineWidth: 1.5))
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .position(x: p.x, y: p.y)
        }
    }

    @ViewBuilder
    private func playerLayer(in rect: CGRect) -> some View {
        ForEach(Array(scene.players.enumerated()), id: \.offset) { _, player in
            let p = point(CourtScene.Point(x: player.x, y: player.y), in: rect)
            VStack(spacing: 3) {
                Circle()
                    .fill(fill(for: player.role))
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)

                if let label = player.label ?? defaultLabel(for: player.role) {
                    Text(label)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        .fixedSize()
                }
            }
            .position(x: p.x, y: p.y)
        }
    }

    private func fill(for role: CourtScene.Marker.Role) -> Color {
        switch role {
        case .you:      return AppPalette.ink
        case .opponent: return AppPalette.parchment
        case .partner:  return AppPalette.mossDeep
        }
    }

    private func defaultLabel(for role: CourtScene.Marker.Role) -> String? {
        switch role {
        case .you:      return "You"
        case .opponent: return nil
        case .partner:  return "Partner"
        }
    }

    // MARK: Geometry

    private func point(_ p: CourtScene.Point, in rect: CGRect) -> CGPoint {
        CGPoint(x: p.x * rect.width, y: p.y * rect.height)
    }

    private var accessibilityDescription: String {
        var parts: [String] = ["Court diagram."]
        if let caption = scene.caption { parts.append(caption) }
        let zoneLabels = scene.zones.compactMap(\.label)
        if !zoneLabels.isEmpty {
            parts.append("Marked areas: " + zoneLabels.joined(separator: ", ") + ".")
        }
        let arrowLabels = scene.arrows.compactMap(\.label)
        if !arrowLabels.isEmpty {
            parts.append("Marked paths: " + arrowLabels.joined(separator: ", ") + ".")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Court markings

/// The permanent white lines of a doubles court, in true proportion inside
/// whatever rectangle it is handed.
private struct CourtLines: Shape {
    /// Singles sidelines sit 4.5ft inside each doubles sideline: 4.5/36.
    static let singlesInset: CGFloat = 0.125
    /// Service lines are 21ft from the net on a 78ft court: 18/78 and 60/78.
    static let serviceFar: CGFloat = 18.0 / 78.0
    static let serviceNear: CGFloat = 60.0 / 78.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let left = Self.singlesInset * w
        let right = (1 - Self.singlesInset) * w

        // Doubles boundary.
        path.addRect(rect)

        // Singles sidelines.
        path.move(to: CGPoint(x: left, y: 0))
        path.addLine(to: CGPoint(x: left, y: h))
        path.move(to: CGPoint(x: right, y: 0))
        path.addLine(to: CGPoint(x: right, y: h))

        // Service lines, singles width only.
        for y in [Self.serviceFar * h, Self.serviceNear * h] {
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }

        // Center service line.
        path.move(to: CGPoint(x: rect.midX, y: Self.serviceFar * h))
        path.addLine(to: CGPoint(x: rect.midX, y: Self.serviceNear * h))

        // Center marks on both baselines.
        let tick = h * 0.022
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: tick))
        path.move(to: CGPoint(x: rect.midX, y: h))
        path.addLine(to: CGPoint(x: rect.midX, y: h - tick))

        return path
    }
}

// MARK: - Arrows

/// A line from → to with an arrowhead. Shots bow slightly toward the outside of
/// the court so a cross-court and a down-the-line shot between the same two
/// points stay visually distinct, and so two shots never overlap into one line.
private struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let curved: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = max(1, sqrt(dx * dx + dy * dy))

        // Direction of travel at the tip — used to orient the arrowhead. For a
        // curved shot that is the tangent from the control point, not the chord.
        var tipDX = dx / length
        var tipDY = dy / length

        if curved {
            // Perpendicular offset, scaled to the shot's length so short balls
            // bow less than baseline-to-baseline drives.
            let bow = length * 0.12
            let control = CGPoint(
                x: (from.x + to.x) / 2 - (dy / length) * bow,
                y: (from.y + to.y) / 2 + (dx / length) * bow
            )
            path.addQuadCurve(to: to, control: control)
            let tangentX = to.x - control.x
            let tangentY = to.y - control.y
            let tangentLength = max(1, sqrt(tangentX * tangentX + tangentY * tangentY))
            tipDX = tangentX / tangentLength
            tipDY = tangentY / tangentLength
        } else {
            path.addLine(to: to)
        }

        // Arrowhead: two barbs swept back from the tip.
        let head: CGFloat = 9
        let spread: CGFloat = 0.5 // radians off the shaft
        let angle = atan2(tipDY, tipDX)
        for side in [-spread, spread] {
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - head * cos(angle + side),
                y: to.y - head * sin(angle + side)
            ))
        }

        return path
    }
}

// MARK: - Preview

#Preview {
    CourtDiagram(scene: CourtScene(
        zones: [.init(x: 0.13, y: 0.0, w: 0.36, h: 0.22, tone: .good, label: "TARGET")],
        arrows: [
            .init(from: .init(x: 0.78, y: 0.94), to: .init(x: 0.28, y: 0.1),
                  kind: .shot, tone: .good, label: "cross"),
            .init(from: .init(x: 0.78, y: 0.94), to: .init(x: 0.5, y: 0.82),
                  kind: .move, tone: .focus, label: "recover")
        ],
        players: [
            .init(x: 0.78, y: 0.94, role: .you),
            .init(x: 0.3, y: 0.06, role: .opponent, label: "Them")
        ],
        balls: [.init(x: 0.28, y: 0.12)],
        caption: "Hit cross-court, then recover to the middle of their angles."
    ))
    .padding(24)
    .background(AppPalette.cream)
}
