import SwiftUI

/// Parameters for one wall session — built from a `WallDrill` or the free-rally
/// entry. Identifiable so the hub can drive a `fullScreenCover(item:)`.
struct WallSessionConfig: Identifiable {
    let id = UUID()
    let title: String
    let instruction: String?
    let target: WallTarget
    let tempoBPM: Int
    let focus: WallFocus
    let isFreeRally: Bool
    let drillID: String?
}

// MARK: - Hub

/// The Wall section landing: a short "why", the free-rally ("Wall Tennis")
/// entry, and the drill library. Each row opens a paced session.
struct WallHubView: View {
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var wallProgress = WallProgressManager.shared
    @State private var active: WallSessionConfig?
    @State private var showRallyCam = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                freeRallyCard
                rallyCamCard
                Text(lang.t("wall.drills_header"))
                    .font(.caption.weight(.heavy)).tracking(0.6).textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.top, 6)
                ForEach(Array(WallDrill.all.enumerated()), id: \.element.id) { idx, drill in
                    drillCard(level: idx + 1, drill: drill,
                              unlocked: idx == 0 || wallProgress.isCleared(WallDrill.all[idx - 1].id))
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("wall.title"))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $active) { cfg in
            WallSessionView(config: cfg).environmentObject(lang)
        }
        .fullScreenCover(isPresented: $showRallyCam) {
            WallRallyCamView().environmentObject(lang)
        }
    }

    /// Experimental: the on-device camera that counts consecutive ball-in-square
    /// hits (Vision trajectory detection). Device-only; beta-badged.
    private var rallyCamCard: some View {
        Button {
            Haptics.tap()
            showRallyCam = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.ink).frame(width: 52, height: 52)
                    Image(systemName: "camera.viewfinder")
                        .appFont(24, weight: .bold, design: .default)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(lang.t("rallycam.title"))
                            .appFont(17, weight: .heavy).foregroundStyle(AppPalette.ink)
                        Text(lang.t("common.beta"))
                            .appFont(9, weight: .heavy).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(AppPalette.gold))
                    }
                    Text(lang.t("rallycam.sub"))
                        .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.inkSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.ink.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("wall.eyebrow"))
            Text(lang.t("wall.headline"))
                .appFont(24, weight: .heavy)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lang.t("wall.subhead"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var freeRallyCard: some View {
        Button {
            Haptics.tap()
            active = WallSessionConfig(
                title: lang.t("wall.free_title"),
                instruction: lang.t("wall.free_instruction"),
                target: .duration(seconds: 0),   // open — user finishes manually
                tempoBPM: 50, focus: .consistency, isFreeRally: true, drillID: nil
            )
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.clay).frame(width: 52, height: 52)
                    Image(systemName: "figure.tennis")
                        .appFont(24, weight: .bold, design: .default)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.t("wall.free_title"))
                        .appFont(17, weight: .heavy).foregroundStyle(AppPalette.ink)
                    Text(lang.t("wall.free_sub"))
                        .font(.footnote).foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.inkSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.clay.opacity(0.30), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    /// A LEVEL in the ladder → opens the detail (free animated demo + the
    /// premium Rally Cam). No metronome.
    private func drillCard(level: Int, drill: WallDrill, unlocked: Bool) -> some View {
        NavigationLink {
            WallLevelDetailView(level: level, drill: drill)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(WallStyle.tint(drill.focus).opacity(0.16))
                        .frame(width: 44, height: 44)
                    Text("\(level)")
                        .appFont(18, weight: .heavy)
                        .foregroundStyle(WallStyle.tint(drill.focus))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(drill.localizedTitle(for: lang.language))
                            .appFont(16, weight: .bold).foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if drill.isTennisIQ {
                            Text("IQ").appFont(9, weight: .heavy).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(AppPalette.clay))
                        }
                    }
                    HStack(spacing: 8) {
                        Text(drill.focus.label(for: lang.language))
                            .font(.caption.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                        if wallProgress.personalBest(drillID: drill.id) > 0 {
                            Text("·").foregroundStyle(AppPalette.inkSoft.opacity(0.5))
                            Label("\(wallProgress.personalBest(drillID: drill.id))", systemImage: "trophy.fill")
                                .font(.caption2.weight(.bold)).foregroundStyle(AppPalette.gold)
                        }
                        Spacer(minLength: 0)
                        WallStyle.difficultyDots(drill.difficulty)
                    }
                }
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(AppPalette.inkSoft.opacity(0.6))
                } else if wallProgress.isCleared(drill.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(AppPalette.moss)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold)).foregroundStyle(AppPalette.inkSoft.opacity(0.6))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.55)
    }
}

