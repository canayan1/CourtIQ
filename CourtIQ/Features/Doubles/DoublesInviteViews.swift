import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Profile bridging

/// Builds the current user's portable `DoublesProfile` from their saved Tennis
/// Profile, and reports completeness. The mapping mirrors the "You (Player A)"
/// side of `DoublesService.buildSummary`: level rawValue, archetype/style,
/// handedness (not in the Tennis Profile → left nil), and the ranked
/// strengths / growth-area dimensions rendered as readable text.
enum DoublesProfileBuilder {
    /// True when the user has completed their Tennis Profile (a saved profile
    /// exists). The invite + accept flows require this so we never send an empty
    /// profile into the pairing.
    @MainActor
    static var hasCompletedProfile: Bool {
        TennisProfileStore.shared.profile != nil
    }

    /// Build `DoublesProfile` from the saved Tennis Profile, or nil if none.
    @MainActor
    static func current(name: String, language: AppLanguage) -> DoublesProfile? {
        guard let profile = TennisProfileStore.shared.profile else { return nil }
        // Strengths / growth-area copy reuses English dimension labels — the
        // analysis function answers in the user's language regardless, matching
        // DoublesService.buildSummary's convention.
        let copy = TennisProfileCopy(lang: .english)
        let result = profile.result

        let strengths = result.strengths.prefix(3).map { copy.dimension($0) }.joined(separator: ", ")
        let weaknesses = result.growthAreas.prefix(2).map { copy.dimension($0) }.joined(separator: ", ")

        return DoublesProfile(
            name: name,
            levelRaw: String(result.level.rawValue),
            handednessRaw: nil,
            styleRaw: result.archetype.rawValue,
            strengths: strengths,
            weaknesses: weaknesses
        )
    }
}

// MARK: - Invite copy (EN/TR)

/// Self-contained bilingual copy for the invite loop, mirroring `DoublesCopy`.
struct DoublesInviteCopy {
    let lang: AppLanguage
    private func t(_ en: String, _ tr: String) -> String { lang == .turkish ? tr : en }

    var sectionTitle: String { t("Pair up with your partner", "Partnerinle eşleş") }
    var sectionSubtitle: String {
        t("Link with your doubles partner to unlock your compatibility report.",
          "Uyum raporunuzu açmak için doubles partnerinle bağlan.")
    }
    var invitePartnerCTA: String { t("Invite a partner", "Partner davet et") }
    var haveCodeCTA: String { t("I have a code", "Kodum var") }

    // Invite sheet
    var inviteTitle: String { t("Invite your partner", "Partnerini davet et") }
    var inviteCodeLabel: String { t("Your invite code", "Davet kodun") }
    var inviteUnlockNote: String {
        t("When your partner joins, your compatibility unlocks here.",
          "Partnerin katıldığında uyumunuz burada açılır.")
    }
    /// Transparency: pairing exchanges Tennis Profile snapshots both ways.
    var shareNotice: String {
        t("Pairing shares your Tennis Profile (level, style, strengths) with your partner — and theirs with you.",
          "Eşleşme, Tenis Profilini (seviye, stil, güçlü yönler) partnerinle paylaşır — onunkini de seninle.")
    }
    var copyCode: String { t("Copy code", "Kodu kopyala") }
    var copyLink: String { t("Copy link", "Bağlantıyı kopyala") }
    var copied: String { t("Copied", "Kopyalandı") }
    func shareMessage(code: String, link: URL) -> String {
        t("Let's see how we'd play as a doubles team on DropVolley 🎾 Get the app and enter code \(code): \(link.absoluteString)",
          "DropVolley'de bir doubles takımı olarak nasıl oynardık görelim 🎾 Uygulamayı indir ve \(code) kodunu gir: \(link.absoluteString)")
    }
    var shareCTA: String { t("Share invite", "Daveti paylaş") }
    var doneCTA: String { t("Done", "Bitti") }

