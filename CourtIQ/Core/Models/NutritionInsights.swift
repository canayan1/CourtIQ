import Foundation

/// One honest comparison: "when you did A you averaged x over n sessions;
/// when you did B, y over m." Nothing is inferred beyond the player's own
/// averages, and nothing is shown until both sides have enough sessions to
/// mean something.
struct NutritionInsight: Identifiable, Hashable {
    enum Dimension: String, CaseIterable {
        case timing, meal, hydration, caffeine
        var labelKey: String { "nutrition.dim_\(rawValue)" }
    }

    let dimension: Dimension
    let betterLabelKey: String
    let betterMean: Double
    let betterCount: Int
    let worseLabelKey: String
    let worseMean: Double
    let worseCount: Int

    var gap: Double { betterMean - worseMean }
    var id: String { "\(dimension.rawValue)-\(betterLabelKey)-\(worseLabelKey)" }
}

/// Pure functions over rated entries. Kept free of the manager so the rules
/// can be unit-tested once a test target exists, and so the thresholds are
/// in one place.
enum NutritionInsights {
    /// A bucket needs this many rated sessions before it may be compared.
    static let minimumSessions = 5
    /// Below this gap in the 1–5 composite, two buckets are "about the same".
    static let minimumGap = 0.5

    static func compute(_ rated: [NutritionEntry]) -> [NutritionInsight] {
        var out: [NutritionInsight] = []
        for dimension in NutritionInsight.Dimension.allCases {
            let groups = Dictionary(grouping: rated) { bucketKey($0, dimension) }
                .compactMapValues { entries -> (mean: Double, n: Int)? in
                    guard entries.count >= minimumSessions else { return nil }
                    let mean = entries.compactMap { $0.ratings?.composite }.reduce(0, +) / Double(entries.count)
                    return (mean, entries.count)
                }
            guard groups.count >= 2,
                  let best = groups.max(by: { $0.value.mean < $1.value.mean }),
                  let worst = groups.min(by: { $0.value.mean < $1.value.mean }),
                  best.key != worst.key,
                  best.value.mean - worst.value.mean >= minimumGap
            else { continue }
            out.append(NutritionInsight(
                dimension: dimension,
                betterLabelKey: best.key, betterMean: best.value.mean, betterCount: best.value.n,
                worseLabelKey: worst.key, worseMean: worst.value.mean, worseCount: worst.value.n))
        }
        // Largest, best-supported difference first.
        return out.sorted { ($0.gap, $0.betterCount + $0.worseCount) > ($1.gap, $1.betterCount + $1.worseCount) }
    }

    /// Overall averages of the four ratings — shown whenever there is at
    /// least one rated session, so the screen is never blank while the
    /// comparisons wait for data.
    static func averages(_ rated: [NutritionEntry]) -> NutritionAverages? {
        let r = rated.compactMap(\.ratings)
        guard !r.isEmpty else { return nil }
        let n = Double(r.count)
        return NutritionAverages(
            energy: r.map { Double($0.energy) }.reduce(0, +) / n,
            legs: r.map { Double($0.legs) }.reduce(0, +) / n,
            focus: r.map { Double($0.focus) }.reduce(0, +) / n,
            stomach: r.map { Double($0.stomach) }.reduce(0, +) / n,
            count: r.count)
    }

    /// How many more rated sessions until the first comparison can appear —
    /// the number the empty state shows instead of a vague "keep logging".
    static func sessionsUntilFirstInsight(_ rated: [NutritionEntry]) -> Int {
        // The cheapest comparison is two buckets of the same dimension each
        // reaching the minimum; the second-largest bucket is the bottleneck.
        var best = Int.max
        for dimension in NutritionInsight.Dimension.allCases {
            let counts = Dictionary(grouping: rated) { bucketKey($0, dimension) }.values.map(\.count).sorted(by: >)
            let first = counts.first ?? 0
            let second = counts.dropFirst().first ?? 0
            let need = max(0, minimumSessions - first) + max(0, minimumSessions - second)
            best = min(best, need)
        }
        return best == Int.max ? minimumSessions * 2 : best
    }

    private static func bucketKey(_ e: NutritionEntry, _ d: NutritionInsight.Dimension) -> String {
        switch d {
        case .timing:    return e.timing?.labelKey ?? "nutrition.kind_rest"
        case .meal:      return e.meal?.labelKey ?? NutritionTiming.nothing.labelKey
        case .hydration: return e.hydration.labelKey
        case .caffeine:  return e.caffeine ? "nutrition.caffeine_yes" : "nutrition.caffeine_no"
        }
    }
}

struct NutritionAverages: Hashable {
    let energy: Double
    let legs: Double
    let focus: Double
    let stomach: Double
    let count: Int
}
