import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            QuizView()
                .tabItem {
                    Label("Quiz", systemImage: "questionmark.circle.fill")
                }

            Text("Daily Tip — Coming Soon")
                .tabItem {
                    Label("Daily Tip", systemImage: "lightbulb.fill")
                }

            Text("Profile — Coming Soon")
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}
