import SwiftUI

/// Join flow: the invitee enters the code their partner sent, sees who invited
/// them, answers their own 9 questions, and accepts — both accounts then share
/// the partnership and its compatibility score.
struct DoublesJoinView: View {
    /// When set (e.g. from a universal-link tap), the code is prefilled and
    /// looked up automatically on appear.
    var prefillCode: String? = nil

    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var service = DoublesService.shared

    private enum Phase { case code, answers }
    @State private var phase: Phase = .code
    @State private var code = ""
    @State private var myName = ""
    @State private var me = DoublesDraft()
    @State private var peek: DoublesInvitePeek?
    @State private var isWorking = false
    @State private var error: String?
    @State private var result: DoublesPartnership?
    @State private var didPrefill = false

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch phase {
                case .code:    codePhase
                case .answers: answersPhase
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.joinTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            service.configure { try await session.ensureAnonymousSession() }
            if let prefillCode, !didPrefill {
                didPrefill = true
                code = prefillCode
                await lookUp()
            }
        }
        .navigationDestination(item: $result) { DoublesResultView(partnership: $0) }
    }

    private var codePhase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.joinCodePrompt).font(.title3.bold()).foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            TextField(copy.joinCodePlaceholder, text: $code)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .monospaced)).tracking(3)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error { Text(error).font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }

            Button { Task { await lookUp() } } label: {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(copy.lookUp)
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(AppPalette.clay)
            .disabled(trimmedCode.count < 4 || isWorking)
        }
    }

    private var answersPhase: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark").foregroundStyle(AppPalette.clay)
                Text(invitedByText).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(AppPalette.clay.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

            Button { Task { await accept() } } label: {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(copy.joinSeeScore)
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(AppPalette.clay)
            .disabled(!me.isComplete || isWorking)
        }
    }

    private var invitedByText: String {
        if let name = peek?.inviterName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            return copy.invitedByLine(name)
        }
        return copy.someoneInvitedYou
    }

    private func lookUp() async {
        isWorking = true; defer { isWorking = false }
        error = nil
        do {
            let p = try await service.peekInvite(code: trimmedCode)
            peek = p
            phase = .answers
        } catch {
            self.error = (error as? RemoteDataError)?.errorDescription ?? copy.inviteNotFound
        }
    }

    private func accept() async {
        guard let profile = me.build() else { return }
        isWorking = true; defer { isWorking = false }
        error = nil
        do {
            let trimmed = myName.trimmingCharacters(in: .whitespaces)
            let row = try await service.acceptInvite(code: trimmedCode, myName: trimmed.isEmpty ? nil : trimmed, myProfile: profile)
            let uid = service.currentUserID ?? ""
            result = row.viewerPartnership(userID: uid)
        } catch {
            self.error = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        }
    }
}
