import SwiftUI

/// DropVolley on the wrist.
///
/// UNRUN. Every line in this target was written without a watch to run it on
/// — the detectors underneath are tested against synthetic signals, and the
/// plumbing here (workout session, batched sensors, microphone, the link to
/// the phone) has been compiled and never executed. It is here because the
/// architecture needed a second sensor to prove it was device-agnostic, and
/// because the user asked for it twice. It is NOT here because it works.
/// The first session on real hardware is a test, not a feature.
@main
struct CourtIQWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchSessionView()
        }
    }
}
