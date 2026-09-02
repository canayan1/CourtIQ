import SwiftUI

/// The one fact the Tactics gate needs from the rest of the app: is this
/// player premium. Kept as its own observable so the ported lesson views
/// keep reading a plain `isSubscribed` (the seam `AccessGate` was built
/// around) while the value comes from DropVolley's real entitlement.
@Observable
@MainActor
final class TacticsAccess {
    var isSubscribed: Bool
    init(isSubscribed: Bool = false) { self.isSubscribed = isSubscribed }
}

/// DropVolley's paywall, presented from inside the lessons. Environment
/// objects are re-attached explicitly: a sheet hosted by a NavigationStack
/// destination has lost them by the time it presents.
struct TacticsPaywallSheet: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    var body: some View {
        NavigationStack {
            PaywallView(source: "Tactics")
                .environmentObject(session)
                .environmentObject(lang)
        }
    }
}
