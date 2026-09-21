import SwiftUI

/// Throwaway comparison view used to decide between the two
/// production-grade figure styles for v1.1.D mobility art:
///
///   • **Procedural** — what we have today: Canvas-based stick athlete
///     with tapered limbs, joints, face, motion arrows, etc.
///
///   • **SF Symbol hybrid** — Apple's anatomically-correct figure
///     symbols (figure.flexibility, figure.cooldown, figure.yoga …)
///     tinted with AppPalette + wrapped with our motion overlays
///     (breath strip, court backdrop, motion arc).
///
/// Both directions render the same conceptual move ("World's Greatest
/// Stretch" hero + the existing 6-pose strip) so the eyeball
/// comparison is fair. Not wired into production navigation.
struct FigureApproachComparison: View {
    @EnvironmentObject private var lang: LanguageManager

    /// Set to one of "1", "2", "3", "all" via UserDefaults
    /// `CourtIQ.figureCompareSection` to render only that approach
    /// when the view is hijacked for screenshots.
    private var sectionFilter: String {
        UserDefaults.standard.string(forKey: "CourtIQ.figureCompareSection") ?? "all"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if sectionFilter == "all" || sectionFilter == "1" { proceduralSection }
                if sectionFilter == "all" || sectionFilter == "2" { sfSymbolSection }
                if sectionFilter == "all" || sectionFilter == "3" { hybridSection }
                if sectionFilter == "all" { Divider().padding(.vertical, 4); tradeoffs }
            }
            .padding(22)
            .padding(.bottom, 60)
        }
        .background(AppPalette.cream)
        .navigationTitle("Figure direction")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Approach 1 — Procedural

    private var proceduralSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTag("1 — Procedural", subtitle: "Hand-drawn Canvas paths")

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                AthleteFigureCanvas(staticPose: .lungeTwist)
                    .frame(width: 240, height: 240)
            }
            .frame(height: 280)

            poseStrip { pose, _ in
                AthleteFigureCanvas(staticPose: pose)
                    .frame(width: 110, height: 110)
            }
        }
    }

    // MARK: - Approach 2 — SF Symbol pure

    private var sfSymbolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTag("2 — SF Symbol (pure)", subtitle: "Apple's figure.* library")

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                Image(systemName: "figure.flexibility")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppPalette.ink, AppPalette.clay)
                    .frame(width: 200, height: 200)
            }
            .frame(height: 280)

            poseStrip { _, kind in
                Image(systemName: kind.symbolName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppPalette.ink, AppPalette.clay)
                    .frame(width: 80, height: 80)
            }
        }
    }

    // MARK: - Approach 3 — SF Symbol + DropVolley overlays

    private var hybridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTag("3 — Hybrid (recommended)", subtitle: "SF Symbol base + our motion arc + breath strip + court")

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )

                CourtTopDown(surface: .clay, lineOpacity: 0.22)
                    .opacity(0.30)
                    .frame(width: 130, height: 200)
                    .offset(x: 95, y: 0)
                    .allowsHitTesting(false)

                ZStack {
                    Image(systemName: "figure.flexibility")
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppPalette.ink, AppPalette.clay)
                        .frame(width: 220, height: 220)
                        .symbolEffect(.pulse.byLayer, options: .repeating)

                    // Motion arc overlay above the figure.
                    MotionArcOverlay(
                        start: CGPoint(x: -50, y: -110),
                        end:   CGPoint(x:  50, y: -110),
                        control: CGPoint(x: 0, y: -160),
                        color: AppPalette.clay
                    )
                }
            }
            .frame(height: 300)

            HStack(spacing: 8) {
                BreathDot()
                Text("Hold 3 breaths each side · 2 rounds")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            poseStrip { _, kind in
                ZStack {
                    Image(systemName: kind.symbolName)
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppPalette.ink, AppPalette.clay)
                        .frame(width: 80, height: 80)
                }
            }
        }
    }

    // MARK: - Trade-offs commentary

    private var tradeoffs: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trade-offs")
                .font(.headline)

            tradeoffRow("Anatomy correctness",
                        procedural: "Stylized — accurate-ish",
                        symbol: "Apple-designed, anatomically correct")
            tradeoffRow("Visual quality",
                        procedural: "Hand-drawn feel, recognizable",
                        symbol: "Production polish, system-native")
            tradeoffRow("Bundle size",
                        procedural: "0 bytes (code)",
                        symbol: "0 bytes (system font)")
            tradeoffRow("Animation",
                        procedural: "Custom: pose interpolation + breath",
                        symbol: "Apple: .pulse / .bounce / .variableColor / .breathe")
            tradeoffRow("Maintenance",
                        procedural: "We own every pixel — every fix is our work",
                        symbol: "Apple updates symbols across iOS versions")
            tradeoffRow("Customization",
                        procedural: "Total — every detail tunable",
                        symbol: "Limited — palette + scale + effect")
            tradeoffRow("Coverage",
                        procedural: "13 hand-built poses",
                        symbol: "~50+ figure.* variants out of the box")
            tradeoffRow("App identity",
                        procedural: "Custom voice — \"this is ours\"",
                        symbol: "iOS-native — \"this is well made\"")
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tradeoffRow(_ label: String, procedural: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Procedural")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                    Text(procedural).font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SF Symbol")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppPalette.moss)
                    Text(symbol).font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func sectionTag(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
        }
    }

    /// Six-pose strip showing the same set of mobility moves across
    /// approaches. The closure renders one card with the figure of the
    /// caller's choice.
    private func poseStrip<Card: View>(
        @ViewBuilder card: @escaping (AthletePose, FigureSymbolKind) -> Card
    ) -> some View {
        let entries: [(String, AthletePose, FigureSymbolKind)] = [
            ("Hamstring", .forwardFold, .yoga),
            ("Hip opener", .lungeTwist, .flexibility),
            ("Calf wall",  .calfWall,   .cooldown),
            ("T-spine",    .tSpineWindmill, .strengthFunctional),
            ("90/90 hip",  .nineNinety, .pilates),
            ("Standing",   .standing,   .stand)
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppPalette.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppPalette.sand, lineWidth: 1)
                                )
                            card(e.1, e.2)
                        }
                        .frame(width: 130, height: 130)
                        Text(e.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                    }
                }
            }
        }
    }
}

// NOTE: not compiled into the app — a throwaway comparison kept for
// reference. MotionArcOverlay and FigureSymbolKind moved to
// MotionArcOverlay.swift. Add this file to CourtIQ's Sources to run it.

#Preview {
    NavigationStack {
        FigureApproachComparison()
            .environmentObject(LanguageManager.shared)
    }
}
