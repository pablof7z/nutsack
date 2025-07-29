import Foundation
import NDKSwift
import CashuSwift
import Observation

@MainActor
@Observable
class WalletManager {
    var wallet: NIP60Wallet?
    var isLoading = false
    var error: Error?
    /// Get current balance directly from the wallet
    var currentBalance: Int64 {
        get async {
            guard let wallet = wallet else { return 0 }
            return (try? await wallet.getBalance()) ?? 0
        }
    }

    /// Get transactions directly from the wallet's transaction history
    var transactions: [Transaction] {
        get async {
            guard let wallet = wallet else { return [] }
            let walletTransactions = await wallet.getRecentTransactions(limit: 50)
            return walletTransactions.map { $0.toTransaction() }
        }
    }

    /// Indicates if the wallet is properly configured with at least one mint
    var isWalletConfigured: Bool {
        get async {
            guard let wallet = wallet else { return false }
            let mints = await wallet.mints.getMintURLs()
            return !mints.isEmpty
        }
    }

    // Guard against duplicate initialization
    private var isInitializingWallet = false

    private let nostrManager: NostrManager
    private let appState: AppState

    init(nostrManager: NostrManager, appState: AppState) {
        self.nostrManager = nostrManager
        self.appState = appState
    }

    // MARK: - Wallet Operations

    /// Load wallet for currently authenticated user
    func loadWalletForCurrentUser() async throws {
        print("📖 WalletManager.loadWalletForCurrentUser() called")
        guard NDKAuthManager.shared.hasActiveSession else {
            print("📖 Not authenticated, throwing error")
            throw WalletError.notAuthenticated
        }

        print("📖 Calling loadWallet()")
        try await loadWallet()
    }

    /// Ensure wallet exists (called automatically by loadWallet)
    private func ensureWalletExists() async throws {
        print("📘 WalletManager.ensureWalletExists() called")
        guard !isInitializingWallet else {
            print("📘 Already initializing wallet, skipping duplicate call")
            return
        }

        guard let ndk = nostrManager.ndk else {
            print("📘 NDK not initialized")
            throw WalletError.ndkNotInitialized
        }

        // Wait for signer to be available before creating wallet
        guard let signer = ndk.signer else {
            print("📘 Signer not available")
            throw WalletError.signerNotAvailable
        }

        isInitializingWallet = true
        defer { isInitializingWallet = false }

        let userPubkey = try await signer.pubkey
        print("📘 Got user pubkey: \(userPubkey.prefix(8))...")

        // Create NIP60Wallet instance with mint cache if available
        print("📘 Creating NIP60Wallet instance")
        let ndkWallet = try NIP60Wallet(ndk: ndk, cache: nostrManager.cache)

        // Set the wallet
        self.wallet = ndkWallet
        print("📘 Wallet set")

        // Register the wallet with the zap manager
        if let zapManager = nostrManager.zapManager {
            await zapManager.register(provider: ndkWallet)
        }

        // Load wallet - this will fetch initial config and subscribe to wallet events
        print("📘 Calling ndkWallet.load()")
        try await ndkWallet.load()
        print("📘 ndkWallet.load() completed")

        // The wallet's load() method will emit a balanceChanged event
        // Balance is now accessed directly from the wallet via computed property
        print("📘 Wallet loaded, balance will be fetched on demand")

        // Check if wallet has mints configured
        let fetchedMintURLs = await ndkWallet.mints.getMintURLs()
        print("📘 Current mint URLs: \(fetchedMintURLs)")
        if fetchedMintURLs.isEmpty {
            print("⚠️ WalletManager - No mints configured. User needs to add mints in wallet settings.")
        } else {
            print("✅ WalletManager - Wallet loaded with \(fetchedMintURLs.count) mints")
        }
    }

