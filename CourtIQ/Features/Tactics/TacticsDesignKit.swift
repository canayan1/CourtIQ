import SwiftUI

/// Components the Tactics lessons use that DropVolley's design system did
/// not have. Copied from the TennisTactics app, which carried DropVolley's
/// palette and motion tokens to begin with — so these are the same studio,
/// not a second style. `Motion`, `Eyebrow`, `PressableCardStyle` and
/// `appFont` already exist here and are reused as-is.

extension AppPalette {
    /// Gold-to-clay wash behind the unlock nudges in the lessons.
    static let premiumGradient = LinearGradient(
        colors: [gold, clayBright, clay],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The court itself. Diagrams are the teaching surface of this app, so the
    /// court gets its own committed colors rather than borrowing card tints.
    enum Court {
        static let surface = Color(red: 197 / 255, green: 106 / 255, blue: 62 / 255)
        static let surfaceDeep = Color(red: 168 / 255, green: 86 / 255, blue: 47 / 255)
        static let line = Color(red: 252 / 255, green: 247 / 255, blue: 238 / 255)
        static let net = Color(red: 46 / 255, green: 52 / 255, blue: 62 / 255)
        // Zone + arrow semantics. These are chosen against the clay surface, not
        // against the app's parchment cards: a mid-tone red is nearly invisible
        // on clay, so "bad" is a much darker shade and "good" a much lighter one.
        // Contrast here comes from lightness difference, not hue.
        static let good = Color(red: 132 / 255, green: 194 / 255, blue: 122 / 255)
        static let bad = Color(red: 74 / 255, green: 26 / 255, blue: 22 / 255)
        static let focus = Color(red: 240 / 255, green: 180 / 255, blue: 40 / 255)
    }
}

// MARK: - Centred scroll

/// Centres its content on a normal screen, and lets it scroll once large text
/// makes the column taller than the screen.
///
/// A `Spacer`-centred column cannot grow: at accessibility text sizes SwiftUI
/// truncates its labels with ellipses instead. That is how the onboarding screen
/// came to read "Tennis Ta…" and "Start the…" at the largest text size.
struct CenteredScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var viewport: CGFloat = 0

    var body: some View {
        ScrollView {
            content()
                .frame(minHeight: viewport)
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewport = geo.size.height }
                    .onChange(of: geo.size.height) { _, height in viewport = height }
            }
        }
    }
}

// MARK: - Card surface

/// The one card recipe: parchment fill, sand hairline, 20pt continuous corners.
struct CardSurface: ViewModifier {
    var fill: Color = AppPalette.parchment
    var stroke: Color = AppPalette.sand
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func cardSurface(fill: Color = AppPalette.parchment,
                     stroke: Color = AppPalette.sand,
                     cornerRadius: CGFloat = 20) -> some View {
        modifier(CardSurface(fill: fill, stroke: stroke, cornerRadius: cornerRadius))
    }
}

// MARK: - Primary / secondary buttons

/// The single full-width call-to-action used by onboarding, lessons and paywall.
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = AppPalette.clay
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.confirm()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.headline)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    // Wrap rather than truncate: at accessibility text sizes a
                    // single-line CTA became "Start the…".
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(enabled ? tint : AppPalette.inkSoft.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!enabled)
    }
}

/// Low-emphasis text action ("Maybe later", "Restore purchases").
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(AppPalette.inkSoft)
        }
    }
}

// MARK: - Kinetic progress bar

/// A rounded XP/progress bar that fills on appear (kinetic). Respects Reduce
/// Motion by jumping straight to the final value.
struct KineticBar: View {
    /// 0…1.
    let value: Double
    var height: CGFloat = 10
    var tint: Color = AppPalette.clay
    var track: Color = AppPalette.sand

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, shown)) * geo.size.width)
            }
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { shown = value; return }
            withAnimation(Motion.entrance.delay(0.1)) { shown = value }
        }
        .onChange(of: value) { _, new in
            guard !reduceMotion else { shown = new; return }
            withAnimation(Motion.reveal) { shown = new }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Stat pill

/// Compact icon + value chip used in the home header (streak, XP, level).
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = AppPalette.clayText
    var background: Color = AppPalette.clayTint

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                // A pill must never wrap: squeezed into an HStack at accessibility
                // sizes, "4/30" broke into a vertical column of characters.
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
