import SwiftUI

/// "Today's Pro Shot" card surfaced on the Today tab. Tapping opens the
/// `ProShotAnimationView` full-screen for playback.
struct ProShotCard: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var manager: ProShotPatternsManager
    @State private var showAnimation = false

    var body: some View {
        let pattern = manager.todaysPattern
        return Group {
            if let pattern {
                Button { showAnimation = true } label: { cardBody(for: pattern) }
                    .buttonStyle(.plain)
                    .fullScreenCover(isPresented: $showAnimation) {
                        ProShotAnimationView(pattern: pattern)
                            .environmentObject(lang)
                    }
            } else {
                EmptyView()
            }
        }
    }

    private func cardBody(for pattern: ProShotPattern) -> some View {
        let viewed = manager.isViewed(pattern.id)
        return HStack(alignment: .top, spacing: 12) {
            // Mini court thumbnail with first shot marker
            ZStack {
                CourtTopDown(surface: thumbnailSurface(pattern: pattern), lineOpacity: 0.85)
                    .frame(width: 50, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                // YOU dot
                Circle()
                    .fill(AppPalette.clay)
                    .frame(width: 8, height: 8)
                    .position(x: pattern.initialYou.x * 50, y: pattern.initialYou.y * 76)
            }
            .frame(width: 50, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.gold)
                    Text(lang.t("pro_shot.card_kicker"))
                        .font(.caption.weight(.heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.gold)
                    Spacer()
                    if viewed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.moss)
                    }
                }

                Text(pattern.localizedTitle(for: lang.language))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)

                Text(pattern.localizedTagline(for: lang.language))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func thumbnailSurface(pattern: ProShotPattern) -> AppPalette.CourtSurface {
        switch pattern.surface {
        case "grass": return .grass
        case "hard":  return .hard
        case "night": return .night
        default:      return .clay
        }
    }
}
