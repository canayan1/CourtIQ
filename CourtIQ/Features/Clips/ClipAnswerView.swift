import SwiftUI
import AVKit

/// Look at a friend's stroke and say what you see. Four questions, votes hidden
/// until you commit, then every view side by side. The same screen shows the
/// owner their own clip's result — with the "answer" step skipped, because
/// nobody answers their own clip.
struct ClipAnswerView: View {
    let clipID: String

    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    private let bank = ClipQuestionBank.shared

    @State private var playback: ClipsService.Playback?
    @State private var player: AVPlayer?
    @State private var tally: ClipsService.Tally?
    @State private var isOwner = false
    @State private var q1: String?
    @State private var q2: String?
    @State private var q3Ms: Int?
    @State private var q4: Double?
    @State private var includeQ4 = false
    @State private var submitted = false
    @State private var busy = false
    @State private var error: String?

    private var ready: Bool { q1 != nil && (q1 == "unclear" || (q2 != nil && q3Ms != nil)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let playback {
                        Eyebrow(lang.t("clips.stroke_\(playback.stroke)"))
                        Text(isOwner ? lang.t("clips.result_title") : lang.t("clips.answer_title"))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppPalette.ink)
                        if let player {
                            VideoPlayer(player: player)
                                .frame(height: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .onAppear { player.play() }
                        }
                        if !isOwner && !submitted { questions }
                        if submitted || isOwner { result }
                    } else if let error {
                        Text(error).foregroundStyle(AppPalette.alert)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(40)
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("clips.title"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("ClipAnswer")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(lang.t("common.done")) { dismiss() }.foregroundStyle(AppPalette.clay) } }
            .task { await load() }
        }
    }

    // MARK: - Questions

