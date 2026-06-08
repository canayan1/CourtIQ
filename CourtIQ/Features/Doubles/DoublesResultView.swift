import SwiftUI

/// Transparent compatibility result: overall + two axis sub-scores
/// (tactical / chemistry), a per-dimension breakdown that shows BOTH
/// players' answers and the rating, team setup with reasons, strengths /
/// watch-outs, a static practice plan, and a premium AI-plan teaser.
struct DoublesResultView: View {
    let partnership: DoublesPartnership
    @EnvironmentObject private var lang: LanguageManager

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var result: DoublesResult { partnership.result }
    private var me: DoublesProfile { partnership.myProfile }
    private var pp: DoublesProfile { partnership.partnerProfile }
    private var partnerName: String { partnership.partnerName }

    private func name(_ slot: PlayerSlot) -> String { slot == .a ? copy.youShort : partnerName }
    private func profile(_ slot: PlayerSlot) -> DoublesProfile { slot == .a ? me : pp }
    private func ratingColor(_ r: DimensionRating) -> Color {
        switch r { case .green: return AppPalette.moss; case .yellow: return AppPalette.gold; case .red: return AppPalette.clay }
    }
    private var bandColor: Color {
        switch result.band { case .strong: return AppPalette.moss; case .workable: return AppPalette.gold; case .needsPlan: return AppPalette.clay }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreCard
                teamSetupCard
                breakdownCard(.tactical, title: copy.tacticalScoreLabel, score: result.tacticalScore)
                breakdownCard(.chemistry, title: copy.chemistryScoreLabel, score: result.chemistryScore)
                if !result.strengthKeys.isEmpty || !result.watchOutKeys.isEmpty { strengthsWatchOutsCard }
                prepCard
                aiTeaserCard
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("\(copy.youShort) & \(partnerName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Score (overall + two axes)
    private var scoreCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppPalette.sand, lineWidth: 12)
                Circle().trim(from: 0, to: CGFloat(result.score) / 100.0)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(result.score)").font(.system(size: 42, weight: .black, design: .rounded)).foregroundStyle(AppPalette.ink)
                    Text(copy.overallLabel).font(.caption2.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                }
            }
            .frame(width: 132, height: 132).padding(.top, 6)

            Text(copy.band(result.band)).font(.title3.bold()).foregroundStyle(bandColor)
            Text(copy.bandBlurb(result.band))
                .font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                axisBar(copy.tacticalScoreLabel, result.tacticalScore)
                axisBar(copy.chemistryScoreLabel, result.chemistryScore)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func axisBar(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(AppPalette.ink)
                Spacer()
                Text("\(value)").font(.caption.weight(.bold)).foregroundStyle(AppPalette.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppPalette.sand).frame(height: 8)
                    Capsule().fill(value >= 80 ? AppPalette.moss : (value >= 60 ? AppPalette.gold : AppPalette.clay))
                        .frame(width: max(8, geo.size.width * CGFloat(value) / 100.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: Team setup (with reasons)
    private var teamSetupCard: some View {
        let serverServe = profile(result.serveFirst).serveStrength
        let otherServe = profile(result.serveFirst == .a ? .b : .a).serveStrength
        let clash = me.preferredSide == pp.preferredSide && me.preferredSide != .either
        return VStack(alignment: .leading, spacing: 12) {
            Text(copy.teamSetupHeader).font(.headline).foregroundStyle(AppPalette.ink)
            setupRow("sportscourt.fill", copy.serveFirstLine(server: name(result.serveFirst), serverServe: serverServe, other: otherServe))
            setupRow("arrow.left.arrow.right", copy.returnLine(deuce: name(result.deuceReturner), ad: name(result.adReturner), clash: clash))
            setupRow("figure.tennis", copy.formationLine(result.startingFormation))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func setupRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.clay).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Per-axis breakdown (shows BOTH answers + rating + note)
    private func breakdownCard(_ axis: DoublesAxis, title: String, score: Int) -> some View {
        let dims = result.dimensions.filter { $0.dimension.axis == axis }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline).foregroundStyle(AppPalette.ink)
                Spacer()
                Text("\(score)/100").font(.subheadline.weight(.bold)).foregroundStyle(AppPalette.inkSoft)
            }
            ForEach(dims, id: \.dimension) { d in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(ratingColor(d.rating)).frame(width: 10, height: 10).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.dimTitle(d.dimension)).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                        Text("\(copy.youShort): \(copy.answer(d.dimension, me))  ·  \(partnerName): \(copy.answer(d.dimension, pp))")
                            .font(.caption).foregroundStyle(AppPalette.inkSoft)
                        Text(copy.dimNote(d.dimension, d.rating))
                            .font(.caption).foregroundStyle(ratingColor(d.rating))
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
                    Label(copy.strengthsHeader, systemImage: "checkmark.seal.fill").font(.subheadline.bold()).foregroundStyle(AppPalette.moss)
                    ForEach(result.strengthKeys, id: \.self) { d in
                        Text("• \(copy.dimTitle(d))").font(.subheadline).foregroundStyle(AppPalette.ink)
                    }
                }
            }
            if !result.watchOutKeys.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(copy.watchOutsHeader, systemImage: "exclamationmark.triangle.fill").font(.subheadline.bold()).foregroundStyle(AppPalette.clay)
                    ForEach(result.watchOutKeys, id: \.self) { d in
                        Text("• \(copy.dimTitle(d))").font(.subheadline).foregroundStyle(AppPalette.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Prep sheet
    private var prepCard: some View {
        let tips = result.watchOutKeys.isEmpty
            ? Array(result.dimensions.sorted { $0.sub < $1.sub }.prefix(2).map { $0.dimension })
            : result.watchOutKeys
        return VStack(alignment: .leading, spacing: 10) {
            Text(copy.prepHeader).font(.headline).foregroundStyle(AppPalette.ink)
            ForEach(tips, id: \.self) { d in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "figure.tennis").font(.caption.weight(.bold)).foregroundStyle(AppPalette.moss).frame(width: 20)
                    Text(copy.prepTip(d)).font(.subheadline).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: AI teaser
    private var aiTeaserCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(AppPalette.clay)
                Text(copy.aiPlanTitle).font(.headline).foregroundStyle(AppPalette.ink)
                Spacer()
                Text(copy.aiPlanComingSoon)
                    .font(.caption2.weight(.heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AppPalette.gold.opacity(0.18)).foregroundStyle(AppPalette.gold).clipShape(Capsule())
            }
            Text(copy.aiPlanBody).font(.subheadline).foregroundStyle(AppPalette.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
