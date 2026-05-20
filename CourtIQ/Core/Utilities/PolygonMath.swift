import CoreGraphics

/// Tiny computational geometry helpers used by the Daily Court Tap Game
/// to decide which scoring zone the user's tap landed in.
///
/// All polygons are arrays of `CGPoint` in normalized court-space `[0, 1]`
/// (matching the convention used by `QuizCourtDiagram`). Convex/concave
/// both supported via the standard ray-casting algorithm.
enum PolygonMath {
    /// Ray-casting point-in-polygon test. Treats the polygon as closed.
    /// Returns `false` for empty / degenerate polygons.
    static func contains(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            let crosses = (pi.y > point.y) != (pj.y > point.y)
            if crosses {
                let slope = (pj.x - pi.x) / (pj.y - pi.y)
                let xAtPoint = pi.x + (point.y - pi.y) * slope
                if point.x < xAtPoint { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Euclidean distance from `point` to the closest edge of `polygon`.
    /// Used as a fallback for "near-miss" yellow scoring when a tap
    /// barely misses the ideal green zone.
    static func minDistanceToEdge(_ point: CGPoint, polygon: [CGPoint]) -> CGFloat {
        guard polygon.count >= 2 else { return .infinity }
        var minDist: CGFloat = .infinity
        for i in 0..<polygon.count {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            minDist = min(minDist, distancePointToSegment(point, a: a, b: b))
        }
        return minDist
    }

    private static func distancePointToSegment(_ p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }
}
