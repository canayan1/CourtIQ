import SwiftUI

/// Labor-illusion loading screen for match analysis — the same stepped,
/// named-progress beat as `OnboardingBuildingView`, retuned so the full
/// sequence runs ~12s (the minimum we hold the analysis on screen so it
/// always feels like real work). Purely visual: the AI call runs
/// concurrently in the parent; this view just animates and never blocks.
struct MatchAnalyzingView: View {
    @EnvironmentObject private var lang: LanguageManager

    let title: String
    let stepLabels: [String]

    @State private var activeIndex = 0
    @State private var fill: CGFloat = 0
    @State private var started = false

    /// Seconds each step takes to fill. With ~5-6 steps this lands the
    /// sequence comfortably in the 12s minimum-display window.
    private let perStep: Double = 2.2

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)

            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppPalette.clay)
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
            }

            VStack(spacing: 14) {
                ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, label in
                    stepRow(index: index, label: label)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppPalette.cream)
        .task {
            guard !started else { return }
            started = true
            await runSequence()
        }
    }

    @ViewBuilder
    private func stepRow(index: Int, label: String) -> some View {
        let isDone = index < activeIndex
        let isActive = index == activeIndex

        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppPalette.moss)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(AppPalette.clay)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppPalette.sand)
                }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.subheadline.weight(isActive || isDone ? .semibold : .regular))
                    .foregroundStyle(isActive || isDone ? AppPalette.ink : AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppPalette.sand.opacity(0.6))
                        Capsule()
                            .fill(isDone ? AppPalette.moss : AppPalette.clay)
                            .frame(width: geo.size.width * (isDone ? 1 : (isActive ? fill : 0)))
                    }
                }
                .frame(height: 5)
            }
            Spacer(minLength: 0)
        }
    }

    /// Loops the steps once. When the last step would complete it instead
    /// loops the final step's fill so the animation keeps breathing if the
    /// network call outruns the 12s window — the parent decides when to
    /// reveal the report.
    private func runSequence() async {
        for index in stepLabels.indices {
            activeIndex = index
            fill = 0
            withAnimation(.easeInOut(duration: perStep)) { fill = 1 }
            try? await Task.sleep(nanoseconds: UInt64(perStep * 1_000_000_000))
        }
        // Hold the final step "active" (spinner) rather than checking it
        // off — the parent transitions away once both the min-display and
        // the network call have resolved.
        activeIndex = max(stepLabels.count - 1, 0)
        withAnimation(.easeInOut(duration: 0.6)) { fill = 1 }
    }
}
