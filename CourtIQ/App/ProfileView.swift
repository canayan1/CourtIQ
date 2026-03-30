import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Profile")
                .font(.largeTitle.bold())
            Text("This is a minimal profile screen.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
    }
}
