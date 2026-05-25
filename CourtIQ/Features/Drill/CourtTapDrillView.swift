import SwiftUI

/// The Daily Court Tap Game.
///
/// Five micro-scenarios in sequence. Each: court diagram + dashed
/// incoming-ball trajectory + scenario chip. User taps the court where
/// they'd hit the next shot. System scores the tap (green / yellow /
/// red), animates a reveal showing the ideal zone + rationale, advances.
///
/// Design intent: 0 UI text outside the rationale reveal. Pure visual
/// interaction. Average commitment: 30-60 seconds.
struct CourtTapDrillView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager

    @State private var drills: [CourtTapDrill] = []
    @State private var currentIndex: Int = 0
    @State private var taps: [DrillTap] = []
    @State private var revealedTap: CGPoint? = nil
    @State private var revealedZone: DrillZone? = nil
    @State private var sessionFinished = false
    @State private var showResult = false
    /// One-time onboarding sheet so first-time users understand the
    /// "tap where you'd hit" interaction before the court appears.
    /// Persisted in UserDefaults — shown only on the very first session
    /// the user ever starts.
    @AppStorage("CourtIQ.Drill.introSeen.v1") private var introSeen: Bool = false
    @State private var showIntro: Bool = false

    private var currentDrill: CourtTapDrill? {
        drills.indices.contains(currentIndex) ? drills[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            topProgress
            if let drill = currentDrill {
                playArea(for: drill)
            } else {
                Color.clear
            }
        }
        .background(AppPalette.cream)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                }
            }
        }
        .onAppear(perform: setupSession)
        .fullScreenCover(isPresented: $showResult, onDismiss: { dismiss() }) {
            if let session = drillManager.todaysSession {
                DrillResultView(session: session, drills: drills)
                    .environmentObject(lang)
                    .environmentObject(drillManager)
            }
        }
        .sheet(isPresented: $showIntro) {
            DrillIntroSheet {
                introSeen = true
                showIntro = false
            }
            .environmentObject(lang)
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Top progress (5 dots)

    private var topProgress: some View {
        HStack(spacing: 8) {
            ForEach(0..<drills.count, id: \.self) { idx in
                let isCurrent = idx == currentIndex
                let zoneForTap = taps.indices.contains(idx) ? taps[idx].zone : nil
                Capsule()
                    .fill(dotColor(zone: zoneForTap, isCurrent: isCurrent))
                    .frame(width: isCurrent ? 28 : 16, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    .animation(.easeInOut(duration: 0.2), value: zoneForTap)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func dotColor(zone: DrillZone?, isCurrent: Bool) -> Color {
        if let zone {
            switch zone {
            case .green:  return AppPalette.moss
            case .yellow: return AppPalette.gold
            case .red:    return AppPalette.alert
            }
        }
        return isCurrent ? AppPalette.clay : AppPalette.sand
    }

    // MARK: - Play area

    private func playArea(for drill: CourtTapDrill) -> some View {
        VStack(spacing: 24) {
            // Court with optional reveal overlay
            GeometryReader { geo in
                let layout = courtLayout(in: geo.size)
                ZStack(alignment: .topLeading) {
                    AppPalette.parchment

                    // Court image — anchored at layout.courtOrigin
                    courtIllustration(drill: drill, layout: layout)
                        .position(
                            x: layout.courtOrigin.x + layout.courtSize.width / 2,
                            y: layout.courtOrigin.y + layout.courtSize.height / 2
                        )

                    // Score chip (top-left of region, parchment margin)
                    if let chip = drill.scoreChip, !chip.isEmpty {
                        Text(chip)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppPalette.ink.opacity(0.85)))
                            .padding(.leading, 16)
                            .padding(.top, 16)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location, layout: layout, drill: drill)
                }
            }
            .frame(height: 360)

            // Either the pre-tap prompt OR the post-tap rationale —
            // never both at the same time. The pre-tap prompt is a
            // gentle one-liner so first-time users always know they
            // need to tap the court; it doesn't crowd the experience.
            if revealedZone != nil {
                rationaleCard(for: drill)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.horizontal, 22)
            } else {
                preTapPrompt
                    .padding(.horizontal, 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    /// Quiet bottom-of-screen prompt shown until the user taps. Mirrors
    /// the rationale card's chrome so the post-tap reveal feels like a
    /// natural state transition, not a screen change.
    private var preTapPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
            Text(lang.t("drill.pretap_prompt"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            Spacer()
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.clay.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Court illustration

    /// Layout helper so tap coordinates and reveal overlay both share
    /// the same coordinate system.
    private struct CourtLayout {
        let courtOrigin: CGPoint   // top-left of court rect in region space
        let courtSize: CGSize      // 120 × 260 box

        /// Convert a tap in region coordinates to normalized court coords.
        /// Returns nil if the tap fell outside the court rect.
        func normalize(_ p: CGPoint) -> CGPoint? {
            let local = CGPoint(x: p.x - courtOrigin.x, y: p.y - courtOrigin.y)
            guard local.x >= 0, local.x <= courtSize.width,
                  local.y >= 0, local.y <= courtSize.height
            else { return nil }
            return CGPoint(x: local.x / courtSize.width, y: local.y / courtSize.height)
        }
    }

    private func courtLayout(in regionSize: CGSize) -> CourtLayout {
        let width: CGFloat = 140
        let height: CGFloat = 300
        let x = (regionSize.width - width) / 2
        let y = (regionSize.height - height) / 2
        return CourtLayout(
            courtOrigin: CGPoint(x: x, y: y),
            courtSize: CGSize(width: width, height: height)
        )
    }

    private func courtIllustration(drill: CourtTapDrill, layout: CourtLayout) -> some View {
        ZStack(alignment: .topLeading) {
            CourtTopDown(surface: surfaceFor(drill: drill), lineOpacity: 0.95)
                .frame(width: layout.courtSize.width, height: layout.courtSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(surfaceFor(drill: drill).line.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: AppPalette.ink.opacity(0.18), radius: 14, x: 0, y: 6)

            ZStack {
                // Dashed incoming-ball trajectory
                if let ox = drill.ballOriginX, let oy = drill.ballOriginY,
                   let tx = drill.ballTargetX, let ty = drill.ballTargetY {
                    let w = layout.courtSize.width
                    let h = layout.courtSize.height
                    Path { p in
                        p.move(to: CGPoint(x: ox * w, y: oy * h))
                        p.addQuadCurve(
                            to: CGPoint(x: tx * w, y: ty * h),
                            control: CGPoint(x: ((ox + tx) / 2) * w,
                                             y: (min(oy, ty) - 0.20) * h)
                        )
                    }
                    .stroke(Color.white.opacity(0.88),
                            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [3, 7]))
                }

                // Opponent + YOU markers
                if let ox = drill.opponentX, let oy = drill.opponentY {
                    courtMarker(label: "OP", fill: AppPalette.ink.opacity(0.88))
                        .position(x: ox * layout.courtSize.width, y: oy * layout.courtSize.height)
                }
                courtMarker(label: "YOU", fill: AppPalette.clay)
                    .position(x: drill.youX * layout.courtSize.width,
                              y: drill.youY * layout.courtSize.height)

                // Reveal overlay — green zone outline + tap dot
                if revealedZone != nil {
                    revealOverlay(drill: drill, layout: layout)
                }
            }
            .frame(width: layout.courtSize.width, height: layout.courtSize.height)
        }
    }

    private func revealOverlay(drill: CourtTapDrill, layout: CourtLayout) -> some View {
        ZStack {
            // Green zone outline + light fill
            Path { p in
                guard let first = drill.greenPolygon.first else { return }
                p.move(to: CGPoint(x: first.x * layout.courtSize.width,
                                   y: first.y * layout.courtSize.height))
                for pt in drill.greenPolygon.dropFirst() {
                    p.addLine(to: CGPoint(x: pt.x * layout.courtSize.width,
                                          y: pt.y * layout.courtSize.height))
                }
                p.closeSubpath()
            }
            .fill(AppPalette.moss.opacity(0.30))
            .overlay(
                Path { p in
                    guard let first = drill.greenPolygon.first else { return }
                    p.move(to: CGPoint(x: first.x * layout.courtSize.width,
                                       y: first.y * layout.courtSize.height))
                    for pt in drill.greenPolygon.dropFirst() {
                        p.addLine(to: CGPoint(x: pt.x * layout.courtSize.width,
                                              y: pt.y * layout.courtSize.height))
                    }
                    p.closeSubpath()
                }
                .stroke(AppPalette.moss, lineWidth: 1.5)
            )

            // Tap dot
            if let tap = revealedTap, let zone = revealedZone {
                Circle()
                    .fill(zoneColor(zone))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .position(x: tap.x * layout.courtSize.width,
                              y: tap.y * layout.courtSize.height)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func courtMarker(label: String, fill: Color) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1.6))
                .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 2)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white)
        }
    }

    private func zoneColor(_ zone: DrillZone) -> Color {
        switch zone {
        case .green:  return AppPalette.moss
        case .yellow: return AppPalette.gold
        case .red:    return AppPalette.alert
        }
    }

    // MARK: - Rationale card

    private func rationaleCard(for drill: CourtTapDrill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let zone = revealedZone {
                    ZStack {
                        Circle()
                            .fill(zoneColor(zone).opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: zone == .green ? "checkmark"
                              : zone == .yellow ? "minus" : "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(zoneColor(zone))
                    }
                }
                Text(drill.localizedTitle(for: lang.language))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
            }

            Text(drill.localizedRationale(for: lang.language))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                advance()
            } label: {
                Text(currentIndex == drills.count - 1
                     ? lang.t("drill.see_result")
                     : lang.t("drill.next"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Logic

    private func setupSession() {
        guard drills.isEmpty else { return }
        drills = drillManager.todaysDrills()
        currentIndex = 0
        taps = []
        revealedTap = nil
        revealedZone = nil
        if !introSeen {
            // Slight delay so the sheet animates over the populated
            // court rather than over a blank screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showIntro = true
            }
        }
    }

    private func handleTap(at point: CGPoint, layout: CourtLayout, drill: CourtTapDrill) {
        guard revealedZone == nil else { return }
        guard let normalized = layout.normalize(point) else { return }

        let zone = CourtTapDrillManager.evaluate(tap: normalized, on: drill)
        withAnimation(.easeOut(duration: 0.28)) {
            revealedTap = normalized
            revealedZone = zone
        }

        // Haptic per zone
        switch zone {
        case .green:  Haptics.success()
        case .yellow: Haptics.warning()
        case .red:    Haptics.error()
        }

        let tap = DrillTap(drillID: drill.id, tapX: normalized.x, tapY: normalized.y, zone: zone)
        taps.append(tap)
    }

    private func advance() {
        if currentIndex < drills.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex += 1
                revealedTap = nil
                revealedZone = nil
            }
        } else {
            drillManager.recordSession(taps: taps)
            sessionFinished = true
            Haptics.celebrate()
            showResult = true
        }
    }

    private func surfaceFor(drill: CourtTapDrill) -> AppPalette.CourtSurface {
        switch drill.surface {
        case "grass": return .grass
        case "hard":  return .hard
        case "night": return .night
        case "cream": return .cream
        default:      return .clay
        }
    }
}

// MARK: - Intro sheet

/// One-time onboarding for the Daily Court Drill. The "0 UI text"
/// design rule meant first-time users opened the drill and were
/// confronted with a court and markers with no explanation. This
/// sheet appears once, primes the user on the three on-court
/// symbols (clay = YOU, ink = OPPONENT, dashed line = incoming ball),
/// states the goal in one sentence, and gets out of the way.
struct DrillIntroSheet: View {
    @EnvironmentObject private var lang: LanguageManager
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppPalette.clay.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.clay)
            }
            .padding(.top, 12)

            VStack(spacing: 6) {
                Text(lang.t("drill.intro_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.ink)
                Text(lang.t("drill.intro_subtitle"))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)

            VStack(spacing: 12) {
                legendRow(symbol: "circle.fill", tint: AppPalette.clay,
                          text: lang.t("drill.intro_legend_you"))
                legendRow(symbol: "circle.fill", tint: AppPalette.ink,
                          text: lang.t("drill.intro_legend_op"))
                legendRow(symbol: "arrow.up.right",
                          tint: AppPalette.inkSoft,
                          text: lang.t("drill.intro_legend_ball"),
                          dashed: true)
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Text(lang.t("drill.intro_cta"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
        }
        .background(AppPalette.cream)
    }

    private func legendRow(symbol: String, tint: Color, text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                if dashed {
                    // Approximate the on-court dashed trajectory marker.
                    Path { p in
                        p.move(to: CGPoint(x: 8, y: 28))
                        p.addLine(to: CGPoint(x: 28, y: 8))
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                    .frame(width: 36, height: 36)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(tint))
                }
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
