import SwiftUI

/// Clips, in and out: strokes friends sent you (answer them), strokes you
/// shared (see the views), your friend link, and the coach application.
struct ClipsHubView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    @State private var inbox: [ClipsService.InboxClip] = []
    @State private var mine: [ClipsService.OwnedClip] = []
    @State private var invite: ClipsService.InviteCode?
    @State private var friendCount = 0
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
                        row(icon: "film", title: lang.t("clips.stroke_\(c.stroke)"),
                            sub: String(format: lang.t("clips.views_fmt"), c.views), moss: false) { open = c.id }
                    }
                }

                sectionTitle(lang.t("clips.friends"))
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(format: lang.t("clips.friends_fmt"), friendCount)).font(.subheadline).foregroundStyle(AppPalette.ink)
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
            inbox = (try? await a) ?? []
            mine = (try? await b) ?? []
            invite = try? await c
            friendCount = ((try? await d) ?? []).count
        }
        loading = false
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