    // Accept sheet
    var acceptTitle: String { t("Enter invite code", "Davet kodunu gir") }
    var codeFieldPlaceholder: String { t("6-character code", "6 karakterli kod") }
    var continueCTA: String { t("Continue", "Devam") }
    var acceptCTA: String { t("Accept", "Kabul et") }
    func invitedYou(_ name: String) -> String {
        t("\(name) invited you to pair up", "\(name) seni eşleşmeye davet etti")
    }
    var acceptingNote: String {
        t("Accepting links you both and unlocks your compatibility report.",
          "Kabul etmek ikinizi bağlar ve uyum raporunuzu açar.")
    }

    // Lists
    var activeHeader: String { t("Your pairings", "Eşleşmelerin") }
    var pendingHeader: String { t("Pending invites", "Bekleyen davetler") }
    func waitingFor(_ code: String) -> String {
        t("Waiting for \(code) to join", "\(code) kodunun katılması bekleniyor")
    }
    var refreshCTA: String { t("Refresh", "Yenile") }
    var reshareCTA: String { t("Re-share", "Tekrar paylaş") }
    var viewReportCTA: String { t("View report", "Raporu gör") }
    var runReportCTA: String { t("See compatibility", "Uyumu gör") }

    var manualHeader: String {
        t("Just want a quick read? Add a partner manually",
          "Hızlı bir okuma mı istiyorsun? Manuel partner ekle")
    }

    // Profile gate
    var profileNeededTitle: String { t("Complete your Tennis Profile first", "Önce Tenis Profilini tamamla") }
    var profileNeededMessage: String {
        t("Take the short Tennis Profile so we can build your side of the pairing.",
          "Eşleşmenin senin tarafını oluşturabilmemiz için kısa Tenis Profilini doldur.")
    }
    var okCTA: String { t("OK", "Tamam") }

    // Errors
    var errorTitle: String { t("Something went wrong", "Bir şeyler ters gitti") }
    var genericError: String {
        t("Please try again.", "Lütfen tekrar dene.")
    }

    // Invite no longer acceptable (peek branch)
    var alreadyPairedTitle: String { t("You're already paired", "Zaten eşleştiniz") }
    var alreadyPairedMessage: String {
        t("You and this partner are already linked — check your pairings to see your compatibility report.",
          "Sen ve bu partner zaten bağlısınız — uyum raporunu görmek için eşleşmelerine bak.")
    }
    var inviteUsedTitle: String { t("Invite no longer available", "Davet artık geçerli değil") }
    var inviteUsedMessage: String {
        t("This invite was already used or has expired. Ask your partner for a fresh code.",
          "Bu davet kullanılmış ya da süresi dolmuş. Partnerinden yeni bir kod iste.")
    }
}

// MARK: - Invite section (embedded at top of DoublesView)

