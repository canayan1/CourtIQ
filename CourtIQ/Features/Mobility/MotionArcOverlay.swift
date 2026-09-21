import SwiftUI

// MotionArcOverlay (and the symbol-kind enum it draws with) is used by the
// production HybridMobilityFigure. It was defined inside
// FigureApproachComparison.swift, a throwaway comparison view, which is why
// that view was being compiled into the app. Now it is not.

/// Curated SF Symbol set for mobility/training poses. Each case carries
/// the actual `systemName` string so the SF Symbol callers don't sprinkle
/// magic strings.
enum FigureSymbolKind {
    case flexibility, cooldown, yoga, mindBody, pilates,
         dance, tennis, strengthFunctional, crossTraining,
         barre, core, run, walk, stand, stretch, rolling

    var symbolName: String {
        switch self {
        case .flexibility:        return "figure.flexibility"
        case .cooldown:           return "figure.cooldown"
        case .yoga:               return "figure.yoga"
        case .mindBody:           return "figure.mind.and.body"
        case .pilates:            return "figure.pilates"
        case .dance:              return "figure.dance"
        case .tennis:             return "figure.tennis"
        case .strengthFunctional: return "figure.strengthtraining.functional"
        case .crossTraining:      return "figure.cross.training"
        case .barre:              return "figure.barre"
        case .core:               return "figure.core.training"
        case .run:                return "figure.run"
        case .walk:               return "figure.walk"
        case .stand:              return "figure.stand"
        case .stretch:            return "figure.flexibility"     // alias
        case .rolling:            return "figure.rolling"
        }
    }
}

/// Standalone curve+arrowhead overlay so the hybrid approach can use it
/// independently of AthleteFigureCanvas. Lives in absolute pixel space
/// — caller positions the start/end/control relative to its frame center.
struct MotionArcOverlay: View {
    let start: CGPoint
    let end: CGPoint
    let control: CGPoint
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let s = CGPoint(x: cx + start.x, y: cy + start.y)
            let e = CGPoint(x: cx + end.x, y: cy + end.y)
            let c = CGPoint(x: cx + control.x, y: cy + control.y)

            Path { p in
                p.move(to: s)
                p.addQuadCurve(to: e, control: c)
            }
            .stroke(color.opacity(0.85),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Arrowhead
            arrowhead(at: e, tangent: CGPoint(x: e.x - c.x, y: e.y - c.y))
        }
    }

    private func arrowhead(at end: CGPoint, tangent: CGPoint) -> some View {
        let len = max(sqrt(tangent.x * tangent.x + tangent.y * tangent.y), 0.0001)
        let tnx = tangent.x / len
        let tny = tangent.y / len
        let headSize: CGFloat = 14
        let cos30: CGFloat = 0.866
        let sin30: CGFloat = 0.5
        let leftDX  = -tnx * cos30 - tny * sin30
        let leftDY  = -tny * cos30 + tnx * sin30
        let rightDX = -tnx * cos30 + tny * sin30
        let rightDY = -tny * cos30 - tnx * sin30

        return Path { p in
            p.move(to: end)
            p.addLine(to: CGPoint(x: end.x + leftDX * headSize,
                                  y: end.y + leftDY * headSize))
            p.move(to: end)
            p.addLine(to: CGPoint(x: end.x + rightDX * headSize,
                                  y: end.y + rightDY * headSize))
        }
        .stroke(color.opacity(0.85),
                style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}
