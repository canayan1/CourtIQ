import SwiftUI

struct TodayView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Today")
                .font(.largeTitle.bold())
            Text("Welcome to the CourtIQ training skeleton.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Today")
    }
}