/// The hero invite card + active/pending partnership lists. Embedded above the
/// existing manual solo flow in `DoublesView`.
struct DoublesInviteSection: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var store = DoublesInviteStore.shared

    private var copy: DoublesInviteCopy { DoublesInviteCopy(lang: lang.language) }
    private let service = DoublesInviteService()

    @State private var showInviteSheet = false
    @State private var createdPartnership: DoublesPartnership?
    @State private var showAcceptSheet = false
    @State private var showProfileGate = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroCard

            if !store.activePartnerships.isEmpty {
                pairingsList
            }
            if !store.pendingPartnerships.isEmpty {
                pendingList
            }
        }
        .task { await refresh() }
        .sheet(isPresented: $showInviteSheet) {
            if let partnership = createdPartnership {
                DoublesInviteShareSheet(partnership: partnership)
            }
        }
        .sheet(isPresented: $showAcceptSheet) {
            DoublesAcceptSheet(onAccepted: { Task { await refresh() } })
        }
        .alert(copy.profileNeededTitle, isPresented: $showProfileGate) {
            Button(copy.okCTA, role: .cancel) {}
        } message: {
            Text(copy.profileNeededMessage)
        }
        .alert(copy.errorTitle, isPresented: $showError) {
            Button(copy.okCTA, role: .cancel) {}
        } message: {
            Text(errorMessage ?? copy.genericError)
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(copy.sectionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text(copy.sectionSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 10) {
                Button {
                    startInvite()
                } label: {
                    Label(copy.invitePartnerCTA, systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
                .disabled(isWorking)

                Button {
                    showAcceptSheet = true
                } label: {
                    Label(copy.haveCodeCTA, systemImage: "qrcode")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(isWorking)
            }

            if isWorking {
                ProgressView().frame(maxWidth: .infinity).tint(.white)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // "Hero + select cards": the invite hero gets a PhotoDoubles marquee
        // background; foreground flips to white over the duotone scrim.
        .brandedPhoto("PhotoDoubles", scrim: .hero, cornerRadius: 20)
    }

    // MARK: Active pairings

    private var pairingsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.activeHeader)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.ink)
            ForEach(store.activePartnerships) { partnership in
                DoublesPartnershipRow(partnership: partnership)
            }
        }
    }

    private var pendingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.pendingHeader)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.ink)
            ForEach(store.pendingPartnerships) { partnership in
                pendingRow(partnership)
            }
        }
    }

    private func pendingRow(_ partnership: DoublesPartnership) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppPalette.sand.opacity(0.5)).frame(width: 42, height: 42)
                Image(systemName: "hourglass")
                    .foregroundStyle(AppPalette.inkSoft)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(partnership.code)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(AppPalette.ink)
                Text(copy.waitingFor(partnership.code))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer(minLength: 0)
            Button {
                createdPartnership = partnership
                showInviteSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .tint(AppPalette.clay)
            .accessibilityLabel(copy.reshareCTA)
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .tint(AppPalette.moss)
            .accessibilityLabel(copy.refreshCTA)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Actions

    private func startInvite() {
        guard DoublesProfileBuilder.hasCompletedProfile else {
            showProfileGate = true
            return
        }
        guard let myProfile = DoublesProfileBuilder.current(name: session.displayName, language: lang.language) else {
            showProfileGate = true
            return
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let supabaseSession = try await ensureSession()
                let partnership = try await service.createInvite(
                    myName: session.displayName,
                    myProfile: myProfile,
                    session: supabaseSession
                )
                store.upsert(partnership)
                createdPartnership = partnership
                showInviteSheet = true
                Haptics.success()
            } catch {
                present(error)
            }
        }
    }

    private func refresh() async {
        do {
            let supabaseSession = try await ensureSession()
            let rows = try await service.fetchPartnerships(session: supabaseSession)
            store.replacePartnerships(rows)
        } catch {
            // Silent on background refresh — the hero card still works offline.
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        showError = true
    }

    private func ensureSession(attempts: Int = 3) async throws -> SupabaseSession {
        var lastError: Error?
        for i in 0..<attempts {
            do {
                return try await session.ensureAnonymousSession()
            } catch {
                lastError = error
                if i < attempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(700_000_000) * UInt64(i + 1))
                }
            }
        }
        throw lastError ?? RemoteDataError.missingConfiguration
    }
}

// MARK: - Active partnership row

