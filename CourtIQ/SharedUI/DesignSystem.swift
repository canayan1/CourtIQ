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
            .font(.system(size: 11, weight: .semibold, design: .rounded))
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

// MARK: - Feature tile

/// A square-ish tappable card with a hierarchical SF Symbol + a one-word title.
/// On tap the icon fires a `.bounce` symbol effect (tactile micro-feedback)
/// before running `action`.
struct FeatureTile: View {
    let sfSymbol: String
    let title: String
    var accent: Color = AppPalette.clay
    var minHeight: CGFloat = 96
    let action: () -> Void

    @State private var bounce = 0

    var body: some View {
        Button {
            bounce += 1
            action()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                    .symbolEffect(.bounce, value: bounce)

                Spacer(minLength: 0)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sfSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(locked ? .isButton : [])
    }
}
