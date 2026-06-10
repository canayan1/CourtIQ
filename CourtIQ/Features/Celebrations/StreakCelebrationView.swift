import SwiftUI

struct StreakCelebrationView: View {
    let streakDays: Int
    let onDismiss: () -> Void

    @State private var numberScale: CGFloat = 0.4
    @State private var numberOpacity: Double = 0
    @State private var badgeOffset: CGFloat = 40
    @State private var badgeOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            AppPalette.heroGradient
                .ignoresSafeArea()

            // Subtle court-line watermark
            courtLines
                .opacity(0.08)

            VStack(spacing: 0) {
                Spacer()

                // Streak number
                Text("\(streakDays)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(numberScale)
                    .opacity(numberOpacity)

                // "DAY STREAK" gold badge
                Text("DAY STREAK")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.25))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.98, green: 0.82, blue: 0.25).opacity(0.18))
                    .clipShape(Capsule())
                    .offset(y: badgeOffset)
                    .opacity(badgeOpacity)

                Spacer().frame(height: 48)

                // Stat improvement
                VStack(spacing: 6) {
                    Text(motivationLine)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .offset(y: badgeOffset)
                .opacity(badgeOpacity)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        shareStreak()
                    } label: {
                        Label("Share your streak", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Keep going")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white)
                            .foregroundStyle(AppPalette.clay)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
                .opacity(buttonsOpacity)
            }
        }
        .onAppear {
            runEntrance()
            Haptics.celebrate()
        }
    }

    // MARK: - Computed copy

    private var motivationLine: String {
        switch streakDays {
        case 3:   return "3 days strong. Habit forming."
        case 7:   return "One full week. That's discipline."
        case 14:  return "Two weeks. Your game is sharpening."
        case 30:  return "A month of daily IQ work. Impressive."
        case 60:  return "60 days. You're in the top 5%."
        case 100: return "100 days. Legend status."
        default:  return "\(streakDays) days straight. Keep the fire."
        }
    }

    private var subLine: String {
        switch streakDays {
        case 3:   return "Three sessions in a row. The hardest part is done."
        case 7:   return "Players who train 7 days see 2× faster improvement."
        case 14:  return "Consistent players make better decisions under pressure."
        case 30:  return "30-day players score 18% higher on scenario quizzes."
        default:  return "Your consistency is your competitive edge."
        }
    }

    // MARK: - Animation

    private func runEntrance() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.1)) {
            numberScale = 1.0
            numberOpacity = 1.0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.38)) {
            badgeOffset = 0
            badgeOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.65)) {
            buttonsOpacity = 1.0
        }
    }

    // MARK: - Share

    private func shareStreak() {
        let text = "I'm on a \(streakDays)-day streak on DropVolley! 🎾"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .rootViewController?
            .present(av, animated: true)
    }

    // MARK: - Court lines watermark

    private var courtLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, size in
                let stroke = GraphicsContext.Stroke(lineWidth: 1.5)
                // Outer singles lines
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.85))
                    p.move(to: CGPoint(x: w * 0.88, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.85))
                    // Baselines
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.15))
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.85))
                    // Service line
                    p.move(to: CGPoint(x: w * 0.12, y: h * 0.50))
                    p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.50))
                    // Centre mark
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.15))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.85))
                }, with: .color(.white), style: stroke)
            }
        }
        .ignoresSafeArea()
    }
}
