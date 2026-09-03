import SwiftUI

/// App-wide design-system tokens + components introduced with the action-first
/// Home redesign ("Home B"). These are intentionally generic so other tabs can
/// adopt the same motion language and tactile feel over time.
///
/// Motion philosophy = TACTILE + KINETIC:
///  - tactile  → springy press feedback + a bouncy, overshooting entrance.
///  - kinetic  → live value motion (a score ring that fills + a number that rolls).
/// Everything here honors Reduce Motion at the call site.

// MARK: - Motion tokens

enum Motion {
    /// Calm, settled entrance — slower glide, minimal overshoot. The app's
    /// pace is deliberate (court-story tempo), not snappy-dashboard tempo.
    static let entrance = Animation.spring(response: 0.8, dampingFraction: 0.8)
    /// Quick press scale (tactile feedback on tap) — feedback stays fast.
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.6)
    /// Smooth reveal for in-place state changes.
    static let reveal = Animation.smooth(duration: 0.55)
    /// Per-item delay step — each card visibly follows the previous one.
    static let stagger: Double = 0.12
}

// MARK: - Typography (Dynamic Type–aware)

/// Applies `.system(size:weight:design:)` but scaled with the user's Dynamic
/// Type setting via `@ScaledMetric`, instead of the fixed size that
/// `.font(.system(size:))` bakes in (which ignores accessibility text sizes).
///
/// The app's display identity is `design: .rounded`, so that is the default —
/// pass `design: .default` for body/system text and `.monospaced` for score
/// read-outs. `relativeTo` controls which text style the size scales against;
/// `.body` is a sensible default for everything.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// Dynamic-Type-scaled replacement for `.font(.system(size:weight:design:))`.
    /// Defaults to the app's rounded display face; the size still scales with
    /// the user's accessibility text-size setting.
    func appFont(_ size: CGFloat,
                 weight: Font.Weight = .regular,
                 design: Font.Design = .rounded,
                 relativeTo: Font.TextStyle = .body) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, relativeTo: relativeTo))
    }
}

// MARK: - Branded photo background (single-tone / duotone)

/// Turns any of the bundled tennis photos (`Image("Photo…")`) into a cohesive,
/// legible card background in ONE consistent treatment so all 14 disparate
/// shots read as one warm clay family ("tek ton, yedirilmiş"):
///
///  1. `Image(name).resizable().scaledToFill().clipped()` fills the card.
///  2. **Single-tone (duotone):** `.saturation(0)` strips color, then
///     `.colorMultiply(AppPalette.clay)` maps whites→clay and darks→deep clay.
///  3. **Legibility scrim:** an `AppPalette.ink` overlay (gradient or uniform)
///     so light foreground text/icons always clear ~4.5:1 contrast.
///
/// Cards using this MUST switch their foreground to LIGHT (white/cream) text +
/// icons. Static — no motion, so Reduce Motion is irrelevant here.
struct BrandedPhotoBackground: View {
    /// Where the darkening scrim concentrates, per surface type.
    enum Scrim {
        /// Bottom-weighted gradient — for cards with text pinned to the bottom.
        case bottom
        /// Uniform veil — for cards whose content sits anywhere/centered.
        case full
        /// Stronger bottom gradient — for big marquee heroes.
        case hero
    }

    let name: String
    var scrim: Scrim = .bottom