// MARK: - Session (paced metronome + auto counter)

/// A hands-free paced session: the ring pulses and a real racket "pock" fires
/// at the tempo, so the player hits IN TIME with the beat instead of tapping
/// the phone each shot. Beats auto-count toward the target (reps → count up;
/// duration → count down; free rally → open). Tempo is adjustable mid-session.
struct WallSessionView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let config: WallSessionConfig

    @State private var running = false
    @State private var beat = 0
    @State private var elapsed = 0
    @State private var bpm: Int
    @State private var scale: CGFloat = 1.0
    @State private var finished = false
    @State private var beatTimer: Timer?
    @State private var secTimer: Timer?

    init(config: WallSessionConfig) {
        self.config = config
        _bpm = State(initialValue: config.tempoBPM)
    }

    private var targetReps: Int? { if case .reps(let r) = config.target { return r }; return nil }
    private var targetSecs: Int? { if case .duration(let s) = config.target, s > 0 { return s }; return nil }
    private var tint: Color { WallStyle.tint(config.focus) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                Spacer(minLength: 0)
                ring
                Spacer(minLength: 0)
                if finished { finishCard } else { liveControls }
            }
            .padding(24)
        }
        .onDisappear { stopTimers() }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { stopTimers(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                        .padding(6).contentShape(Rectangle())
                }
                .accessibilityLabel(lang.t("common.close"))
                Spacer()
                Label(config.focus.label(for: lang.language), systemImage: config.focus.iconName)
                    .font(.caption.weight(.heavy)).textCase(.uppercase).tracking(0.5)
                    .foregroundStyle(tint)
            }
            Text(config.title)
                .appFont(22, weight: .heavy).foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let instruction = config.instruction {
                Text(instruction)
                    .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Ring (tap = start / pause)

    private var ring: some View {
        Button {
            running ? pause() : start()
        } label: {
            ZStack {
                Circle().fill(tint.opacity(0.10)).frame(width: 250, height: 250)
                Circle().stroke(tint.opacity(0.25), lineWidth: 2).frame(width: 250, height: 250)
                if let p = progress {
                    Circle().trim(from: 0, to: p)
                        .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 250, height: 250)
                        .animation(.easeInOut(duration: 0.25), value: p)
                }
                Circle().fill(tint.opacity(0.14)).frame(width: 150, height: 150).scaleEffect(scale)
                VStack(spacing: 2) {
                    Text(primaryText).appFont(46, weight: .heavy).foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                    Text(secondaryText).font(.caption.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                    if !running && !finished {
                        Label(beat == 0 ? lang.t("wall.start") : lang.t("wall.resume"), systemImage: "play.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(tint).padding(.top, 4)
                    } else if running {
                        Image(systemName: "pause.fill").font(.caption).foregroundStyle(AppPalette.inkSoft).padding(.top, 4)
                    }
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(finished)
    }

    private var progress: CGFloat? {
        if let tr = targetReps, tr > 0 { return min(1, CGFloat(beat) / CGFloat(tr)) }
        if let ts = targetSecs, ts > 0 { return min(1, CGFloat(elapsed) / CGFloat(ts)) }
        return nil   // free rally — no ring progress
    }

    private var primaryText: String {
        if let ts = targetSecs { return WallStyle.clock(max(0, ts - elapsed)) }
        return "\(beat)"          // reps target + free rally show the hit count
    }

    private var secondaryText: String {
        if targetSecs != nil { return lang.t("wall.remaining") }
        if let tr = targetReps { return "/ \(tr) \(lang.t("wall.hits"))" }
        return "\(lang.t("wall.hits")) · \(WallStyle.clock(elapsed))"   // free rally
    }

    // MARK: Live controls

    private var liveControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                tempoButton(system: "minus") { adjustTempo(-2) }
                VStack(spacing: 0) {
                    Text("\(bpm)").appFont(22, weight: .heavy).foregroundStyle(AppPalette.ink).monospacedDigit()
                    Text(lang.t("wall.bpm")).font(.caption2.weight(.bold)).foregroundStyle(AppPalette.inkSoft).tracking(0.5)
                }
                .frame(minWidth: 66)
                tempoButton(system: "plus") { adjustTempo(2) }
            }

            Button { finish() } label: {
                Text(lang.t("wall.finish"))
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.bordered).tint(AppPalette.inkSoft)
        }
    }

    private func tempoButton(system: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: system)
                .appFont(16, weight: .bold, design: .default).foregroundStyle(tint)
                .frame(width: 44, height: 44).background(Circle().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Finish

    private var finishCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").appFont(48, design: .default).foregroundStyle(AppPalette.moss)
            Text(lang.t("wall.complete_title")).appFont(20, weight: .heavy).foregroundStyle(AppPalette.ink)
            Text(String(format: lang.t("wall.complete_sub"), beat, WallStyle.clock(elapsed)))
                .font(.subheadline).foregroundStyle(AppPalette.inkSoft).multilineTextAlignment(.center)
            Button { stopTimers(); dismiss() } label: {
                Text(lang.t("wall.done")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(AppPalette.clay)
        }
    }

    // MARK: Engine

    private func start() {
        guard !running else { return }
        running = true
        AudioManager.shared.play(.sweetSpot)
        scheduleBeat()
        secTimer?.invalidate()
        secTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard running else { return }
            elapsed += 1
            if let ts = targetSecs, elapsed >= ts { finish() }
        }
    }

    private func pause() {
        running = false
        stopTimers()
    }

    private func scheduleBeat() {
        beatTimer?.invalidate()
        let interval = 60.0 / Double(max(30, bpm))
        beatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard running else { return }
            onBeat()
        }
    }

    private func onBeat() {
        beat += 1
        AudioManager.shared.play(.ballHit)
        Haptics.tap()
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.10)) { scale = 1.16 }
            withAnimation(.easeIn(duration: 0.14).delay(0.10)) { scale = 1.0 }
        }
        if let tr = targetReps, beat >= tr { finish() }
    }

    private func adjustTempo(_ delta: Int) {
        bpm = min(140, max(30, bpm + delta))
        if running { scheduleBeat() }
    }

    private func finish() {
        running = false
        stopTimers()
        withAnimation(.easeOut(duration: 0.25)) { finished = true }
        Haptics.celebrate()
        AudioManager.shared.play(.correct)
        AppAnalytics.shared.log(AnalyticsEvent.wallSessionCompleted, [
            "title": config.title, "hits": beat, "seconds": elapsed,
            "free_rally": config.isFreeRally
        ])
        WallProgressManager.shared.record(
            drillID: config.drillID, title: config.title,
            hits: beat, seconds: elapsed, isFreeRally: config.isFreeRally
        )
    }

    private func stopTimers() {
        beatTimer?.invalidate(); beatTimer = nil
        secTimer?.invalidate(); secTimer = nil
    }
}

