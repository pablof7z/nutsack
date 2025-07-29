import Foundation
import NDKSwift

// MARK: - MintInfo
// Local replacement for the removed NIP60Wallet.MintInfo type
struct MintInfo: Identifiable, Equatable, Hashable {
    let id: String
    let url: URL
    let name: String?
    let description: String?
    let isActive: Bool

    init(url: URL, name: String? = nil, description: String? = nil, isActive: Bool = true) {
        self.id = url.absoluteString
        self.url = url
        self.name = name
        self.description = description
        self.isActive = isActive
    }
}

// Note: MintInfo is now defined at the top level of this file
// References to NIP60Wallet.MintInfo should be changed to just MintInfo

// MARK: - Transaction
// UI model for displaying transactions (no longer a SwiftData @Model)
struct Transaction: Identifiable {
    let id = UUID()
    var transactionID: UUID

    var type: TransactionType
    var amount: Int
    var memo: String?
    var createdAt: Date
    var nostrEventID: String?  // For nutzaps
    var lightningInvoice: String?
    var status: TransactionStatus
    var senderPubkey: String?  // For nutzaps and received transactions
    var recipientPubkey: String?  // For sent nutzaps
    var offlineToken: String?  // Store generated offline token
    var timestamp: Date  // Transaction timestamp from wallet event
    var direction: TransactionDirection  // Direction of the transaction
    var mintURL: String?  // Mint URL for the transaction
    var errorDetails: String?  // Error details for failed transactions

    init(type: TransactionType, amount: Int, memo: String? = nil) {
        self.transactionID = UUID()
        self.type = type
        self.amount = amount
        self.memo = memo
        self.createdAt = Date()
        self.timestamp = Date()
        self.status = .pending
        self.direction = .neutral
    }

    enum TransactionType: String, Codable {
        case mint      // Lightning -> Ecash (deposit)
        case melt      // Ecash -> Lightning (withdraw)
        case send      // Send ecash token
        case receive   // Receive ecash token
        case nutzap    // NIP-61 zap
        case deposit   // Alias for mint
        case withdraw  // Alias for melt
        case swap      // Swap between mints
    }

    enum TransactionStatus: String, Codable {
        case pending
        case processing
        case completed
        case failed
        case expired
    }

    enum TransactionDirection: String, Codable {
        case incoming
        case outgoing
        case neutral
    }
}

// MARK: - Transaction Extensions

extension Transaction.TransactionType {
    var displayName: String {
        switch self {
        case .mint, .deposit: return "Lightning Deposit"
        case .melt, .withdraw: return "Lightning Payment"
        case .send: return "Sent Ecash"
        case .receive: return "Received Ecash"
        case .nutzap: return "Zap"
        case .swap: return "Mint Transfer"
        }
    }
}

// MARK: - WalletTransaction UI Extensions

extension WalletTransaction {
    /// Convert WalletTransaction to app's Transaction model for UI compatibility
    func toTransaction() -> Transaction {
        var transaction = Transaction(
            type: mapTransactionType(),
            amount: Int(amount),
            memo: memo ?? displayDescription
        )

        // Map status
        switch status {
        case .pending:
            transaction.status = .pending
        case .processing:
            transaction.status = .processing
        case .completed:
            transaction.status = .completed
        case .failed:
            transaction.status = .failed
        case .expired:
            transaction.status = .expired
        }

        // Map direction
        switch direction {
        case .incoming:
            transaction.direction = .incoming
        case .outgoing:
            transaction.direction = .outgoing
        case .neutral:
            transaction.direction = .neutral
        }

        // Set additional fields
        transaction.timestamp = timestamp
        transaction.createdAt = timestamp

        // Set nutzap-specific fields
        if let nutzapData = nutzapData {
            transaction.senderPubkey = nutzapData.senderPubkey
            transaction.recipientPubkey = nutzapData.recipientPubkey
            transaction.nostrEventID = nutzapData.nutzapEventId
        }

        // Set primary event ID
        if let primaryEventId = events.primaryEventId {
            transaction.nostrEventID = primaryEventId
        }

        // Set mint URL if available
        if let mint = mint {
            transaction.mintURL = mint
        }

        // Set offline token if available
        if let tokenData = ecashTokenData {
            transaction.offlineToken = tokenData.tokenString
        }

        // Set error details if available
        transaction.errorDetails = errorDetails

        return transaction
    }

    private func mapTransactionType() -> Transaction.TransactionType {
        switch type {
        case .mint:
            return .mint
        case .melt:
            return .melt
        case .send:
            return .send
        case .receive:
            return .receive
        case .nutzapSent, .nutzapReceived:
            return .nutzap
        case .swap:
            return .swap
        }
    }
}
