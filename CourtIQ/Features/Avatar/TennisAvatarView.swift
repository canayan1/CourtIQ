import SwiftUI

/// Procedural avatar — no image assets. Every visual is composed of
/// SwiftUI Shape primitives (Circle, Capsule, RoundedRectangle, Path).
///
/// Style: flat geometric, Bitmoji-adjacent, tennis-themed. Palette
/// driven by the user's `AvatarConfig`.
struct TennisAvatarView: View {
    let config: AvatarConfig
    /// When true, draws the configured court background behind the avatar.
    /// When false, renders the avatar with a transparent background
    /// (useful for inline thumbnails in lists).
    var showCourtBackground: Bool = true
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            if showCourtBackground {
                courtBackground
            }
            avatarBody
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
    }

    // MARK: - Court background

    @ViewBuilder
    private var courtBackground: some View {
        switch config.courtSurface {
        case .sunsetCourt:
            LinearGradient(
                colors: [
                    AppPalette.clay,
                    AppPalette.clayBright,
                    AppPalette.gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [
                    config.courtSurface.surface.sky,
                    config.courtSurface.surface.base,
                    config.courtSurface.surface.dark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Avatar body

    private var avatarBody: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let unit = min(w, h) / 220

            ZStack {
                // Shadow under feet
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 76 * unit, height: 10 * unit)
                    .position(x: w * 0.5, y: h * 0.93)

                // Legs
                legs(unit: unit, in: geo.size)

                // Body
                bodyShape(unit: unit, in: geo.size)

                // Arms (stance-dependent)
                arms(unit: unit, in: geo.size)

                // Head
                head(unit: unit, in: geo.size)

                // Racket (held in dominant hand)
                racketGroup(unit: unit, in: geo.size)
            }
        }
    }

    // MARK: - Component shapes

    private func head(unit: CGFloat, in s: CGSize) -> some View {
        let skinColor = Color(red: 0.95, green: 0.80, blue: 0.66)
        let hairColor = Color(red: 0.18, green: 0.14, blue: 0.10)
        return ZStack {
            // Hair back
            Circle()
                .fill(hairColor)
                .frame(width: 70 * unit, height: 70 * unit)
                .position(x: s.width * 0.5, y: s.height * 0.27)
            // Skin
            Circle()
                .fill(skinColor)
                .frame(width: 60 * unit, height: 60 * unit)
                .position(x: s.width * 0.5, y: s.height * 0.30)
            // Hair forward (cap stripe)
            Capsule()
                .fill(hairColor)
                .frame(width: 60 * unit, height: 12 * unit)
                .position(x: s.width * 0.5, y: s.height * 0.255)

            // Eyes
            HStack(spacing: 10 * unit) {
                eyeShape(unit: unit)
                eyeShape(unit: unit)
            }
            .position(x: s.width * 0.5, y: s.height * 0.30)

            // Accent overlay (headband / cap)
            accentLayer(unit: unit, in: s)
        }
    }

    private func eyeShape(unit: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.12, green: 0.10, blue: 0.10))
            .frame(width: 5 * unit, height: 5 * unit)
    }

    @ViewBuilder
    private func accentLayer(unit: CGFloat, in s: CGSize) -> some View {
        switch config.accent {
        case .none:
            EmptyView()
        case .headband:
            Capsule()
                .fill(config.outfit.shortColor)
                .frame(width: 64 * unit, height: 10 * unit)
                .overlay(
                    Capsule()
                        .stroke(config.outfit.jerseyColor.opacity(0.7), lineWidth: 1)
                )
                .position(x: s.width * 0.5, y: s.height * 0.24)
        case .wristbands:
            // Drawn in the arms layer; render headband-area as empty.
            EmptyView()
        case .capForward:
            // Simple cap = arc + brim
            ZStack {
                Path { p in
                    p.addArc(
                        center: CGPoint(x: s.width * 0.5, y: s.height * 0.27),
                        radius: 36 * unit,
                        startAngle: .degrees(200),
                        endAngle: .degrees(340),
                        clockwise: false
                    )
                    p.closeSubpath()
                }
                .fill(config.outfit.jerseyColor)

                // Brim
                Ellipse()
                    .fill(config.outfit.jerseyColor)
                    .frame(width: 70 * unit, height: 8 * unit)
                    .position(x: s.width * 0.5, y: s.height * 0.255)
            }
        }
    }

    private func bodyShape(unit: CGFloat, in s: CGSize) -> some View {
        // Torso = rounded trapezoid built from a Path so we get the
        // "athletic V" silhouette that signals tennis.
        let centerX = s.width * 0.5
        return Path { p in
            let topY = s.height * 0.40
            let bottomY = s.height * 0.66
            let topHalf = 32 * unit
            let bottomHalf = 26 * unit
            let radius = 8 * unit
            p.move(to: CGPoint(x: centerX - topHalf, y: topY + radius))
            p.addQuadCurve(
                to: CGPoint(x: centerX - topHalf + radius, y: topY),
                control: CGPoint(x: centerX - topHalf, y: topY)
            )
            p.addLine(to: CGPoint(x: centerX + topHalf - radius, y: topY))
            p.addQuadCurve(
                to: CGPoint(x: centerX + topHalf, y: topY + radius),
                control: CGPoint(x: centerX + topHalf, y: topY)
            )
            p.addLine(to: CGPoint(x: centerX + bottomHalf, y: bottomY))
            p.addLine(to: CGPoint(x: centerX - bottomHalf, y: bottomY))
            p.closeSubpath()
        }
        .fill(config.outfit.jerseyColor)
        .overlay(
            // Subtle inner outline
            Path { p in
                p.move(to: CGPoint(x: centerX, y: s.height * 0.42))
                p.addLine(to: CGPoint(x: centerX, y: s.height * 0.55))
            }
            .stroke(config.outfit.jerseyColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func legs(unit: CGFloat, in s: CGSize) -> some View {
        let centerX = s.width * 0.5
        return ZStack {
            // Shorts band
            RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
                .fill(config.outfit.shortColor)
                .frame(width: 56 * unit, height: 28 * unit)
                .position(x: centerX, y: s.height * 0.72)

            // Legs (skin tone)
            HStack(spacing: 6 * unit) {
                Capsule()
                    .fill(Color(red: 0.95, green: 0.80, blue: 0.66))
                    .frame(width: 16 * unit, height: 36 * unit)
                Capsule()
                    .fill(Color(red: 0.95, green: 0.80, blue: 0.66))
                    .frame(width: 16 * unit, height: 36 * unit)
            }
            .position(x: centerX, y: s.height * 0.82)

            // Shoes
            HStack(spacing: 6 * unit) {
                RoundedRectangle(cornerRadius: 4 * unit, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 22 * unit, height: 10 * unit)
                RoundedRectangle(cornerRadius: 4 * unit, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 22 * unit, height: 10 * unit)
            }
            .position(x: centerX, y: s.height * 0.895)
        }
    }

    private func arms(unit: CGFloat, in s: CGSize) -> some View {
        let centerX = s.width * 0.5
        let skinColor = Color(red: 0.95, green: 0.80, blue: 0.66)

        // Stance affects arm angles.
        let leftAngle: Double
        let rightAngle: Double
        switch config.stance {
        case .ready:
            leftAngle = -18
            rightAngle = 28
        case .proPose:
            leftAngle = -32
            rightAngle = 70
        }

        return ZStack {
            // Left arm (avatar's left = screen right)
            armCapsule(skinColor: skinColor, unit: unit)
                .rotationEffect(.degrees(rightAngle), anchor: .top)
                .position(x: centerX + 30 * unit, y: s.height * 0.46)
                .overlay(
                    wristbandOverlay(unit: unit)
                        .rotationEffect(.degrees(rightAngle), anchor: .top)
                        .position(x: centerX + 38 * unit, y: s.height * 0.60),
                    alignment: .top
                )

            // Right arm (holding racket — drawn behind racket)
            armCapsule(skinColor: skinColor, unit: unit)
                .rotationEffect(.degrees(leftAngle), anchor: .top)
                .position(x: centerX - 30 * unit, y: s.height * 0.46)
        }
    }

    private func armCapsule(skinColor: Color, unit: CGFloat) -> some View {
        ZStack {
            // Sleeve
            Capsule()
                .fill(config.outfit.jerseyColor)
                .frame(width: 14 * unit, height: 22 * unit)
                .offset(y: 10 * unit)
            // Forearm + hand
            Capsule()
                .fill(skinColor)
                .frame(width: 12 * unit, height: 34 * unit)
                .offset(y: 30 * unit)
        }
    }

    @ViewBuilder
    private func wristbandOverlay(unit: CGFloat) -> some View {
        if config.accent == .wristbands {
            Capsule()
                .fill(config.outfit.shortColor)
                .frame(width: 16 * unit, height: 5 * unit)
        }
    }

    // MARK: - Racket

    private func racketGroup(unit: CGFloat, in s: CGSize) -> some View {
        let centerX = s.width * 0.5
        let racketY = s.height * 0.58

        // Held in left hand (avatar's right) — angle racket up-and-out
        let angle: Double = config.stance == .proPose ? -45 : -18

        return ZStack {
            // Strings + head
            ZStack {
                Ellipse()
                    .fill(config.racket.headColor)
                    .frame(width: 38 * unit, height: 50 * unit)
                Ellipse()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 32 * unit, height: 44 * unit)

                // String grid hint
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 24 * unit, height: 0.6)
                        .offset(y: CGFloat(i - 1) * 6 * unit)
                }
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 0.6, height: 32 * unit)
                        .offset(x: CGFloat(i - 1) * 6 * unit)
                }
            }
            .offset(y: -22 * unit)

            // Throat + grip
            Rectangle()
                .fill(config.racket.headColor)
                .frame(width: 5 * unit, height: 26 * unit)

            // Grip wrap
            Rectangle()
                .fill(config.racket.accentColor)
                .frame(width: 8 * unit, height: 18 * unit)
                .offset(y: 22 * unit)
        }
        .rotationEffect(.degrees(angle))
        .position(x: centerX - 50 * unit, y: racketY)
    }
}