// MARK: - Shared style helpers

@MainActor
enum WallStyle {
    static func tint(_ focus: WallFocus) -> Color {
        switch focus {
        case .consistency: return AppPalette.moss
        case .technique:   return AppPalette.clay
        case .volley:      return AppPalette.gold
        case .movement:    return AppPalette.moss
        case .iq:          return AppPalette.clay
        }
    }

    static func targetText(_ target: WallTarget, lang: LanguageManager) -> String {
        switch target {
        case .reps(let r):            return "\(r) \(lang.t("wall.hits"))"
        case .duration(let s):        return clock(s)
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func difficultyDots(_ level: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= level ? AppPalette.clay : AppPalette.sand)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

// MARK: - Level detail (free animated demo + premium Rally Cam)

/// One wall LEVEL: shows what the drill is + a free animated "how to" demo, and
/// offers the premium **Rally Cam** (the on-device vision scorer) — gated behind
/// the paywall for free accounts. Replaces the old metronome session.
struct WallLevelDetailView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var wallProgress = WallProgressManager.shared

    let level: Int
    let drill: WallDrill

    @State private var showRallyCam = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                WallDemoAnimation(focus: drill.focus)
                goalCard
                rallyCamButton
                clearSection
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(String(format: lang.t("wall.level_n"), level))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showRallyCam) {
            WallRallyCamView().environmentObject(lang)
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "WallRallyCam")
                    .environmentObject(session).environmentObject(lang)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(drill.focus.label(for: lang.language), systemImage: drill.focus.iconName)
                    .font(.caption.weight(.heavy)).textCase(.uppercase).tracking(0.5)
                    .foregroundStyle(WallStyle.tint(drill.focus))
                if drill.isTennisIQ {
                    Text("IQ").appFont(9, weight: .heavy).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(AppPalette.clay))
                }
                Spacer()
                if wallProgress.personalBest(drillID: drill.id) > 0 {
                    Label("\(wallProgress.personalBest(drillID: drill.id))", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(AppPalette.gold)
                }
            }
            Text(drill.localizedTitle(for: lang.language))
                .appFont(26, weight: .heavy).foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("wall.how_to"))
                .font(.caption.weight(.heavy)).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)
            Text(drill.localizedInstruction(for: lang.language))
                .font(.subheadline).foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var rallyCamButton: some View {
        Button {
            Haptics.tap()
            if session.isPremiumUnlocked { showRallyCam = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder").appFont(20, weight: .bold, design: .default)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(lang.t("rallycam.title")).font(.headline)
                        if !session.isPremiumUnlocked {
                            Image(systemName: "crown.fill").font(.caption).foregroundStyle(AppPalette.gold)
                        }
                    }
                    Text(lang.t("wall.rallycam_cta")).font(.caption).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.clay)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Clears the level (unlocks the next). Free accounts self-attest after the
    /// demo; premium earns it via a Rally Cam run. Once cleared, shows a seal.
    @ViewBuilder
    private var clearSection: some View {
        if wallProgress.isCleared(drill.id) {
            Label(lang.t("wall.level_cleared"), systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.moss)
                .frame(maxWidth: .infinity).padding(.top, 4)
        } else {
            Button {
                Haptics.success()
                wallProgress.markCleared(drill.id)
            } label: {
                Text(lang.t("wall.mark_done")).font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.bordered).tint(AppPalette.moss)
        }
    }
}

