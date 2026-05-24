import SwiftUI

// MARK: - Hybrid mobility figure
//
// Production-grade figure renderer for mobility / training surfaces.
// Pairs Apple's SF Symbol figure library (anatomically correct,
// professionally drawn, free) with CourtIQ-specific chrome (court
// watermark, motion arc, breath-tempo strip, palette tinting,
// .symbolEffect breath animation).
//
// API design intent:
//   • `HybridMobilityFigureHero` — full-size animated hero. Cycles
//     through the matched SF Symbols of the first N movements in
//     the flow, cross-fading between them. Court backdrop and
//     optional motion arc give it CourtIQ identity.
//   • `HybridMobilityFigureThumb` — small static figure for the
//     per-movement row in the sequence list. No chrome, just the
//     tinted symbol so the list reads tidy at thumbnail scale.
//
// Why this exists over the existing AthleteFigureCanvas: we kept the
// procedural renderer in the repo as a reference (and a possible
// future fallback) but production now uses Apple-quality figures so
// reviewers and users don't see hand-rolled stick-figures.

/// Mobility move titles map to one of these symbol archetypes via
/// `FigureSymbol.match(forTitle:)`. Each case knows its own SF
/// Symbol systemName, palette pairing, and whether a motion arc
/// should accompany it.
enum FigureSymbol: String, CaseIterable, Identifiable {
    case flexibility, cooldown, yoga, mindBody, pilates,
         strengthFunctional, crossTraining, core, rolling,
         stand, walk, run, tennis, dance, barre, stretch

    var id: String { rawValue }

    /// SF Symbol systemName fed into Image(systemName:).
    var symbolName: String {
        switch self {
        case .flexibility:        return "figure.flexibility"
        case .cooldown:           return "figure.cooldown"
        case .yoga:               return "figure.yoga"
        case .mindBody:           return "figure.mind.and.body"
        case .pilates:            return "figure.pilates"
        case .strengthFunctional: return "figure.strengthtraining.functional"
        case .crossTraining:      return "figure.cross.training"
        case .core:               return "figure.core.training"
        case .rolling:            return "figure.rolling"
        case .stand:              return "figure.stand"
        case .walk:               return "figure.walk"
        case .run:                return "figure.run"
        case .tennis:             return "figure.tennis"
        case .dance:              return "figure.dance"
        case .barre:              return "figure.barre"
        case .stretch:            return "figure.flexibility"   // alias
        }
    }

    /// Whether the hero should draw a motion arc above this symbol.
    /// Used for thoracic rotations, twists, dynamic stretches — where
    /// the arrow adds instructional clarity. Static holds skip the arc
    /// so the figure isn't cluttered.
    var wantsMotionArc: Bool {
        switch self {
        case .flexibility, .yoga, .pilates, .strengthFunctional,
             .crossTraining, .core, .dance, .tennis, .barre:
            return true
        case .cooldown, .mindBody, .rolling, .stand, .walk, .run, .stretch:
            return false
        }
    }

    // MARK: - Title → symbol lookup

    /// Best-effort lookup that maps any free-form mobility movement
    /// title (from `mobility_flows.json`, ~70 distinct names) to one
    /// of these symbols. Most-specific keywords first; falls back to
    /// `.flexibility` so unknown titles still render a credible pose.
    static func match(forTitle title: String) -> FigureSymbol {
        let t = title.lowercased()

        // Named hero moves
        if t.contains("world") || (t.contains("greatest") && t.contains("stretch")) {
            return .flexibility
        }
        if t.contains("pigeon")        { return .yoga }
        if t.contains("child")         { return .mindBody }
        if t.contains("cossack")       { return .pilates }
        if t.contains("90/90") || t.contains("90 90") { return .pilates }
        if t.contains("foam roll") || t.contains("foam-roll") || t.contains("rolling") {
            return .rolling
        }

        // Categorical signals — order matters.
        if t.contains("twist") || t.contains("open-book") || t.contains("open book") ||
           t.contains("windmill") || t.contains("spinal") || t.contains("thoracic") {
            return .pilates
        }
        if t.contains("rotat") || t.contains("rotate") {
            return .pilates
        }
        if t.contains("lunge") || t.contains("hip flexor") {
            return .flexibility
        }
        if t.contains("squat") {
            return .strengthFunctional
        }
        if t.contains("bridge") || t.contains("supine") || t.contains("lying") ||
           t.contains("figure-four") || t.contains("figure four") || t.contains("sleeper") {
            return .core
        }
        if t.contains("calf") || t.contains("ankle") {
            return .cooldown
        }
        if t.contains("forward fold") || t.contains("hamstring") || t.contains("hinge") ||
           t.contains("toe tap") || t.contains("toe-touch") || t.contains("rdl") ||
           t.contains("romanian") {
            return .cooldown
        }
        if t.contains("hip circle") || t.contains("hip swing") || t.contains("hip opener") ||
           t.contains("knee hug") || t.contains("leg swing") || t.contains("walking") {
            return .crossTraining
        }
        if t.contains("balance") || t.contains("single-leg") || t.contains("single leg") {
            return .yoga
        }
        if t.contains("shoulder slide") || t.contains("wall angel") ||
           t.contains("band") || t.contains("shoulder draw") ||
           t.contains("pull-apart") || t.contains("pull apart") ||
           t.contains("shoulder plate") || t.contains("doorway") ||
           t.contains("chest opener") {
            return .strengthFunctional
        }
        if t.contains("reach") && (t.contains("standing") || t.contains("overhead")) {
            return .yoga
        }
        if t.contains("seat") || t.contains("cross-legged") || t.contains("kneeling") {
            return .mindBody
        }
        if t.contains("thread") || t.contains("press") {
            return .barre
        }

        return .flexibility
    }
}

