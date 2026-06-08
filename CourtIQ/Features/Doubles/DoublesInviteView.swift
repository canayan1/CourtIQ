import SwiftUI

/// Invite flow: the inviter answers their 9 questions, creates a server-backed
/// pending partnership, and shares a link + code. When the partner accepts,
/// the compatibility score appears in the partnerships list (Step 6 makes the
/// link deep-open the app; for now the code can be entered manually).
struct DoublesInviteView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var service = DoublesService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var myName = ""
    @State private var me = DoublesDraft()
    @State private var created: DoublesPartnershipRow?
    @State private var isWorking = false
    @State private var error: String?

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private func inviteLink(_ code: String) -> String { "https://canayan-ios-apps.vercel.app/d/\(code)" }

    var body: some View {
        ScrollView {
            if let created {
                inviteReady(created)
            } else {
                answerPhase
            }
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.inviteTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { service.configure { try await session.ensureAnonymousSession() } }
    }

    private var answerPhase: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(copy.inviteIntro)
                .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.yourNamePrompt).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                TextField(copy.yourNamePlaceholder, text: $myName)
                    .textFieldStyle(.plain).padding(.horizontal, 14).padding(.vertical, 12)
                    .background(AppPalette.parchment)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.sand, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            DoublesAnswerForm(draft: $me, copy: copy)

            if let error { Text(error).font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }

            Button { Task { await createInvite() } } label: {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(copy.createInviteCTA)
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(AppPalette.clay)
            .disabled(!me.isComplete || isWorking)
            .padding(.top, 4)
        }
        .padding()
    }

    private func inviteReady(_ row: DoublesPartnershipRow) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54)).foregroundStyle(AppPalette.moss).padding(.top, 18)
            Text(copy.inviteReadyTitle).font(.title3.bold()).foregroundStyle(AppPalette.ink)
            Text(copy.inviteReadyBody)
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Text(copy.inviteCodeLabel).font(.caption.weight(.heavy)).tracking(0.6).foregroundStyle(AppPalette.inkSoft)
                Text(row.code)
                    .font(.system(size: 32, weight: .black, design: .monospaced)).tracking(4)
                    .foregroundStyle(AppPalette.clay)
            }
            .padding().frame(maxWidth: .infinity)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            ShareLink(item: copy.inviteShareMessage(link: inviteLink(row.code), code: row.code)) {
                Label(copy.shareInvite, systemImage: "square.and.arrow.up")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppPalette.clay).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text(copy.pendingNote).font(.footnote).foregroundStyle(AppPalette.inkSoft)
            Button(copy.done) { dismiss() }.buttonStyle(.bordered).tint(AppPalette.inkSoft)
        }
        .padding()
    }

    private func createInvite() async {
        guard let profile = me.build() else { return }
        isWorking = true; defer { isWorking = false }
        error = nil
        do {
            let trimmed = myName.trimmingCharacters(in: .whitespaces)
            created = try await service.createInvite(myName: trimmed.isEmpty ? nil : trimmed, myProfile: profile)
        } catch {
            self.error = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        }
    }
}