/// A tiny looping side-view demo — player on the left, wall + dashed target on
/// the right, a ball shuttling to the wall and back — so FREE accounts see how
/// the drill is done without the camera. (Per-drill choreography can come later;
/// this is the shared v1.) Honors Reduce Motion.
struct WallDemoAnimation: View {
    let focus: WallFocus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var atWall = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let leftX = w * 0.14, rightX = w * 0.78
            let baseY = h * 0.62
            ZStack {
                Rectangle().fill(WallStyle.tint(focus).opacity(0.22))
                    .frame(height: 2).position(x: w / 2, y: baseY + 24)
                RoundedRectangle(cornerRadius: 3).fill(AppPalette.ink.opacity(0.85))
                    .frame(width: 9, height: h * 0.7).position(x: w * 0.9, y: h * 0.42)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WallStyle.tint(focus), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 32, height: 32).position(x: w * 0.86, y: h * 0.40)
                Circle().fill(AppPalette.clay).frame(width: 18, height: 18).position(x: leftX, y: baseY)
                Circle().fill(Color.yellow).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
                    .frame(width: 13, height: 13)
                    .position(x: atWall ? rightX : leftX, y: baseY - h * 0.16)
            }
        }
        .frame(height: 150)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) { atWall = true }
        }
    }
}