/// One active pairing: partner name + a compatibility score badge. Tapping
/// runs (or opens) the compatibility report.
struct DoublesPartnershipRow: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var store = DoublesInviteStore.shared

    let partnership: DoublesPartnership

    private var copy: DoublesInviteCopy { DoublesInviteCopy(lang: lang.language) }
    private var doublesCopy: DoublesCopy { DoublesCopy(lang: lang.language) }

    @State private var showReport = false

    private var currentUserId: String? {
        session.remoteSession.flatMap { DoublesInviteService.authUserId(from: $0) }
    }

    var body: some View {
        Button {
            showReport = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(partnership.partnerDisplayName(forCurrentUserId: currentUserId))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(store.score(forPartnership: partnership.id) == nil ? copy.runReportCTA : copy.viewReportCTA)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                if let score = store.score(forPartnership: partnership.id) {
                    DoublesScoreBadge(score: score, copy: doublesCopy)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            // "Hero + select cards": active pairing rows get a PhotoDoubles
            // background; foreground flips to white over the duotone scrim.
            .brandedPhoto("PhotoDoubles", scrim: .bottom, cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showReport) {
            DoublesPartnershipReportView(partnership: partnership)
        }
    }
}

// MARK: - Partnership report (runs analyze, caches, shows)

/// Runs `DoublesService.analyze` for the OTHER side's profile, caches the report
/// in `DoublesInviteStore`, and shows it via the existing `DoublesReportDetailView`.
struct DoublesPartnershipReportView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var store = DoublesInviteStore.shared
    @Environment(\.dismiss) private var dismiss

    let partnership: DoublesPartnership

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private let service = DoublesService()

    private enum Phase { case analyzing, ready(DoublesReport), failed }
    @State private var phase: Phase = .analyzing
    @State private var errorMessage: String?

    /// First-run consent before any profile data is sent to Google (Gemini).
    @State private var showConsent = false

    private var currentUserId: String? {
        session.remoteSession.flatMap { DoublesInviteService.authUserId(from: $0) }
    }

    /// Both sides for the mutual profile cards: the partner from the shared
    /// partnership snapshot (named), "you" rebuilt from the local Tennis
    /// Profile. Nil only when the partner side is missing.
    private var pairProfiles: DoublesPairProfiles? {
        guard var partner = partnership.partnerProfile(forCurrentUserId: currentUserId) else { return nil }
        partner.name = partnership.partnerDisplayName(forCurrentUserId: currentUserId)
        let you = DoublesProfileBuilder.current(name: copy.youLabel, language: lang.language)
        return DoublesPairProfiles(you: you, partner: partner)
    }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            content
        }
        .navigationTitle(copy.reportTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureReport() }
        // First-run disclosure before any profile data leaves the device.
        // Declining ("Not now") pops back instead of stranding the spinner.
        .sheet(isPresented: $showConsent, onDismiss: {
            if !AIConsent.isAccepted(.doubles) { dismiss() }
        }) {
            NavigationStack {
                AIConsentView(spec: .doubles) { Task { await runAnalysis(force: true) } }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .analyzing:
            MatchAnalyzingView(title: copy.analyzingTitle, stepLabels: copy.analyzingSteps)
        case .ready(let report):
            DoublesReportDetailView(report: report, pair: pairProfiles)
        case .failed:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .appFont(36, design: .default)
                    .foregroundStyle(AppPalette.clay)
                Text(errorMessage ?? copy.errorGeneric)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
                Button(copy.retryCTA) { Task { await runAnalysis(force: true) } }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.clay)
            }
            .padding(40)
        }
    }

    private func ensureReport() async {
        if let cached = store.report(forPartnership: partnership.id) {
            phase = .ready(cached)
        } else {
            await runAnalysis(force: false)
        }
    }

    private func runAnalysis(force: Bool) async {
        // Gate the third-party send on explicit consent (first run only).
        guard AIConsent.isAccepted(.doubles) else { showConsent = true; return }
        phase = .analyzing
        guard let partnerProfile = partnership.partnerProfile(forCurrentUserId: currentUserId) else {
            errorMessage = copy.errorGeneric
            phase = .failed
            return
        }
        do {
            async let minimum: Void = Task.sleep(nanoseconds: 3_500_000_000)
            let supabaseSession = try await ensureSession()
            let result = try await service.analyze(
                partner: partnerProfile.asPartner(),
                language: lang.language,
                session: supabaseSession
            )
            try? await minimum

            let report = DoublesReport(
                partnerId: partnership.id,
                score: result.score,
                reportText: result.report
            )
            store.setReport(report, forPartnership: partnership.id)
            phase = .ready(report)
            // Peak moment: the compatibility score just landed (parity with
            // DoublesAnalysisView's reveal).
            Haptics.success()
        } catch {
            errorMessage = (error as? RemoteDataError)?.errorDescription ?? copy.errorGeneric
            phase = .failed
        }
    }

    private func ensureSession(attempts: Int = 3) async throws -> SupabaseSession {
        var lastError: Error?
        for i in 0..<attempts {
            do {
                return try await session.ensureAnonymousSession()
            } catch {
                lastError = error
                if i < attempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(700_000_000) * UInt64(i + 1))
                }
            }
        }
        throw lastError ?? RemoteDataError.missingConfiguration
    }
}

