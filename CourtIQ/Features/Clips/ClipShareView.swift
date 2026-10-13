import SwiftUI
import PhotosUI
import AVKit

/// Share a stroke: pick a video, say which stroke, (optionally) your rating,
/// upload, get a link. Thirty seconds, and the link is the whole product —
/// whoever opens it answers in the browser without installing.
struct ClipShareView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    private let bank = ClipQuestionBank.shared

    @State private var pickerItem: PhotosPickerItem?
    @State private var picked: PickedMovie?
    @State private var prepared: ClipsService.Prepared?
    @State private var player: AVPlayer?
    @State private var stroke = "forehand"
    @State private var ratingSystem = "wtn"
    @State private var ratingValue: Double = 25
    @State private var includeRating = false
    @State private var consented = false
    @State private var phase: Phase = .pick
    @State private var created: ClipsService.Created?
    @State private var error: String?

    private enum Phase { case pick, preparing, ready, uploading, done }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(lang.t("clips.share_eyebrow"))
                    Text(lang.t("clips.share_title"))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    switch phase {
                    case .pick: pickCard
                    case .preparing: ProgressView(lang.t("clips.preparing")).frame(maxWidth: .infinity).padding(30)
                    case .ready, .uploading: readyCard
                    case .done: doneCard
                    }

                    if let error {
                        Text(error).font(.footnote).foregroundStyle(AppPalette.alert).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("clips.title"))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("ClipShare")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(lang.t("common.done")) { dismiss() }.foregroundStyle(AppPalette.clay) } }
            .onChange(of: pickerItem) { _, item in Task { await load(item) } }
        }
    }

    // MARK: - Steps

    private var pickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("clips.pick_body")).font(.subheadline).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
            PhotosPicker(selection: $pickerItem, matching: .videos, photoLibrary: .shared()) {
                HStack(spacing: 8) { Image(systemName: "film"); Text(lang.t("clips.pick_button")) }
                    .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text(lang.t("clips.pick_hint")).font(.caption).foregroundStyle(AppPalette.inkSoft)
        }
        .padding(18).cardSurface(cornerRadius: 22)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onAppear { player.play() }
            }
            if let prepared {
                Text(String(format: lang.t("clips.length_fmt"), Double(prepared.durationMs) / 1000))
                    .font(.caption).foregroundStyle(AppPalette.inkSoft)
            }

            Text(lang.t("clips.stroke_prompt")).font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.ink)
            HStack(spacing: 8) {
                ForEach(bank.strokes, id: \.self) { s in
                    Button { stroke = s } label: {
                        Text(lang.t("clips.stroke_\(s)")).font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(stroke == s ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                            .foregroundStyle(stroke == s ? .white : AppPalette.ink)
                    }
                }
            }

            Toggle(isOn: $includeRating) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("clips.rating_toggle")).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    Text(lang.t("clips.rating_why")).font(.caption).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppPalette.clay)
            if includeRating, let sys = bank.q4.systems[ratingSystem], let lo = sys.min, let hi = sys.max {
                HStack {
                    Text("\(sys.label) \(ratingValue.formatted(.number.precision(.fractionLength(1))))")
                        .font(.headline).foregroundStyle(AppPalette.clay).monospacedDigit()
                    Slider(value: $ratingValue, in: lo...hi, step: sys.step ?? 0.5).tint(AppPalette.clay)
                }
            }

            Toggle(isOn: $consented) {
                Text(lang.t("clips.consent")).font(.footnote).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
            }
            .tint(AppPalette.moss)

            PrimaryButton(title: phase == .uploading ? lang.t("clips.uploading") : lang.t("clips.get_link"), icon: "link") {
                Task { await uploadAndCreate() }
            }
            .disabled(!consented || phase == .uploading)
            .opacity(consented ? 1 : 0.5)
        }
        .padding(18).cardSurface(cornerRadius: 22)
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(AppPalette.clay)
            Text(lang.t("clips.done_title")).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(AppPalette.ink)
            Text(lang.t("clips.done_body")).font(.subheadline).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
            if let created, let url = URL(string: created.url) {
                Text(created.url).font(.caption.monospaced()).foregroundStyle(AppPalette.inkSoft)
                ShareLink(item: url, message: Text(lang.t("clips.share_message"))) {
                    HStack(spacing: 8) { Image(systemName: "paperplane.fill"); Text(lang.t("clips.send_link")) }
                        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .simultaneousGesture(TapGesture().onEnded { AppAnalytics.shared.log(AnalyticsEvent.clipShared, ["stroke": stroke]) })
            }
        }
        .padding(18).cardSurface(cornerRadius: 22)
    }

    // MARK: - Work

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        phase = .preparing; error = nil
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw ClipsService.Failure.export }
            picked = movie
            let p = try await ClipsService.prepare(sourceURL: movie.url, maxSeconds: Double(bank.maxClipMs) / 1000)
            prepared = p
            let pl = AVPlayer(url: p.fileURL); pl.isMuted = true
            player = pl
            phase = .ready
        } catch {
            self.error = error.localizedDescription; phase = .pick; pickerItem = nil
        }
    }

    private func uploadAndCreate() async {
        guard let prepared else { return }
        phase = .uploading; error = nil
        do {
            let s = try await session.ensureSessionWithRetry()
            let rating: (system: String, value: Double?, band: String?)? = includeRating ? (ratingSystem, ratingValue, nil) : nil
            let c = try await ClipsService.create(stroke: stroke, durationMs: prepared.durationMs, rating: rating, session: s)
            try await ClipsService.upload(fileURL: prepared.fileURL, to: c.uploadUrl, contentType: "video/mp4")
            if let poster = prepared.posterURL, let purl = c.posterUploadUrl {
                try? await ClipsService.upload(fileURL: poster, to: purl, contentType: "image/jpeg")
            }
            try await ClipsService.finalize(clipId: c.clipId, session: s)
            created = c
            phase = .done
            Haptics.tap()
        } catch {
            self.error = error.localizedDescription; phase = .ready
        }
    }
}
