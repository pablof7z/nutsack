import Foundation
import NDKSwift
import CashuSwift

// Data model for wallet event information
struct WalletEventInfo: Identifiable, Hashable {
    let id: String
    let event: NDKEvent
    let tokenData: NIP60TokenEvent?
    let isDeleted: Bool
    let deletionReason: String?
    let deletionEvent: NDKEvent?

    init(event: NDKEvent, tokenData: NIP60TokenEvent?, isDeleted: Bool, deletionReason: String? = nil, deletionEvent: NDKEvent? = nil) {
        self.id = event.id
        self.event = event
        self.tokenData = tokenData
        self.isDeleted = isDeleted
        self.deletionReason = deletionReason
        self.deletionEvent = deletionEvent
    }

    static func == (lhs: WalletEventInfo, rhs: WalletEventInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
