import SwiftUI

/// Clips, in and out: strokes friends sent you (answer them), strokes you
/// shared (see the views), your friend link, and the coach application.
struct ClipsHubView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    @State private var inbox: [ClipsService.InboxClip] = []
    @State private var mine: [ClipsService.OwnedClip] = []
    @State private var invite: ClipsService.InviteCode?
    @State private var friends: [ClipsService.Friend] = []
    @State private var displayName = ""
    @State private var pinnedClipId: String?
    @State private var showShare = false
    @State private var open: String?
    @State private var showCoachApply = false
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(lang.t("clips.hub_eyebrow"))
                Text(lang.t("clips.hub_title")).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(AppPalette.ink)
                Text(lang.t("clips.hub_body")).font(.subheadline).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)

                PrimaryButton(title: lang.t("clips.share_cta"), icon: "video.badge.plus") { showShare = true }

                if !inbox.isEmpty {
                    sectionTitle(lang.t("clips.inbox"))
                    ForEach(inbox) { c in
                        row(icon: c.answered ? "checkmark.circle.fill" : "eye",
                            title: lang.t("clips.stroke_\(c.stroke)"),
                            sub: c.answered ? lang.t("clips.answered") : lang.t("clips.waiting_for_you"),
                            moss: c.answered) { open = c.id }
                    }
                }

                sectionTitle(lang.t("clips.mine"))
                if mine.isEmpty && !loading {
                    Text(lang.t("clips.mine_empty")).font(.footnote).foregroundStyle(AppPalette.inkSoft)
                } else {
                    ForEach(mine) { c in
                        HStack(spacing: 8) {
                            row(icon: pinnedClipId == c.id ? "pin.fill" : "film", title: lang.t("clips.stroke_\(c.stroke)"),
                                sub: String(format: lang.t("clips.views_fmt"), c.views), moss: pinnedClipId == c.id) { open = c.id }
                            Button {
                                Task { await setPin(pinnedClipId == c.id ? nil : c.id) }
                            } label: {
                                Image(systemName: pinnedClipId == c.id ? "pin.slash" : "pin")
                                    .font(.subheadline).foregroundStyle(AppPalette.clay).frame(width: 36, height: 36)
                                    .background(AppPalette.clayTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .accessibilityLabel(lang.t(pinnedClipId == c.id ? "clips.unpin" : "clips.pin"))
                        }
                    }
                    Text(lang.t("clips.pin_hint")).font(.caption).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }

                sectionTitle(lang.t("clips.name"))
                HStack(spacing: 8) {
                    TextField(lang.t("clips.name_placeholder"), text: $displayName)
                        .textFieldStyle(.plain).padding(12)
                        .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button(lang.t("common.save")) { Task { await saveName() } }
                        .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.clay)
                }
                Text(lang.t("clips.name_hint")).font(.caption).foregroundStyle(AppPalette.inkSoft)

                sectionTitle(lang.t("clips.friends"))
                if !friends.isEmpty {
                    ForEach(friends) { f in
                        if let pin = f.pinned {
                            row(icon: "pin.fill", title: f.displayName ?? lang.t("clips.friend_unnamed"),
                                sub: lang.t("clips.stroke_\(pin.stroke)") + " · " + lang.t("clips.pinned_by_friend"), moss: false) { open = pin.id }
                        } else {
                            row(icon: "person", title: f.displayName ?? lang.t("clips.friend_unnamed"),
                                sub: lang.t("clips.no_pin_yet"), moss: false) { }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: lang.t("clips.friends_fmt"), friends.count)).font(.subheadline).foregroundStyle(AppPalette.ink)
                    Text(lang.t("clips.friends_body")).font(.footnote).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
                    if let invite, let url = URL(string: invite.url) {
                        ShareLink(item: url, message: Text(lang.t("clips.friend_message"))) {
                            HStack(spacing: 8) { Image(systemName: "person.badge.plus"); Text(lang.t("clips.friend_link")) }
                                .font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.clay)
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardSurface(cornerRadius: 18)

                Button { showCoachApply = true } label: {
                    HStack { Image(systemName: "star"); Text(lang.t("clips.coach_apply")) }
                        .font(.footnote.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                }
                .padding(.top, 6)
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("clips.title"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("ClipsHub")
        .task { await refresh() }
        .sheet(isPresented: $showShare, onDismiss: { Task { await refresh() } }) { ClipShareView().environmentObject(lang).environmentObject(session) }
        .sheet(item: Binding(get: { open.map(Box.init) }, set: { open = $0?.id })) { b in
            ClipAnswerView(clipID: b.id).environmentObject(lang).environmentObject(session)
        }
        .sheet(isPresented: $showCoachApply) { CoachApplyView().environmentObject(lang).environmentObject(session) }
    }

    private struct Box: Identifiable { let id: String }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(AppPalette.inkSoft).padding(.top, 6)
    }

    private func row(icon: String, title: String, sub: String, moss: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 30, height: 30)
                    .background(moss ? AppPalette.mossTint : AppPalette.clayTint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .foregroundStyle(moss ? AppPalette.mossText : AppPalette.clayText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.ink)
                    Text(sub).font(.caption).foregroundStyle(AppPalette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppPalette.inkSoft)
            }
            .padding(12).background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func refresh() async {
        loading = true
        if let s = try? await session.ensureSessionWithRetry() {
            async let a = ClipsService.inbox(session: s)
            async let b = ClipsService.mine(session: s)
            async let c = ClipsService.inviteCode(session: s)
            async let d = ClipsService.friends(session: s)
            async let e = ClipsService.profile(session: s)
            inbox = (try? await a) ?? []
            mine = (try? await b) ?? []
            invite = try? await c
            friends = (try? await d) ?? []
            if let pr = try? await e { displayName = pr.displayName ?? ""; pinnedClipId = pr.pinnedClipId }
        }
        loading = false
    }

    private func setPin(_ id: String?) async {
        guard let s = try? await session.ensureSessionWithRetry() else { return }
        try? await ClipsService.setProfile(displayName: nil, pin: .some(id), session: s)
        pinnedClipId = id
        Haptics.tap()
    }

    private func saveName() async {
        guard let s = try? await session.ensureSessionWithRetry() else { return }
        try? await ClipsService.setProfile(displayName: displayName, pin: nil, session: s)
        Haptics.tap()
    }
}

/// "I coach" — a credential type and reference; Can verifies by hand. Until
/// then nothing changes and nothing says "pending".
struct CoachApplyView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var type = "ITF"
    @State private var ref = ""
    @State private var sent = false
    private let types = ["ITF", "PTR", "USPTA", "LTA", "TTF", "FFT", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(lang.t("clips.coach_apply_footer"))) {
                    Picker(lang.t("clips.coach_credential"), selection: $type) { ForEach(types, id: \.self) { Text($0) } }
                    TextField(lang.t("clips.coach_ref"), text: $ref)
                }
                Section {
                    Button(sent ? lang.t("clips.coach_sent") : lang.t("clips.coach_send")) {
                        Task { if let s = try? await session.ensureSessionWithRetry() { try? await ClipsService.applyAsCoach(credentialType: type, credentialRef: ref, session: s); sent = true } }
                    }.disabled(sent)
                }
            }
            .navigationTitle(lang.t("clips.coach_apply"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(lang.t("common.done")) { dismiss() } } }
        }
    }
}
