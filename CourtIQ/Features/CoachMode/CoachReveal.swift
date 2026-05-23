import SwiftUI

/// Side-by-side comparison shown after both phones in Coach Mode have
/// submitted their ratings. This is the moment that justifies the whole
/// feature: each player sees how the *opponent* saw the match, with
/// the deltas explicitly called out.
///
/// Optionally saves the comparison into the user's Match Journal as a
/// new entry so the insight persists past the session.
struct CoachReveal: View {
    let local: CoachSession.Submission
    let peer: CoachSession.Submission
    let peerName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var matches: MatchEntryManager
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                comparisonGrid
                takeawayPair
                if !saved { saveButton } else { savedBadge }
            }
            .padding(22)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("coach.reveal_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lang.t("coach.reveal_kicker"))
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
            Text(lang.t("coach.reveal_subhead"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 4-row dimension comparison

    private var comparisonGrid: some View {
        VStack(spacing: 14) {
            row(label: lang.t("coach.dim_serve"),     mine: local.serveRating,    theirs: peer.serveRating,    glyph: .serve)
            row(label: lang.t("coach.dim_return"),    mine: local.returnRating,   theirs: peer.returnRating,   glyph: .backhand)
            row(label: lang.t("coach.dim_movement"),  mine: local.movementRating, theirs: peer.movementRating, glyph: .mobility)
            row(label: lang.t("coach.dim_mental"),    mine: local.mentalRating,   theirs: peer.mentalRating,   glyph: .target)
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(label: String, mine: Int, theirs: Int, glyph: TennisGlyphKind) -> some View {
        let delta = mine - theirs
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TennisGlyph(kind: glyph, color: AppPalette.clay, size: 18)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                deltaBadge(delta)
            }

            HStack(spacing: 8) {
                ratingBar(value: mine, total: 5, tint: AppPalette.clay,
                          label: lang.t("coach.you"))
                ratingBar(value: theirs, total: 5, tint: AppPalette.moss,
                          label: peerName)
            }
        }
    }

    /// Shows the delta as "+N" green, "-N" red, or "·" neutral. The
    /// magnitude is what users react to — a 0 delta means the two
    /// agreed, which is itself information.
    private func deltaBadge(_ delta: Int) -> some View {
        let tint: Color = delta > 0 ? AppPalette.moss : (delta < 0 ? AppPalette.alert : AppPalette.inkSoft)
        let symbol = delta == 0 ? "=" : (delta > 0 ? "+\(delta)" : "\(delta)")
        return Text(symbol)
            .font(.caption.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint))
    }

    private func ratingBar(value: Int, total: Int, tint: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
                .lineLimit(1)
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i < value ? tint : AppPalette.sand)
                        .frame(height: 8)
                }
            }
        }
    }

    // MARK: - Takeaways

    private var takeawayPair: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("coach.takeaways"))
                .font(.headline)

            takeawayCard(title: lang.t("coach.you"),
                         body: local.takeaway.isEmpty ? "—" : local.takeaway,
                         accent: AppPalette.clay)
            takeawayCard(title: peerName,
                         body: peer.takeaway.isEmpty ? "—" : peer.takeaway,
                         accent: AppPalette.moss)
        }
    }

    private func takeawayCard(title: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(accent)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Save to journal

    private var saveButton: some View {
        Button {
            saveAsMatchEntry()
        } label: {
            Label(lang.t("coach.save_to_journal"), systemImage: "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
    }

    private var savedBadge: some View {
        Label(lang.t("coach.saved_confirmation"), systemImage: "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppPalette.moss)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    /// Persist the local player's submission as a fresh MatchEntry so
    /// it shows in the trend dashboard. The peer's ratings are quoted
    /// in the postMatchNotes ("Partner saw...") so the insight isn't
    /// lost when the ephemeral coach session ends.
    private func saveAsMatchEntry() {
        let entry = MatchEntry(
            opponentName: peerName,
            serveRating: local.serveRating,
            returnRating: local.returnRating,
            movementRating: local.movementRating,
            mentalRating: local.mentalRating,
            postMatchNotes: peerNotesQuote,
            takeaway: local.takeaway,
            isQuickLog: false
        )
        matches.save(entry)
        Haptics.celebrate()
        saved = true
    }

    /// Render the peer's ratings + takeaway as a chunk of text the
    /// user can scan in their journal later. We keep this template in
    /// the local language using `lang.t`.
    private var peerNotesQuote: String {
        let header = lang.t("coach.partner_saw_header")
        let body = String(
            format: lang.t("coach.partner_ratings_format"),
            peer.serveRating, peer.returnRating, peer.movementRating, peer.mentalRating
        )
        let takeaway = peer.takeaway.isEmpty ? "" : "\n\n\(peer.takeaway)"
        return "\(header)\n\(body)\(takeaway)"
    }
}
