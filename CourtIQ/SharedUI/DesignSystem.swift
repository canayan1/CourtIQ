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
    /// Bouncy entrance with a touch of overshoot (tactile).
    static let entrance = Animation.spring(response: 0.55, dampingFraction: 0.62)
    /// Quick press scale (tactile feedback on tap).
    static let press = Animation.spring(response: 0.3, dampingFraction: 0.6)
    /// Snappy reveal for in-place state changes.
    static let reveal = Animation.snappy(duration: 0.4)
    /// Per-item delay step for a staggered entrance.
    static let stagger: Double = 0.07
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
        Image(name)
            .resizable()
            .scaledToFill()
            .clipped()
            .saturation(0)
            .colorMultiply(BrandedPhotoBackground.tone)
            .overlay(scrimOverlay)
            .clipped()
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
        static let bottomTop: Double = 0.10      // .bottom — light at the top
        static let bottomBottom: Double = 0.55   // .bottom — dark at the bottom
        static let full: Double = 0.40           // .full  — uniform veil
        static let heroTop: Double = 0.25        // .hero  — still readable up top
        static let heroBottom: Double = 0.70     // .hero  — strong base for big text
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
    }
}

// MARK: - Eyebrow

/// Tiny uppercase section label (e.g. "YOUR GAME").
struct Eyebrow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(AppPalette.inkSoft)
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
        // Fixed-height tile: clamp very large sizes so the icon + title don't
        // overflow the minHeight box. Scales up to accessibility2, then holds.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(locked ? .isButton : [])
    }
}