    /// Load wallet from NIP-60 events
    func loadWallet() async throws {
        print("📗 WalletManager.loadWallet() called")
        guard nostrManager.ndk != nil else {
            print("📗 NDK not initialized, throwing error")
            throw WalletError.ndkNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        print("📗 Calling ensureWalletExists()")
        // Ensure wallet exists (creates if needed)
        try await ensureWalletExists()

        guard wallet != nil else {
            print("📗 No wallet after ensureWalletExists, throwing error")
            throw WalletError.noActiveWallet
        }

        print("📗 Wallet loaded successfully, triggering negentropy sync")
        // Trigger negentropy sync after wallet has loaded
        Task {
            await nostrManager.performStartupSync()
        }
    }

    /// Get relays for wallet configuration
    private func getRelaysForWallet() async -> [String] {
        print("🌐 getRelaysForWallet called")
        guard let ndk = nostrManager.ndk,
              let signer = ndk.signer,
              let userPubkey = try? await signer.pubkey else {
            print("🌐 getRelaysForWallet - returning default relays (guard failed)")
            // Return default relays if we can't get user's relays
            return [
                "wss://relay.primal.net"
            ]
        }
        print("🌐 getRelaysForWallet - guard ok, pubkey: \(userPubkey.prefix(8))...")

        // Try to get user's relay list
        let user = ndk.getUser(userPubkey)
        do {
            // Use the method from NDKUser.swift that returns [NDKRelayInfo]
            print("🌐 getRelaysForWallet - fetching user relay list")
            let relayInfoList: [NDKRelayInfo] = try await user.fetchRelayList()
            let writeRelays = relayInfoList
                .filter { $0.write }
                .map { $0.url }
            print("🌐 getRelaysForWallet - found \(writeRelays.count) write relays")
            if !writeRelays.isEmpty {
                print("🌐 getRelaysForWallet - returning user's write relays: \(writeRelays)")
                return writeRelays
            }
        } catch {
            print("⚠️ WalletManager - Failed to fetch user's relay list: \(error)")
        }

        print("🌐 getRelaysForWallet - falling back to default relays")
        // Fallback to default relays
        return [
            "wss://relay.primal.net"
        ]
    }

    // MARK: - Mint Operations

    // MARK: - Offline Operations

    /// Get all unspent proofs grouped by mint for offline sending
    func getUnspentProofsByMint() async throws -> [URL: [CashuSwift.Proof]] {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        let proofsByMint = await wallet.getUnspentProofs()

        // Convert string mint URLs to URL objects
        var result: [URL: [CashuSwift.Proof]] = [:]
        for (mintString, proofs) in proofsByMint {
            if let mintURL = URL(string: mintString) {
                result[mintURL] = proofs
            }
        }

        return result
    }

    /// Send offline using specific proofs
    func sendOffline(
        proofs: [CashuSwift.Proof],
        mint: URL,
        memo: String?
    ) async throws -> (token: String, transactionId: UUID) {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        // Create the token without P2PK locking
        let token = try await wallet.createTokenFromProofs(
            proofs: proofs,
            mint: mint,
            memo: memo
        )

        // Transaction will be tracked by wallet's transaction history
        let transactionId = UUID()

        return (token: token, transactionId: transactionId)
    }

    // MARK: - Send Operations

    /// Send ecash tokens
    func send(amount: Int64, memo: String?, fromMint: URL?) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        // Create pending transaction immediately in wallet's transaction history
        let pendingTx = await wallet.transactionHistory.createPendingTransaction(
            type: .send,
            amount: amount,
            direction: .outgoing,
            memo: memo ?? "Sent ecash",
            mint: fromMint?.absoluteString
        )
        print("Created pending transaction: \(pendingTx.id) for send operation")

        // Transaction will be added when wallet event is processed

        do {
            // Select mint if not specified
            let selectedMintURL: URL
            if let fromMint = fromMint {
                selectedMintURL = fromMint
            } else {
                // Auto-select mint with sufficient balance
                let mintURLs = await wallet.mints.getMintURLs()
                let mints = mintURLs.compactMap { URL(string: $0) }
                var selectedMint: URL?

                for mint in mints {
                    let balance = await wallet.getBalance(mint: mint)
                    if balance >= amount {
                        selectedMint = mint
                        break
                    }
                }

                guard let selected = selectedMint else {
                    throw WalletError.insufficientBalance
                }
                selectedMintURL = selected
            }

            // Generate P2PK pubkey for locking
            let p2pkPubkey = try await wallet.getP2PKPubkey()

            // Send tokens (creates P2PK locked proofs)
            let (proofs, _) = try await wallet.send(
                amount: amount,
                to: p2pkPubkey,
                mint: selectedMintURL
            )

            // Create token from proofs
            let token = CashuSwift.Token(
                proofs: [selectedMintURL.absoluteString: proofs],
                unit: "sat",
                memo: memo
            )

            // Encode token
            // Note: JSONCoding.encoder already has sorted keys formatting
            let tokenData = try JSONCoding.encoder.encode(token)
            guard String(data: tokenData, encoding: .utf8) != nil else {
                throw WalletError.encodingError
            }

            // Create base64url encoded token
            let base64Token = tokenData.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")

            let tokenString = "cashuA\(base64Token)"

            // Update pending transaction status to completed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .completed)

            // Create history event for sending ecash
            do {
                guard let ndk = nostrManager.ndk,
                      let signer = ndk.signer else {
                    print("Failed to create history event: NDK or signer not available")
                    return tokenString
                }

                try await wallet.eventManager.createSpendingHistoryEvent(
                    direction: .out,
                    amount: amount,
                    memo: memo ?? "Sent ecash",
                    signer: signer
                )
            } catch {
                print("Failed to create history event for send: \(error)")
                // Don't throw here, the send operation succeeded even if history event failed
            }

            return tokenString
        } catch {
            // Update pending transaction status to failed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .failed)
            throw error
        }
    }

