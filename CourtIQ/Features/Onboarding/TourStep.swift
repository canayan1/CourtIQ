import SwiftUI

/// Onboarding step 5 — a 4-page, horizontally-swipeable guided tour of the
/// app's core surfaces (Quiz, Training, Mobility, Profile). Designed to
/// orient new users on "what's here, where do I find it" before they hit
/// the paywall preview and account screens.
///
/// Each page is text-light + visual-heavy and reuses existing tennis design
/// motifs from `TennisVisuals.swift`. A top-right "Skip" lets impatient
/// users bypass to the paywall step at any time.
struct TourStep: View {
    let dotIndex: Int
    let onBack: () -> Void
    let onNext: () -> Void

    @EnvironmentObject private var lang: LanguageManager
    @State private var page = 0

    // 7 pages: Drill (the new daily ritual) → Pro Shot of the Day → Three
    // Rings → Match Journal → Training programs → Mobility → Avatar &
    // unlocks. Order is chosen so users see the most active features
    // first (Drill, Pro Shot) before the heavier reference tools.
    private let pageCount = 7

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                tourPageDrill.tag(0)
                tourPageProShot.tag(1)
                tourPageRings.tag(2)
                tourPageMatches.tag(3)
                tourPageTraining.tag(4)
                tourPageMobility.tag(5)
                tourPageAvatar.tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            pageIndicator
            bottomCTA
        }
        .background(AppPalette.cream)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(AppPalette.inkSoft.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                }
            }
            .buttonStyle(.plain)

            OnboardingDots(current: dotIndex)

            Spacer()

            Button(lang.t("onb.tour.skip"), action: onNext)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 10)
    }

    // MARK: - Pages

    private var tourPageDrill: some View {
        TourPage(
            visual: AnyView(drillVisual),
            title: lang.t("onb.tour.drill.title"),
            bodyText: lang.t("onb.tour.drill.body")
        )
    }

    private var tourPageProShot: some View {
        TourPage(
            visual: AnyView(proShotVisual),
            title: lang.t("onb.tour.proshot.title"),
            bodyText: lang.t("onb.tour.proshot.body")
        )
    }

    private var tourPageRings: some View {
        TourPage(
            visual: AnyView(ringsVisual),
            title: lang.t("onb.tour.rings.title"),
            bodyText: lang.t("onb.tour.rings.body")
        )
    }

    private var tourPageMatches: some View {
        TourPage(
            visual: AnyView(matchesVisual),
            title: lang.t("onb.tour.matches.title"),
            bodyText: lang.t("onb.tour.matches.body")
        )
    }

    private var tourPageTraining: some View {
        TourPage(
            visual: AnyView(trainingVisual),
            title: lang.t("onb.tour.training.title"),
            bodyText: lang.t("onb.tour.training.body")
        )
    }

    private var tourPageMobility: some View {
        TourPage(
            visual: AnyView(mobilityVisual),
            title: lang.t("onb.tour.mobility.title"),
            bodyText: lang.t("onb.tour.mobility.body")
        )
    }

    private var tourPageAvatar: some View {
        TourPage(
            visual: AnyView(avatarVisual),
            title: lang.t("onb.tour.avatar.title"),
            bodyText: lang.t("onb.tour.avatar.body")
        )
    }

    // MARK: - New visuals (drill / pro shot / rings / matches / avatar)

    /// Drill: top-down court with tap dot + YOU marker. Court + decorations
    /// live inside a fixed 220x240 ZStack so offsets stay bounded.
    private var drillVisual: some View {
        ZStack {
            CourtTopDown(surface: .clay, lineOpacity: 0.95)
                .frame(width: 110, height: 238)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Suggested tap dot — green = good choice
            Circle()
                .fill(AppPalette.moss)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .offset(x: 24, y: -70)

            // YOU marker
            courtMarker(label: "YOU", fill: AppPalette.clay)
                .offset(x: 0, y: 95)
        }
        .frame(width: 220, height: 240)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Pro Shot: court + dashed pattern + trophy badge. Wrapped in a
    /// 260x240 fixed ZStack so the trophy badge offset stays bounded
    /// inside the parent's clip rather than bleeding into the title.
    private var proShotVisual: some View {
        ZStack {
            CourtTopDown(surface: .grass, lineOpacity: 0.95)
                .frame(width: 110, height: 238)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: 55, y: 220))
                        p.addQuadCurve(to: CGPoint(x: 92, y: 35),
                                       control: CGPoint(x: 100, y: 110))
                    }
                    .stroke(Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [3, 7]))
                )

            // Trophy at top-right of bounded region (no longer overflowing).
            ZStack {
                Circle()
                    .fill(AppPalette.gold.opacity(0.18))
                    .frame(width: 60, height: 60)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppPalette.gold)
            }
            .offset(x: 80, y: -85)
        }
        .frame(width: 260, height: 240)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Three Rings: large concentric activity ring preview.
    private var ringsVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .frame(height: 240)

            ActivityRingsView(
                quizProgress: 1.0,
                matchProgress: 1.0,
                mobilityProgress: 0.7,
                size: 168
            )
        }
        .padding(.horizontal, 28)
    }

    /// Matches: list-style preview with a few rows.
    private var matchesVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .frame(height: 240)

            VStack(spacing: 10) {
                matchRow(date: "Mon", opp: "Mehmet", result: "W", color: AppPalette.moss)
                matchRow(date: "Wed", opp: "Aylin",  result: "L", color: AppPalette.alert)
                matchRow(date: "Sat", opp: "Burak",  result: "W", color: AppPalette.moss)
            }
            .padding(.horizontal, 26)
        }
        .padding(.horizontal, 28)
    }

    private func matchRow(date: String, opp: String, result: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(date)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.inkSoft)
                .frame(width: 36, alignment: .leading)
            Text(opp)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            Spacer()
            Text(result)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(color))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Avatar: procedural tennis avatar preview with court background.
    private var avatarVisual: some View {
        let demoConfig = AvatarConfig(
            outfitID: AvatarOutfit.sunsetOrange.rawValue,
            racketID: AvatarRacket.neonYellow.rawValue,
            courtSurfaceID: AvatarCourtBg.clayCourt.rawValue,
            accentID: AvatarAccent.headband.rawValue,
            stanceID: AvatarStance.proPose.rawValue
        )
        return ZStack {
            TennisAvatarView(config: demoConfig, size: 220)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Visuals (reuse TennisVisuals primitives)

    /// Quiz: top-down clay court with YOU and OP markers.
    private var quizVisual: some View {
        ZStack {
            CourtTopDown(surface: .clay, lineOpacity: 0.95)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            // YOU marker, near baseline
            courtMarker(label: "YOU", fill: AppPalette.clay)
                .offset(x: 0, y: 100)

            // OP marker, far court
            courtMarker(label: "OP", fill: AppPalette.ink.opacity(0.85))
                .offset(x: 24, y: -90)
        }
        .padding(.horizontal, 28)
    }

    /// Training: diagonal racket + 8-week strip.
    private var trainingVisual: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppPalette.trainingGradient)
                .frame(height: 240)

            TennisRacket(color: .white.opacity(0.22), accent: .white.opacity(0.4), angle: -22)
                .frame(width: 130, height: 182)
                .offset(x: 24, y: 10)

            VStack(alignment: .leading, spacing: 14) {
                Text("TRAINING")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                Text("8 WEEKS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(i < 3 ? 0.85 : 0.28))
                            .frame(height: 6)
                    }
                }
                .frame(maxWidth: 160)
            }
            .padding(24)
        }
        .padding(.horizontal, 28)
    }

    /// Mobility: grass court perspective with figure motif.
    private var mobilityVisual: some View {
        ZStack {
            CourtPerspective(surface: .grass)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            TrajectoryArc(color: .white.opacity(0.6), dashed: true, lineWidth: 2)
                .frame(height: 240)
                .padding(.horizontal, 50)
                .allowsHitTesting(false)

            TennisGlyph(kind: .mobility, color: .white.opacity(0.9), size: 76)
                .offset(y: 10)
        }
        .padding(.horizontal, 28)
    }

    /// Profile: StreakRing centered on a parchment card.
    private var profileVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .frame(height: 240)

            CourtLinesBg(color: AppPalette.clay.opacity(0.08))
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.horizontal, 28)
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppPalette.ink)
                        .frame(width: 140, height: 140)
                    StreakRing(value: 12, maxValue: 30, color: AppPalette.clay)
                        .frame(width: 120, height: 120)
                }

                Text("IQ 1,420")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(AppPalette.ink)
            }
        }
        .padding(.horizontal, 28)
    }

    private func courtMarker(label: String, fill: Color) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Page indicator + bottom CTA

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { idx in
                Capsule()
                    .fill(idx == page ? AppPalette.clay : AppPalette.sand)
                    .frame(width: idx == page ? 22 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var bottomCTA: some View {
        VStack(spacing: 0) {
            if page == pageCount - 1 {
                Button(action: onNext) {
                    Text(lang.t("onb.cta.continue"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppPalette.clay)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
                .transition(.opacity)
            } else {
                Text(lang.t("onb.tour.swipe_hint"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.bottom, 50)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
    }
}

// MARK: - Reusable per-page layout

private struct TourPage: View {
    let visual: AnyView
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer().frame(height: 8)

            // Hard-bound the visual frame so any .offset() decorations
            // inside individual visuals can't bleed into the title block
            // below. Without this clip the Pro Shot trophy badge (offset
            // x:90, y:-90) was overlapping the title text on page 2.
            visual
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }
}
