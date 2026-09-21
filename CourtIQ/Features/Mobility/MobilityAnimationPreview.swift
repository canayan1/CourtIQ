import SwiftUI

// MARK: - Public surface
//
// `MobilityAnimationPreview` is a development gallery that shows the
// production-grade procedural athlete figure across a handful of named
// tennis mobility moves. The same `AthleteFigureCanvas` + `AthletePose`
// types are wired into `MobilityFlowDetailView` so the gallery and the
// production surface render from the same source of truth.
//
// Design goals (post-Begum pivot):
//   • Looks intentional, not "stick figure".
//   • Uses only AppPalette tokens — palette/dark-mode just work.
//   • Zero image assets, zero bundle weight, infinite scale.
//   • Animates between poses with eased interpolation and a subtle
//     breath-driven micro-motion so the figure feels alive even at rest.

struct MobilityAnimationPreview: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                kicker
                heroAnimation
                otherMovesStrip
                stylenote
            }
            .padding(22)
            .padding(.bottom, 40)
        }
        .background(AppPalette.cream)
        .navigationTitle("Procedural figure")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("World's Greatest Stretch", systemImage: "figure.flexibility")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.clay)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("A tennis warm-up classic — hip opener, hamstring, thoracic rotation.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    private var heroAnimation: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )

                // Soft court accent — matches the Home hero cards
                // pattern (CourtTopDown + opacity damper).
                CourtTopDown(surface: .clay, lineOpacity: 0.22)
                    .opacity(0.30)
                    .frame(width: 130, height: 200)
                    .offset(x: 95, y: 0)
                    .allowsHitTesting(false)

                AthleteFigureCanvas(
                    poseSequence: [.standing, .forwardFold, .lungeTwist],
                    loopDuration: 6.0
                )
                .frame(width: 280, height: 280)
            }
            .frame(height: 340)

            HStack(spacing: 8) {
                BreathDot()
                Text("Hold 3 breaths each side · 2 rounds")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
    }

    private var otherMovesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More moves — same style")
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    moveThumb(title: "Hamstring",  pose: .forwardFold)
                    moveThumb(title: "Hip opener", pose: .lungeTwist)
                    moveThumb(title: "Calf wall",  pose: .calfWall)
                    moveThumb(title: "T-spine",    pose: .tSpineWindmill)
                    moveThumb(title: "90/90 hip",  pose: .nineNinety)
                    moveThumb(title: "Standing",   pose: .standing)
                }
            }
        }
    }

    private func moveThumb(title: String, pose: AthletePose) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                AthleteFigureCanvas(staticPose: pose)
                    .frame(width: 120, height: 120)
            }
            .frame(width: 140, height: 150)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
        }
    }

    private var stylenote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Procedural rendering — production grade")
                .font(.headline)
            Text("Each limb is a filled tapered ribbon (Bezier-driven, thicker proximal to thinner distal). Body silhouette is one continuous closed Path. Pose data is normalized [0,1] so the same figure scales from 90 pt thumbnail to full-screen detail. Breath modulation pulses the torso ±2% on a 4-second sine. Floor shadow follows foot spread. All colors come from AppPalette tokens — change clay or ink and every figure restyles automatically.")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Athlete figure renderer

// NOTE: not compiled into the app. The production types this gallery uses
// (AthleteFigureCanvas, AthletePose, BreathDot, MotionHint) live in
// AthleteFigure.swift; this file is kept as a development reference and
// is not a member of any target. Add it back to CourtIQ's Sources to run it.

#Preview {
    NavigationStack {
        MobilityAnimationPreview()
            .environmentObject(LanguageManager.shared)
    }
}