    // MARK: - Receive Operations

    /// Receive ecash tokens
    func receive(tokenString: String) async throws -> Int64 {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        // Parse token string to get amount first
        guard tokenString.hasPrefix("cashuA") else {
            throw WalletError.invalidToken
        }

        let base64Part = String(tokenString.dropFirst(6))

        // Convert base64url to base64
        var base64 = base64Part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let tokenData = Data(base64Encoded: base64),
              let token = try? JSONCoding.decoder.decode(CashuSwift.Token.self, from: tokenData) else {
            throw WalletError.invalidToken
        }

        // Calculate total amount from token
        let totalAmount = token.proofsByMint.values.reduce(0) { sum, proofs in
            sum + proofs.reduce(0) { $0 + Int64($1.amount) }
        }

        // Create pending transaction immediately in wallet's transaction history
        let pendingTx = await wallet.transactionHistory.createPendingTransaction(
            type: .receive,
            amount: totalAmount,
            direction: .incoming,
            memo: token.memo ?? "Received ecash"
        )
        print("Created pending transaction: \(pendingTx.id) for receive operation")

        do {
            var totalReceived: Int64 = 0

            // Process proofs from each mint
            for (_, proofs) in token.proofsByMint {
                // Receive the proofs - wallet can handle proofs from any mint
                try await wallet.receive(proofs: proofs)

                // Calculate total
                totalReceived += proofs.reduce(0) { $0 + Int64($1.amount) }
            }

            // Update pending transaction status to completed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .completed)

            // Create history event for receiving ecash
            if totalReceived > 0 {
                do {
                    guard let ndk = nostrManager.ndk,
                          let signer = ndk.signer else {
                        print("Failed to create history event: NDK or signer not available")
                        return totalReceived
                    }

                    try await wallet.eventManager.createSpendingHistoryEvent(
                        direction: .in,
                        amount: totalReceived,
                        memo: token.memo ?? "Received ecash",
                        signer: signer
                    )
                } catch {
                    print("Failed to create history event for receive: \(error)")
                    // Don't throw here, the receive operation succeeded even if history event failed
                }
            }

            return totalReceived
        } catch {
            // Update pending transaction status to failed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .failed)
            throw error
        }
    }

