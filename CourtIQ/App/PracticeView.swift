import SwiftUI

struct PracticeView: View {
    private let categories = ["Serve", "Return", "Rally", "Net", "Mental"]

    var body: some View {
        List(categories, id: \.self) { category in
            NavigationLink {
                QuizView(title: "\(category) Quiz")
            } label: {
                Text(category)
            }
        }
        .navigationTitle("Practice")
    }
}