    private var questions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(lang.t("clips.answer_body")).font(.footnote).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)

            section("1 · " + bank.q1.prompt) {
                flow(bank.q1.options, selected: q1) { q1 = $0; q2 = nil }
            }
            if let q1, q1 != "unclear", let opts = bank.q2.byQ1[q1] {
                section("2 · " + bank.q2.prompt) { flow(opts, selected: q2) { q2 = $0 } }
                section("3 · " + bank.q3.prompt) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t("clips.q3_hint")).font(.caption).foregroundStyle(AppPalette.inkSoft)
                        Button {
                            guard let player else { return }
                            player.pause()
                            q3Ms = Int(player.currentTime().seconds * 1000)
                            Haptics.tap()
                        } label: {
                            Text(q3Ms == nil ? lang.t("clips.q3_mark") : String(format: lang.t("clips.q3_marked_fmt"), Double(q3Ms!) / 1000))
                                .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(q3Ms == nil ? AppPalette.clay : AppPalette.moss, in: Capsule())
                        }
                    }
                }
            }
            if q1 != nil {
                section("4 · " + bank.q4.prompt) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(lang.t("clips.q4_toggle"), isOn: $includeQ4).tint(AppPalette.clay).font(.footnote)
                        if includeQ4, let sys = bank.q4.systems["wtn"], let lo = sys.min, let hi = sys.max {
                            HStack {
                                Text("WTN \((q4 ?? 25).formatted(.number.precision(.fractionLength(1))))")
                                    .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.clay).monospacedDigit()
                                Slider(value: Binding(get: { q4 ?? 25 }, set: { q4 = $0 }), in: lo...hi, step: sys.step ?? 0.5).tint(AppPalette.clay)
                            }
                            Text(lang.t("clips.q4_hint")).font(.caption2).foregroundStyle(AppPalette.inkSoft)
                        }
                    }
                }
            }
            PrimaryButton(title: busy ? lang.t("clips.sending") : lang.t("clips.see_views"), icon: "eye") { Task { await submit() } }
                .disabled(!ready || busy).opacity(ready ? 1 : 0.5)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.ink)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface(cornerRadius: 18)
    }

    private func flow(_ options: [ClipQuestionBank.Option], selected: String?, pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(options) { o in
                Button { pick(o.id); Haptics.tap() } label: {
                    HStack {
                        Text(o.label).font(.subheadline.weight(selected == o.id ? .bold : .medium)).foregroundStyle(AppPalette.ink)
                        Spacer()
                        Image(systemName: selected == o.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected == o.id ? AppPalette.clay : AppPalette.sand)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(selected == o.id ? AppPalette.clayTint : AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Result

    private var result: some View {
        VStack(alignment: .leading, spacing: 12) {
            if submitted, let q1 {
                viewCard(title: lang.t("clips.your_view"), icon: "person.fill", accent: true,
                         rows: [(bank.q1.options.first { $0.id == q1 }?.label ?? q1, nil),
                                (q2.map { bank.label($0) }, nil),
                                (q3Ms.map { String(format: "%.1f s", Double($0) / 1000) }, nil),
                                (q4.map { "WTN \($0.formatted(.number.precision(.fractionLength(1))))" }, nil)]
                            .compactMap { r in r.0.map { ($0, r.1) } })
            }
            if let tally {
                ForEach(ClipViewKind.allCases, id: \.rawValue) { kind in
                    if let t = tally.kind(kind.rawValue) { kindCard(kind, t) }
                }
                if isOwner, let d = tally.declared, let v = d.value {
                    Text(String(format: lang.t("clips.declared_fmt"), (d.system ?? "").uppercased(), v))
                        .font(.caption).foregroundStyle(AppPalette.inkSoft)
                }
            }
            Text(lang.t("clips.no_truth")).font(.caption).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func kindCard(_ kind: ClipViewKind, _ t: ClipsService.KindTally) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: kind.icon).foregroundStyle(kind == .coach ? AppPalette.gold : AppPalette.clay)
                Text(lang.t(kind.titleKey)).font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.ink)
                Spacer()
                Text(t.shown ? String(format: lang.t("clips.views_fmt"), t.n)
                             : (t.n == 0 ? lang.t("clips.nobody_yet") : String(format: lang.t("clips.not_enough_fmt"), t.n, bank.minVotesForCrowd)))
                    .font(.caption).foregroundStyle(AppPalette.inkSoft)
            }
            if t.shown {
                if let q1 = t.q1 { dist(q1, n: t.n) }
                if let q2 = t.q2, !q2.isEmpty { dist(q2, n: t.n, small: true) }
                if let m = t.q3_median_ms { row(lang.t("clips.moment_median"), String(format: "%.1f s", m / 1000)) }
                if let mean = t.q4_mean { row(lang.t("clips.level_mean"), "WTN \(mean.formatted(.number.precision(.fractionLength(1))))") }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardSurface(cornerRadius: 18)
    }

    private func viewCard(title: String, icon: String, accent: Bool, rows: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Image(systemName: icon); Text(title).font(.subheadline.weight(.bold)) }.foregroundStyle(AppPalette.clayText)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                Text(r.0).font(.footnote).foregroundStyle(AppPalette.ink)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.clayTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dist(_ m: [String: Int], n: Int, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(m.sorted { $0.value > $1.value }, id: \.key) { k, c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text(bank.label(k)).font(small ? Font.caption : Font.footnote); Spacer(); Text("\(Int((Double(c) / Double(n) * 100).rounded()))%").font((small ? Font.caption : Font.footnote).weight(.bold)) }
                        .foregroundStyle(AppPalette.ink)
                    GeometryReader { g in
                        Capsule().fill(AppPalette.sand).frame(height: 4)
                            .overlay(alignment: .leading) { Capsule().fill(small ? AppPalette.inkSoft : AppPalette.clay).frame(width: g.size.width * Double(c) / Double(n), height: 4) }
                    }.frame(height: 4)
                }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.footnote).foregroundStyle(AppPalette.inkSoft); Spacer(); Text(v).font(.footnote.weight(.bold)).foregroundStyle(AppPalette.ink) }
    }

    // MARK: - Work

    private func load() async {
        do {
            let s = try await session.ensureSessionWithRetry()
            let p = try await ClipsService.playback(clipId: clipID, session: s)
            playback = p
            if let u = p.url, let url = URL(string: u) { let pl = AVPlayer(url: url); pl.isMuted = true; player = pl }
            let mine = (try? await ClipsService.mine(session: s)) ?? []
            isOwner = mine.contains { $0.id == clipID }
            if isOwner { tally = try? await ClipsService.tally(clipId: clipID, session: s) }
            else {
                // Already answered? Then skip straight to the views.
                let inbox = (try? await ClipsService.inbox(session: s)) ?? []
                if inbox.first(where: { $0.id == clipID })?.answered == true {
                    submitted = true; tally = try? await ClipsService.tally(clipId: clipID, session: s)
                }
            }
        } catch { self.error = error.localizedDescription }
    }

    private func submit() async {
        guard let q1 else { return }
        busy = true; error = nil
        do {
            let s = try await session.ensureSessionWithRetry()
            let r = try await ClipsService.vote(clipId: clipID, q1: q1, q2: q1 == "unclear" ? nil : q2, q3Ms: q1 == "unclear" ? nil : q3Ms, q4: includeQ4 ? q4 : nil, session: s)
            tally = r.tally; submitted = true
            AppAnalytics.shared.log(AnalyticsEvent.clipAnswered, ["kind": r.kind])
            Haptics.tap()
        } catch { self.error = error.localizedDescription }
        busy = false
    }
}
