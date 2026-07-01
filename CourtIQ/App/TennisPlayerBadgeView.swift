import SwiftUI

// MARK: - TennisPlayerBadgeView

/// Full badge: circular court illustration + player figure + progress ring + stars + IQ label.
struct TennisPlayerBadgeView: View {
    let level: TennisPlayerLevel
    let iqRating: Int
    var progressOverride: Double? = nil

    @EnvironmentObject private var lang: LanguageManager
    @State private var animatedProgress: Double = 0

    private var progress: Double { progressOverride ?? level.progress(for: iqRating) }

    var body: some View {
        VStack(spacing: 14) {
            badgeRing
            labelBlock
        }
    }

    // MARK: - Ring

    private var badgeRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(level.accent.opacity(0.14), lineWidth: 7)
                .frame(width: 134, height: 134)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    level.accent,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 134, height: 134)
                .rotationEffect(.degrees(-90))

            // Pro outer glow ring
            if level == .pro {
                Circle()
                    .stroke(level.accentSoft.opacity(0.45), lineWidth: 12)
                    .frame(width: 134, height: 134)
                    .blur(radius: 8)
            }

            // Badge disc
            Circle()
                .fill(level.backgroundGradient)
                .frame(width: 116, height: 116)
                .overlay(
                    Circle()
                        .strokeBorder(level.accent.opacity(0.20), lineWidth: 1)
                )

            // Court lines watermark
            TennisCourtLinesView()
                .foregroundStyle(level.accent)
                .opacity(0.13)
                .frame(width: 116, height: 116)
                .clipShape(Circle())

            // Player / ball figure
            Image(systemName: level.symbolName)
                .font(.system(size: level.figureSize, weight: .medium))
                .foregroundStyle(level.accent)
                .shadow(color: level.accent.opacity(0.25), radius: 6, x: 0, y: 2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) {
                animatedProgress = progress
            }
        }
        .onChange(of: iqRating) { _, _ in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
    }

    // MARK: - Labels

    private var labelBlock: some View {
        VStack(spacing: 5) {
            // Level title
            Text(level.localizedTitle(for: lang.language).uppercased())
                .appFont(12, weight: .bold)
                .tracking(1.4)
                .foregroundStyle(level.accent)

            // Stars
            if level.starCount > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<level.starCount, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .appFont(9, design: .default)
                            .foregroundStyle(level.accent)
                    }
                }
            }


        }
    }
}

// MARK: - TennisCourtLinesView

/// Minimal overhead court diagram used as a watermark inside the badge circle.
struct TennisCourtLinesView: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let style = StrokeStyle(lineWidth: 1.4, lineCap: .round)

            // Outer court rectangle
            var outer = Path()
            outer.addRect(CGRect(x: w * 0.10, y: h * 0.08,
                                 width: w * 0.80, height: h * 0.84))
            ctx.stroke(outer, with: .foreground, style: style)

            // Net (horizontal centre)
            stroke(ctx, from: CGPoint(x: w * 0.10, y: h * 0.50),
                       to: CGPoint(x: w * 0.90, y: h * 0.50), style: style)

            // Centre service line (vertical)
            stroke(ctx, from: CGPoint(x: w * 0.50, y: h * 0.08),
                       to: CGPoint(x: w * 0.50, y: h * 0.92), style: style)

            // Service lines (top and bottom halves)
            let svcT = h * 0.08 + (h * 0.42) * 0.56
            let svcB = h * 0.50 + (h * 0.42) * 0.44
            stroke(ctx, from: CGPoint(x: w * 0.10, y: svcT),
                       to: CGPoint(x: w * 0.90, y: svcT), style: style)
            stroke(ctx, from: CGPoint(x: w * 0.10, y: svcB),
                       to: CGPoint(x: w * 0.90, y: svcB), style: style)
        }
    }

    private func stroke(_ ctx: GraphicsContext,
                        from: CGPoint, to: CGPoint,
                        style: StrokeStyle) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .foreground, style: style)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 32) {
            ForEach(TennisPlayerLevel.allCases, id: \.rawValue) { level in
                let fakeIQ = level.lowerBound + (level == .pro ? 200 : (level.upperBound - level.lowerBound) / 2)
                TennisPlayerBadgeView(level: level, iqRating: fakeIQ)
            }
        }
        .padding()
    }
    .background(Color(white: 0.96))
}
