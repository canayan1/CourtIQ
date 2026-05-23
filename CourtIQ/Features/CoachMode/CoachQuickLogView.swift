import SwiftUI

/// In-match rating capture for Coach Mode. Same four 1-5 ratings as the
/// solo `QuickLogView` plus a one-sentence takeaway — but here the
/// values you enter are about the *opponent* and they're entering theirs
/// about you. After both sides submit, `CoachReveal` shows the comparison.
struct CoachQuickLogView: View {
    @ObservedObject var session: CoachSession
    @EnvironmentObject private var lang: LanguageManager

    @State private var serve = 3
    @State private var ret = 3
    @State private var movement = 3
    @State private var mental = 3
    @State private var takeaway = ""

    var body: some View {
        Group {
            if session.state == .bothSubmitted,
               let local = session.localSubmission,
               let peer = session.peerSubmission {
                CoachReveal(local: local, peer: peer,
                            peerName: session.peerDisplayName ?? lang.t("coach.partner"))
            } else {
                captureView
            }
        }
    }

    private var captureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                ratingRow(kind: .serve, label: lang.t("coach.rate_serve_of_partner"), value: $serve)
                ratingRow(kind: .backhand, label: lang.t("coach.rate_return_of_partner"), value: $ret)
                ratingRow(kind: .mobility, label: lang.t("coach.rate_movement_of_partner"), value: $movement)
                ratingRow(kind: .target, label: lang.t("coach.rate_mental_of_partner"), value: $mental)

                TextField(
                    lang.t("coach.takeaway_placeholder"),
                    text: $takeaway,
                    axis: .vertical
                )
                .lineLimit(2, reservesSpace: true)
                .padding(14)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                submitButton

                if session.state == .submittedLocally {
                    waitingForPeer
                }
            }
            .padding(22)
        }
        .background(AppPalette.cream)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(session.peerDisplayName ?? lang.t("coach.partner"),
                  systemImage: "person.2.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)

            Text(lang.t("coach.rate_them_headline"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ratingRow(kind: TennisGlyphKind, label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TennisGlyph(kind: kind, color: AppPalette.clay, size: 22)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        Haptics.tap()
                        value.wrappedValue = i
                    } label: {
                        Circle()
                            .fill(i <= value.wrappedValue ? AppPalette.clay : AppPalette.sand)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(i) of 5")
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            Haptics.confirm()
            session.submit(.init(
                serveRating: serve,
                returnRating: ret,
                movementRating: movement,
                mentalRating: mental,
                takeaway: takeaway.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        } label: {
            Text(lang.t("coach.submit"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
        .disabled(session.state == .submittedLocally || session.state == .bothSubmitted)
    }

    private var waitingForPeer: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(lang.t("coach.waiting_for_partner_submit"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.top, 6)
    }
}
