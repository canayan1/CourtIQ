import SwiftUI

/// Labor-illusion screen: a short (~9s) sequence of NAMED steps that reflect the
/// user's real answers (their level, their top weakness, their daily
/// commitment), each filling a progress bar and then checking off. This is the
/// Cal AI / Noom "building your plan" beat — it must feel substantive, so every
/// step references a concrete answer rather than spinning hollowly. When the
/// last step completes it calls `onDone` to auto-advance to the result reveal.
struct OnboardingBuildingView: View {
    @EnvironmentObject private var lang: LanguageManager

    /// Human-readable step labels, already localized + interpolated with the
    /// user's answers by the flow controller.
    let stepLabels: [String]
    let onDone: () -> Void

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }

    /// Index of the step currently filling. Steps below it are done (checked).
    @State private var activeIndex = 0
    /// 0...1 fill of the active step.
    @State private var fill: CGFloat = 0
    @State private var started = false

    /// Seconds each step takes to fill. Total ≈ sum (clamped into the 8–12s band).
    private let perStep: Double = 2.2

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)

            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppPalette.clay)
                Text(copy.buildingTitle)
                    .font(.system(.title2, design: .rounded).weight(.bold))
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

    // MARK: Step row

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

    // MARK: Sequence driver

    private func runSequence() async {
        for index in stepLabels.indices {
            activeIndex = index
            fill = 0
            withAnimation(.easeInOut(duration: perStep)) { fill = 1 }
            try? await Task.sleep(nanoseconds: UInt64(perStep * 1_000_000_000))
        }
        // Mark the final step checked, hold a beat, then hand off.
        activeIndex = stepLabels.count
        try? await Task.sleep(nanoseconds: 500_000_000)
        onDone()
    }
}
