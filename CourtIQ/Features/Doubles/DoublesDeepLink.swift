import Foundation
import Combine

/// Routes incoming universal links (and custom-scheme URLs) for the doubles
/// invite flow: `https://<host>/d/<CODE>` → opens the Join flow with the code
/// prefilled. Set from the app's URL handlers; observed by the root view,
/// which presents the join sheet via `.sheet(item:)`.
@MainActor
final class DoublesLinkRouter: ObservableObject {
    static let shared = DoublesLinkRouter()

    /// Pending invite (wrapped so it's Identifiable for `.sheet(item:)`).
    @Published var pendingInvite: Invite?

    struct Invite: Identifiable, Equatable {
        let code: String
        var id: String { code }
    }

    /// Parse an incoming URL. Returns true if it matched a doubles invite
    /// (`.../d/<CODE>`), in which case `pendingInvite` is set.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let parts = comps.path.split(separator: "/").map(String.init)
        guard let i = parts.firstIndex(where: { $0.lowercased() == "d" }), i + 1 < parts.count else { return false }
        let code = parts[i + 1].trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return false }
        pendingInvite = Invite(code: code)
        return true
    }
}