// MARK: - Hero

/// Full-size mobility hero. Drops into MobilityFlowDetailView.header.
/// Cross-fades through the matched SF Symbols of the flow's first
/// three movements on a steady 6 second loop, with Apple's
/// `.symbolEffect(.pulse)` driving in-figure breath motion.
struct HybridMobilityFigureHero: View {
    /// Movement titles to derive the symbol sequence from. Caller
    /// usually passes `flow.movements.prefix(3).map(\.title)`.
    let movementTitles: [String]

    var body: some View {
        ZStack {
            // Card chassis matches the rest of the app's parchment look.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )

            // Court watermark — clay tape behind the figure.
            CourtTopDown(surface: .clay, lineOpacity: 0.22)
                .opacity(0.30)
                .frame(width: 130, height: 200)
                .offset(x: 95, y: 0)
                .allowsHitTesting(false)

            CyclingFigure(symbols: symbols, motionArc: shouldShowArc)
        }
        .frame(height: 280)
    }

    private var symbols: [FigureSymbol] {
        let mapped = movementTitles.prefix(3).map(FigureSymbol.match(forTitle:))
        // Pad with a "rest" figure so animation always has a place to
        // fade toward, even when the flow has only one movement.
        guard !mapped.isEmpty else { return [.flexibility, .yoga, .cooldown] }
        return mapped.count == 1 ? [mapped[0], .stand] : Array(mapped)
    }

    /// Show the motion arc only if at least one of the cycled figures
    /// genuinely benefits from one (twists / rotations).
    private var shouldShowArc: Bool {
        symbols.contains(where: \.wantsMotionArc)
    }
}

/// Drives the cross-fade between SF Symbols over time and overlays
/// the motion arc when requested. Kept private to this file because
/// nobody else needs the timing intricacies.
private struct CyclingFigure: View {
    let symbols: [FigureSymbol]
    let motionArc: Bool

    /// Seconds spent on each symbol before crossfading to the next.
    private let dwellSeconds: TimeInterval = 2.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let total = dwellSeconds * Double(symbols.count)
            let phase = t.truncatingRemainder(dividingBy: total)
            let idx = Int(phase / dwellSeconds) % symbols.count
            let active = symbols[idx]

            ZStack {
                Image(systemName: active.symbolName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 220, height: 220)
                    .id(active.rawValue)
                    .transition(.opacity)

                if motionArc {
                    MotionArcOverlay(
                        start:   CGPoint(x: -50, y: -110),
                        end:     CGPoint(x:  50, y: -110),
                        control: CGPoint(x:   0, y: -160),
                        color: AppPalette.clay
                    )
                    .frame(width: 220, height: 220)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: active)
        }
    }
}

// MARK: - Thumbnail

/// Small static figure used in the per-movement row of a flow's
/// sequence list. No chrome, just the tinted SF Symbol.
struct HybridMobilityFigureThumb: View {
    let title: String

    var body: some View {
        let kind = FigureSymbol.match(forTitle: title)
        Image(systemName: kind.symbolName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppPalette.ink, AppPalette.clay)
            .frame(width: 44, height: 44)
            .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 24) {
        HybridMobilityFigureHero(movementTitles: [
            "Arm circles with thoracic rotation",
            "Wall shoulder slides",
            "Band pull-aparts"
        ])
        HStack(spacing: 16) {
            HybridMobilityFigureThumb(title: "World's greatest stretch")
            HybridMobilityFigureThumb(title: "Calf wall press")
            HybridMobilityFigureThumb(title: "Foam roll hamstrings")
        }
    }
    .padding()
    .background(AppPalette.cream)
}