    // MARK: - Lightning Operations

    /// Pay a Lightning invoice
    func payLightning(invoice: String, amount: Int64) async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        // Create pending transaction immediately in wallet's transaction history
        let lightningData = LightningData(invoice: invoice)
        let pendingTx = await wallet.transactionHistory.createPendingTransaction(
            type: .melt,
            amount: amount,
            direction: .outgoing,
            memo: "Lightning payment",
            lookupKeys: TransactionLookupKeys(paymentHash: nil), // Could extract from invoice
            lightningData: lightningData
        )
        print("Created pending transaction: \(pendingTx.id) for lightning payment")

        do {
            let (preimage, feePaid) = try await wallet.payLightning(
                invoice: invoice,
                amount: amount
            )

            print("Paid Lightning invoice: \(amount) sats, fee: \(feePaid ?? 0) sats")

            // Update pending transaction status to completed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .completed)

            return preimage
        } catch {
            // Update pending transaction status to failed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .failed)
            throw error
        }
    }

    // MARK: - Nutzap Operations

    /// Send a nutzap
    func sendNutzap(
        to recipient: String,
        amount: Int64,
        comment: String?,
        acceptedMints: [URL]
    ) async throws {
        print("🚀 WalletManager.sendNutzap called - recipient: \(recipient), amount: \(amount), acceptedMints: \(acceptedMints)")

        guard let wallet = wallet else {
            print("❌ No wallet!")
            throw WalletError.noActiveWallet
        }

        // Create pending transaction immediately in wallet's transaction history
        let nutzapData = NutzapData(
            recipientPubkey: recipient,
            nutzapEventId: "pending-\(UUID().uuidString)", // Temporary ID until nutzap event is created
            comment: comment
        )
        let pendingTx = await wallet.transactionHistory.createPendingTransaction(
            type: .nutzapSent,
            amount: amount,
            direction: .outgoing,
            memo: comment ?? "Zap sent",
            lookupKeys: TransactionLookupKeys(recipientPubkey: recipient),
            nutzapData: nutzapData
        )
        print("Created pending transaction: \(pendingTx.id) for nutzap")

        do {
            // Create nutzap request
            let request = NutzapPaymentRequest(
                amountSats: amount,
                recipientPubkey: recipient,
                recipientP2PK: "", // Empty P2PK for now, will be set by wallet
                acceptedMints: acceptedMints,
                comment: comment
            )

            print("💳 Created NutzapPaymentRequest, calling wallet.pay()")

            // Send nutzap
            _ = try await wallet.pay(request)

            print("✅ Nutzap completed successfully!")

            // Update pending transaction status to completed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .completed)
        } catch {
            // Update pending transaction status to failed
            await wallet.transactionHistory.updateTransactionStatus(id: pendingTx.id, status: .failed)
            throw error
        }
    }

    // MARK: - Mint Management

    /// Get mint URLs excluding blacklisted ones
    func getActiveMintsURLs() async -> [String] {
        guard let wallet = wallet else { return [] }
        let allMints = await wallet.mints.getMintURLs()
        return allMints.filter { !appState.isMintBlacklisted($0) }
    }

    /// Check if mint operations should be allowed for a URL
    func shouldAllowMintOperations(for mintURL: String) -> Bool {
        return !appState.isMintBlacklisted(mintURL)
    }

    // MARK: - Cross-mint Operations

    /// Transfer between mints
    func transferBetweenMints(
        amount: Int64,
        fromMint: URL,
        toMint: URL
    ) async throws -> TransferResult {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        return try await wallet.transferBetweenMints(
            amount: amount,
            fromMint: fromMint,
            toMint: toMint
        )
    }

    /// Estimate transfer fees
    func estimateTransferFees(
        amount: Int64,
        fromMint: URL,
        toMint: URL
    ) async throws -> (lightningFee: Int64, inputFee: Int64, totalFee: Int64) {
        guard wallet != nil else {
            throw WalletError.noActiveWallet
        }

        // Estimate fees for cross-mint transfer
        // Lightning fee is typically 0.5% + 1 sat
        let lightningFee = max(1, Int64(Double(amount) * 0.005) + 1)
        // Input fee is typically 0.2%
        let inputFee = max(1, Int64(Double(amount) * 0.002))
        let totalFee = lightningFee + inputFee

        return (lightningFee: lightningFee, inputFee: inputFee, totalFee: totalFee)
    }

    // MARK: - State Management

    /// Check and reconcile proof states
    func reconcileProofStates() async throws {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        try await wallet.checkAndReconcileProofStates()
    }

    // MARK: - Wallet Events Management

    /// Fetch all wallet events (kind 7375) and their deletion status
    func fetchAllWalletEvents() async throws -> [WalletEventInfo] {
        guard let ndk = nostrManager.ndk,
              let signer = ndk.signer else {
            throw WalletError.ndkNotInitialized
        }

        let userPubkey = try await signer.pubkey

        // Fetch all token events (kind 7375) from this user
        let tokenFilter = NDKFilter(
            authors: [userPubkey],
            kinds: [EventKind.cashuToken]
        )

        // Fetch deletion events that target token events
        let deletionFilter = NDKFilter(
            authors: [userPubkey],
            kinds: [EventKind.deletion],
            tags: ["k": Set([String(EventKind.cashuToken)])]
        )

        // Fetch events from cache or relays using data sources
        let tokenDataSource = ndk.observe(filter: tokenFilter, maxAge: 3600)
        let deletionDataSource = ndk.observe(filter: deletionFilter, maxAge: 3600)

        // Collect events
        var tokenEvents: [NDKEvent] = []
        var deletionEvents: [NDKEvent] = []

        // Use a timeout for collecting events
        let fetchTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await event in tokenDataSource.events {
                        tokenEvents.append(event)
                    }
                }
                group.addTask {
                    for await event in deletionDataSource.events {
                        deletionEvents.append(event)
                    }
                }
                // Wait for a reasonable timeout
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                group.cancelAll()
            }
        }

        await fetchTask.value

        // Build a set of deleted event IDs from deletion events
        var deletedEventIds = Set<String>()
        var deletionEventMap: [String: NDKEvent] = [:]

        for deletionEvent in deletionEvents {
            // Extract deleted event IDs from "e" tags
            for tag in deletionEvent.tags {
                if tag.count >= 2 && tag[0] == "e" {
                    deletedEventIds.insert(tag[1])
                    deletionEventMap[tag[1]] = deletionEvent
                }
            }
        }

        // Also check for del tags in newer events
        var eventsByDel: [String: Set<String>] = [:]
        for event in tokenEvents {
            // Try to decrypt and parse token data
            if let tokenData = try? await decryptTokenEvent(event, signer: signer) {
                if let delTags = tokenData.del {
                    for deletedId in delTags {
                        deletedEventIds.insert(deletedId)
                        if eventsByDel[deletedId] == nil {
                            eventsByDel[deletedId] = Set<String>()
                        }
                        eventsByDel[deletedId]?.insert(event.id)
                    }
                }
            }
        }

        // Process each token event
        var walletEvents: [WalletEventInfo] = []

        for event in tokenEvents {
            // Try to decrypt token data
            let tokenData = try? await decryptTokenEvent(event, signer: signer)

            // Check if this event is deleted
            let isDeleted = deletedEventIds.contains(event.id)

            // Determine deletion reason
            var deletionReason: String?
            var deletionEvent: NDKEvent?

            if isDeleted {
                if let delEvent = deletionEventMap[event.id] {
                    deletionReason = "Deleted via NIP-09"
                    deletionEvent = delEvent
                } else if let replacingEventIds = eventsByDel[event.id] {
                    deletionReason = "Replaced by event(s): \(replacingEventIds.joined(separator: ", ").prefix(32))..."
                }
            }

            let eventInfo = WalletEventInfo(
                event: event,
                tokenData: tokenData,
                isDeleted: isDeleted,
                deletionReason: deletionReason,
                deletionEvent: deletionEvent
            )

            walletEvents.append(eventInfo)
        }

        // Sort by creation date (newest first)
        walletEvents.sort { $0.event.createdAt > $1.event.createdAt }

        return walletEvents
    }

    /// Decrypt a token event to get its content
    private func decryptTokenEvent(_ event: NDKEvent, signer: NDKSigner) async throws -> NIP60TokenEvent? {
        let sender = NDKUser(pubkey: event.pubkey)
        let decryptedContent = try await signer.decrypt(
            sender: sender,
            value: event.content,
            scheme: .nip44
        )

        guard let data = decryptedContent.data(using: .utf8) else {
            return nil
        }

        return try JSONCoding.decoder.decode(NIP60TokenEvent.self, from: data)
    }

    /// Check proof states for specific proofs
    func checkProofStates(for proofs: [CashuSwift.Proof], mint mintURL: String) async throws -> [String: CashuSwift.Proof.ProofState] {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        guard URL(string: mintURL) != nil else {
            throw WalletError.invalidMintURL
        }

        // Get mint instance
        let mints = await wallet.mints.getAllMints()
        guard let mint = mints[mintURL] else {
            throw WalletError.mintNotFound
        }

        // Check proof states
        let states = try await CashuSwift.check(proofs, mint: mint)

        // Build result dictionary mapping C value to state
        var result: [String: CashuSwift.Proof.ProofState] = [:]
        for (index, proof) in proofs.enumerated() {
            if index < states.count {
                result[proof.C] = states[index]
            }
        }

        return result
    }

    /// Get wallet's P2PK pubkey
    func getP2PKPubkey() async throws -> String {
        guard let wallet = wallet else {
            throw WalletError.noActiveWallet
        }

        return try await wallet.getP2PKPubkey()
    }

    // MARK: - Mint Management

    /// Get mints info as MintInfo array

    // MARK: - Session Management

    /// Clear all wallet data and cancel active subscriptions (called during logout)
    func clearWalletData() {
        // Clear wallet state
        wallet = nil

        print("WalletManager - Cleared all wallet data and cancelled subscriptions")
    }

    // MARK: - Health Monitoring

    // wallet property already exposed at the top

    // MARK: - Pending Transactions

    /// Calculate total pending amount (outgoing is negative, incoming is positive)
    var pendingAmount: Int64 {
        get async {
            guard let wallet = wallet else { return 0 }
            let walletTransactions = await wallet.getRecentTransactions(limit: 50)
            return walletTransactions
                .filter { $0.status == .pending || $0.status == .processing }
                .reduce(0) { sum, transaction in
                    switch transaction.direction {
                    case .incoming:
                        return sum + transaction.amount
                    case .outgoing:
                        return sum - transaction.amount
                    case .neutral:
                        return sum
                    }
                }
        }
    }

    // MARK: - Private Methods
}

// MARK: - Errors

enum WalletError: LocalizedError {
    case ndkNotInitialized
    case noActiveWallet // TODO: rename to noWallet
    case notAuthenticated
    case insufficientBalance
    case invalidToken
    case encodingError
    case signerNotAvailable
    case invalidMintURL
    case mintNotFound

    var errorDescription: String? {
        switch self {
        case .ndkNotInitialized:
            return "NDK is not initialized"
        case .noActiveWallet:
            return "No wallet found"
        case .notAuthenticated:
            return "User not authenticated"
        case .insufficientBalance:
            return "Insufficient balance"
        case .invalidToken:
            return "Invalid token format"
        case .encodingError:
            return "Failed to encode data"
        case .signerNotAvailable:
            return "Signer not available yet"
        case .invalidMintURL:
            return "Invalid mint URL"
        case .mintNotFound:
            return "Mint not found"
        }
    }
}

// MARK: - Extensions
