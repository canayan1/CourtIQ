import SwiftUI

@main
struct CourtIQApp: App {
    @StateObject private var session = UserSessionManager.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(session)
        }
    }
}
