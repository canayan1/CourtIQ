import Foundation
import SwiftData

@Model
final class TipReadHistory {
    var tipID: String
    var readAt: Date

    init(tipID: String) {
        self.tipID = tipID
        self.readAt = Date()
    }
}