    var body: some View {
        // Color.clear takes exactly the host's proposed size; the photo is an
        // overlay clipped to those bounds. This prevents scaledToFill from
        // overflowing its card and overlapping neighbors (the layout bug).
        Color.clear
            .overlay(
                Image(name)
                    .resizable()
                    .scaledToFill()
                    // Cohesive but not muddy: keep some of the photo's life, warm
                    // it toward the brand clay, then scrim for text legibility.
                    .saturation(0.45)
                    .overlay(BrandedPhotoBackground.tone.opacity(0.42).blendMode(.multiply))
            )
            .overlay(scrimOverlay)
            .clipped()
            // .clipped() clips DRAWING only — the scaledToFill image still
            // hit-tests in its full, unclipped extent, silently stealing taps
            // from neighboring views (dead buttons/rows next to photo cards).
            // The background is purely decorative, so opt it out of hit
            // testing entirely.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var scrimOverlay: some View {
        switch scrim {
        case .bottom:
            LinearGradient(
                colors: [AppPalette.ink.opacity(Tuning.bottomTop),
                         AppPalette.ink.opacity(Tuning.bottomBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .full:
            AppPalette.ink.opacity(Tuning.full)
        case .hero:
            LinearGradient(
                colors: [AppPalette.ink.opacity(Tuning.heroTop),
                         AppPalette.ink.opacity(Tuning.heroBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: Tuning — the single calibration surface for the whole app

    /// The brand tone every photo is multiplied toward. Change this one value to
    /// re-key the entire photo system to a different brand color.
    static let tone: Color = AppPalette.clay

    /// All scrim opacities grouped so the parent can dial legibility app-wide
    /// from one place. Higher = darker = more legible (but flatter) photo.
    enum Tuning {
        static let bottomTop: Double = 0.12      // .bottom — light at the top
        static let bottomBottom: Double = 0.64   // .bottom — dark at the bottom
        static let full: Double = 0.42           // .full  — uniform veil
        static let heroTop: Double = 0.28        // .hero  — still readable up top
        static let heroBottom: Double = 0.74     // .hero  — strong base for big text
    }
}

extension View {
    /// Places a `BrandedPhotoBackground` behind the view, clipped to the given
    /// rounded shape, and stamps it as the view's `.background`. The caller is
    /// responsible for switching its own foreground to LIGHT (white/cream).
    ///
    /// Keeps a surface's existing corner radius + clipping by re-clipping the
    /// composited result to the same `RoundedRectangle`.
    func brandedPhoto(
        _ name: String,
        scrim: BrandedPhotoBackground.Scrim = .bottom,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.background(
            BrandedPhotoBackground(name: name, scrim: scrim)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
    }
}

// MARK: - Pressable card style

/// Scales a tappable card/tile down to 0.95 while pressed, with a spring.
/// Use for every tappable card/tile so the whole app shares one tactile feel.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            // One place to give EVERY tappable card/tile a light tactile tick on
            // press-down — app-wide immediate feedback, not just a visual scale.
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

// MARK: - Eyebrow

/// Tiny uppercase section label (e.g. "YOUR GAME").
struct Eyebrow: View {
    let text: String
    /// Defaults to the quiet ink; the Tactics lessons set it on colored cards.
    var tint: Color = AppPalette.inkSoft

    init(_ text: String, tint: Color = AppPalette.inkSoft) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(tint)
    }
}

// MARK: - Score ring (kinetic)

/// A circular 0–100 ring with a rolling center number. On appear the ring
/// fills 0→score/100 and the number rolls 0→score (kinetic motion). When
/// Reduce Motion is on, it shows the final value instantly with no animation.
struct ScoreRing: View {
    let size: CGFloat
    let score: Int
    var accent: Color = AppPalette.clay
    /// Track color behind the progress arc.
    var track: Color = AppPalette.sand.opacity(0.5)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Int = 0

    private var progress: Double { Double(displayed) / 100.0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: size * 0.11)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(displayed)")
                .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { displayed = score; return }
            withAnimation(Motion.entrance) {
                displayed = score
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score)")
    }
}

// MARK: - Shared tile background

/// The shared background recipe for `FeatureTile` / `LockableTile`. When
/// `photo` is nil it keeps the original parchment fill + sand stroke; when set
/// it swaps in a duotone `BrandedPhotoBackground` (`.bottom` scrim) so the same
/// tile becomes a photo card with a single line of code. Either way the corner
/// radius + clipping match the originals (20pt continuous).
private struct TileBackground: ViewModifier {
    let photo: String?

    func body(content: Content) -> some View {
        if let photo {
            content
                .brandedPhoto(photo, scrim: .bottom, cornerRadius: 20)
        } else {
            content
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Feature tile

/// A square-ish tappable card with a hierarchical SF Symbol + a one-word title.
/// On tap the icon fires a `.bounce` symbol effect (tactile micro-feedback)
/// before running `action`.
struct FeatureTile: View {
    let sfSymbol: String
    let title: String
    var accent: Color = AppPalette.clay
    var minHeight: CGFloat = 96
    /// When set, the tile renders a `BrandedPhotoBackground` (duotone photo +
    /// `.bottom` scrim) with a LIGHT foreground. When nil, the original
    /// parchment look is preserved.
    var photo: String? = nil
    let action: () -> Void

    @State private var bounce = 0

    /// Photo tiles flip icon + label to white over the scrim for legibility.
    private var foreground: Color { photo == nil ? AppPalette.ink : .white }
    private var iconAccent: Color { photo == nil ? accent : .white }

    var body: some View {
        Button {
            bounce += 1
            action()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: sfSymbol)
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconAccent)
                    .symbolEffect(.bounce, value: bounce)

                Spacer(minLength: 0)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(16)
            .modifier(TileBackground(photo: photo))
            // The background photo/parchment is a `.background`, so on its own
            // only the icon+title area is tappable. Make the whole tile the hit
            // target so any point on the card triggers it.
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        // Fixed-height tile: clamp very large sizes so the icon + title don't
        // overflow the minHeight box. Scales up to accessibility2, then holds.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityLabel(title)
    }
}

// MARK: - Lockable tile

/// The single, shared square-ish category/quiz tile used across the app
/// (Train hub category cards + Practice quiz tiles). It is a *label-only*
/// view — wrap it in a `NavigationLink` or `Button` and apply
/// `PressableCardStyle()` at the call site, exactly like the old hand-rolled
/// `CategoryCard` / `quizTile` recipes it replaces.
///
/// Visuals are identical to those recipes: a hierarchical SF Symbol, an
/// optional top-right lock glyph, and a one/two-word title pinned to the
/// bottom. `minHeight` lets the Train hub (112) and Practice (96) keep their
/// existing proportions.
struct LockableTile: View {
    let sfSymbol: String
    let title: String
    var locked: Bool = false
    var accent: Color = AppPalette.clay
    var minHeight: CGFloat = 96
    /// When set, the tile renders a `BrandedPhotoBackground` (duotone photo +
    /// `.bottom` scrim) with a LIGHT foreground. When nil, the original
    /// parchment look is preserved.
    var photo: String? = nil

    /// Photo tiles flip icon + label to white over the scrim for legibility.
    private var foreground: Color { photo == nil ? AppPalette.ink : .white }
    private var iconAccent: Color { photo == nil ? accent : .white }
    private var lockTint: Color { photo == nil ? AppPalette.inkSoft : .white.opacity(0.9) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sfSymbol)
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconAccent)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(lockTint)
                }
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(foreground)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .padding(16)
        .modifier(TileBackground(photo: photo))
        // The photo/parchment is a `.background`, so on its own only the
        // icon+title area is hit-testable — make the whole card tappable for
        // the wrapping Button/NavigationLink (same fix as FeatureTile).
        .contentShape(Rectangle())
        // Fixed-height tile: clamp very large sizes so the icon + title don't
        // overflow the minHeight box. Scales up to accessibility2, then holds.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(locked ? .isButton : [])
    }
}

// MARK: - Court palette + lesson components (arrived with the Tactics tab)


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