// MARK: - Invite share sheet

struct DoublesInviteShareSheet: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let partnership: DoublesPartnership

    private var copy: DoublesInviteCopy { DoublesInviteCopy(lang: lang.language) }

    @State private var copiedCode = false
    @State private var copiedLink = false

    private var link: URL { DoublesInviteService.universalLink(for: partnership.code) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.cream.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        Text(copy.inviteCodeLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.inkSoft)

                        Text(partnership.code)
                            .appFont(46, weight: .heavy)
                            .tracking(6)
                            .foregroundStyle(AppPalette.clay)
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .background(AppPalette.parchment)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppPalette.sand, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text(copy.inviteUnlockNote)
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)

                        Label(copy.shareNotice, systemImage: "person.2.badge.key.fill")
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)

                        ShareLink(
                            item: link,
                            message: Text(copy.shareMessage(code: partnership.code, link: link))
                        ) {
                            Label(copy.shareCTA, systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.clay)

                        HStack(spacing: 10) {
                            Button {
                                copyToPasteboard(partnership.code)
                                markCopied(.code)
                            } label: {
                                Label(copiedCode ? copy.copied : copy.copyCode,
                                      systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppPalette.moss)

                            Button {
                                copyToPasteboard(link.absoluteString)
                                markCopied(.link)
                            } label: {
                                Label(copiedLink ? copy.copied : copy.copyLink,
                                      systemImage: copiedLink ? "checkmark" : "link")
                                    .contentTransition(.symbolEffect(.replace))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppPalette.moss)
                        }
                        .animation(.snappy, value: copiedCode)
                        .animation(.snappy, value: copiedLink)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(copy.inviteTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.doneCTA) { dismiss() }.tint(AppPalette.clay)
                }
            }
        }
    }

    private enum CopyTarget { case code, link }

    private func copyToPasteboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }

    /// Flip the matching "Copied" flag on with a subtle tap, then auto-reset it
    /// after ~1.5s so the confirmation doesn't stick around.
    private func markCopied(_ target: CopyTarget) {
        Haptics.tap()
        switch target {
        case .code: copiedCode = true
        case .link: copiedLink = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            switch target {
            case .code: copiedCode = false
            case .link: copiedLink = false
            }
        }
    }
}

// MARK: - Accept sheet

