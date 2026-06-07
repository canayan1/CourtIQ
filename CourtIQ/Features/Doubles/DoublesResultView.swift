import SwiftUI

/// Shows the compatibility result for a partnership: score, per-dimension
/// breakdown, team setup, strengths/watch-outs, a static practice plan
/// (free), and a premium AI game-plan teaser (wired in Step 6).
struct DoublesResultView: View {
    let partnership: DoublesPartnership
    @EnvironmentObject private var lang: LanguageManager

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var result: DoublesResult { partnership.result }

    private func name(_ slot: PlayerSlot) -> String {
        slot == .a ? copy.youShort : partnership.partnerName
    }
    private func ratingColor(_ r: DimensionRating) -> Color {
        switch r {
        case .green:  return AppPalette.moss
        case .yellow: return AppPalette.gold
        case .red:    return AppPalette.clay
        }
    }
    private var bandColor: Color {
        switch result.band {
        case .strong:    return AppPalette.moss
        case .workable:  return AppPalette.gold
        case .needsPlan: return AppPalette.clay
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreCard
                teamSetupCard
                breakdownCard
                if !result.strengthKeys.isEmpty || !result.watchOutKeys.isEmpty {
                    strengthsWatchOutsCard
                }
                prepCard
                aiTeaserCard
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("\(copy.youShort) & \(partnership.partnerName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Score
    private var scoreCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(AppPalette.sand, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(result.score) / 100.0)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(result.score)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text("/100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            .frame(width: 140, height: 140)
            .padding(.top, 8)

            Text(copy.band(result.band))
                .font(.title3.bold())
                .foregroundStyle(bandColor)
            Text(copy.bandBlurb(result.band))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Team setup
    private var teamSetupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.teamSetupHeader).font(.headline).foregroundStyle(AppPalette.ink)
            row("sportscourt.fill", copy.serveFirst(name(result.serveFirst)))
            row("arrow.left.arrow.right", copy.returnSides(deuce: name(result.deuceReturner), ad: name(result.adReturner)))
            row("figure.tennis", copy.formation(result.startingFormation))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Breakdown
    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(result.dimensions, id: \.dimension) { d in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(ratingColor(d.rating)).frame(width: 10, height: 10).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.dimTitle(d.dimension))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                        Text(copy.dimNote(d.dimension, d.rating))
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Strengths / watch-outs
    private var strengthsWatchOutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.strengthKeys.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(copy.strengthsHeader, systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold()).foregroundStyle(AppPalette.moss)
                    ForEach(result.strengthKeys, id: \.self) { d in
                        Text("• \(copy.dimTitle(d))").font(.subheadline).foregroundStyle(AppPalette.ink)
                    }
                }
            }
            if !result.watchOutKeys.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(copy.watchOutsHeader, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold()).foregroundStyle(AppPalette.clay)
                    ForEach(result.watchOutKeys, id: \.self) { d in
                        Text("• \(copy.dimTitle(d))").font(.subheadline).foregroundStyle(AppPalette.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Prep sheet (free) — tips for the watch-out dimensions
    private var prepCard: some View {
        let tips = result.watchOutKeys.isEmpty
            ? Array(result.dimensions.sorted { $0.sub < $1.sub }.prefix(2).map { $0.dimension })
            : result.watchOutKeys
        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.prepHeader).font(.headline).foregroundStyle(AppPalette.ink)
            ForEach(tips, id: \.self) { d in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "figure.tennis")
                        .font(.caption.weight(.bold)).foregroundStyle(AppPalette.moss).frame(width: 20)
                    Text(copy.prepTip(d)).font(.subheadline).foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: AI plan teaser (premium; full feature later)
    private var aiTeaserCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(AppPalette.clay)
                Text(copy.aiPlanTitle).font(.headline).foregroundStyle(AppPalette.ink)
                Spacer()
                Text(copy.aiPlanComingSoon)
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AppPalette.gold.opacity(0.18))
                    .foregroundStyle(AppPalette.gold)
                    .clipShape(Capsule())
            }
            Text(copy.aiPlanBody).font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