struct DoublesAcceptSheet: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @Environment(\.dismiss) private var dismiss

    var onAccepted: () -> Void

    private var copy: DoublesInviteCopy { DoublesInviteCopy(lang: lang.language) }
    private let service = DoublesInviteService()

    private enum Step {
        case enterCode
        case confirm(inviterName: String)
        /// Peek told us the code can't be accepted (already paired, or used /
        /// expired). We show a clear, friendly state instead of falling through
        /// to the confirm step and dumping a raw server error.
        case unavailable(title: String, message: String)
    }
    @State private var step: Step = .enterCode
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showProfileGate = false

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.cream.ignoresSafeArea()
                content
            }
            .navigationTitle(copy.acceptTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(copy.doneCTA) { dismiss() }.tint(AppPalette.inkSoft)
                }
            }
            .alert(copy.profileNeededTitle, isPresented: $showProfileGate) {
                Button(copy.okCTA, role: .cancel) {}
            } message: {
                Text(copy.profileNeededMessage)
            }
            .alert(copy.errorTitle, isPresented: $showError) {
                Button(copy.okCTA, role: .cancel) {}
            } message: {
                Text(errorMessage ?? copy.genericError)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 22) {
                switch step {
                case .enterCode:
                    enterCodeStep
                case .confirm(let inviterName):
                    confirmStep(inviterName: inviterName)
                case .unavailable(let title, let message):
                    unavailableStep(title: title, message: message)
                }
                if isWorking { ProgressView() }
            }
            .padding(24)
        }
    }

    private var enterCodeStep: some View {
        VStack(spacing: 18) {
            TextField(copy.codeFieldPlaceholder, text: $code)
                .appFont(28, weight: .bold)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: code) { _, newValue in
                    let upper = newValue.uppercased()
                    if upper != newValue { code = upper }
                    if code.count > 6 { code = String(code.prefix(6)) }
                }

            Button {
                peek()
            } label: {
                Text(copy.continueCTA)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .disabled(trimmedCode.count < 4 || isWorking)
        }
    }

    private func confirmStep(inviterName: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "person.2.wave.2.fill")
                .appFont(40, design: .default)
                .foregroundStyle(AppPalette.clay)
            Text(copy.invitedYou(inviterName))
                .font(.title3.weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)
            Text(copy.acceptingNote)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)

            Label(copy.shareNotice, systemImage: "person.2.badge.key.fill")
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                accept()
            } label: {
                Text(copy.acceptCTA)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .disabled(isWorking)
        }
    }

    private func unavailableStep(title: String, message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .appFont(40, design: .default)
                .foregroundStyle(AppPalette.moss)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text(copy.doneCTA)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
    }

    // MARK: Actions

    private func peek() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let supabaseSession = try await ensureSession()
                let result = try await service.peekInvite(code: trimmedCode, session: supabaseSession)

                // Branch on the peek result BEFORE the confirm step so an
                // already-accepted / used / expired code shows a clear, friendly
                // state rather than falling through and dumping a raw server error.
                if result.alreadyMember {
                    step = .unavailable(title: copy.alreadyPairedTitle,
                                        message: copy.alreadyPairedMessage)
                    return
                }
                let normalizedStatus = result.status
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if normalizedStatus != "pending" {
                    step = .unavailable(title: copy.inviteUsedTitle,
                                        message: copy.inviteUsedMessage)
                    return
                }

                let name = result.inviterName?.trimmingCharacters(in: .whitespacesAndNewlines)
                step = .confirm(inviterName: (name?.isEmpty == false ? name! : "A player"))
            } catch {
                present(error)
            }
        }
    }

    private func accept() {
        guard DoublesProfileBuilder.hasCompletedProfile,
              let myProfile = DoublesProfileBuilder.current(name: session.displayName, language: lang.language) else {
            showProfileGate = true
            return
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let supabaseSession = try await ensureSession()
                _ = try await service.acceptInvite(
                    code: trimmedCode,
                    myName: session.displayName,
                    myProfile: myProfile,
                    session: supabaseSession
                )
                Haptics.success()
                onAccepted()
                dismiss()
            } catch {
                present(error)
            }
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? RemoteDataError)?.errorDescription ?? error.localizedDescription
        showError = true
    }

    private func ensureSession(attempts: Int = 3) async throws -> SupabaseSession {
        var lastError: Error?
        for i in 0..<attempts {
            do {
                return try await session.ensureAnonymousSession()
            } catch {
                lastError = error
                if i < attempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(700_000_000) * UInt64(i + 1))
                }
            }
        }
        throw lastError ?? RemoteDataError.missingConfiguration
    }
}
