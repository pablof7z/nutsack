import Foundation
import NDKSwift
import SwiftUI
import Observation

@MainActor
@Observable
class NostrManager {
    var ndk: NDK?
    var isConnected = false
    var relayStatus: [String: Bool] = [:]
    var zapManager: NDKZapManager?
    var isInitialized = false
    
    var cache: NDKSQLiteCache?
    
    // Declarative data sources
    private(set) var contactsMetadataDataSource: MultipleProfilesDataSource?
    
    // Current user's profile
    private(set) var currentUserProfile: NDKUserProfile?
    private var profileObservationTask: Task<Void, Never>?
    
    // Default relays for the app
    let defaultRelays = [RelayConstants.primal]
    
    // Key for storing user-added relays
    private static let userRelaysKey = "UserAddedRelays"
    
    init(from: String) {
        print("🏚️ [NostrManager] Initializing...", from)
        Task {
            await setupNDK()
        }
    }
    
    private func setupNDK() async {
        print("🏚️ [NostrManager] Setting up NDK...")
        // Initialize SQLite cache for better performance and offline access
        do {
            cache = try await NDKSQLiteCache()
            let allRelays = getAllRelays()
            ndk = NDK(relayUrls: allRelays, cache: cache)
            print("NDK initialized with SQLite cache and \(allRelays.count) relays: \(allRelays)")
        } catch {
            print("Failed to initialize SQLite cache: \(error). Continuing without cache.")
            // Fall back to no cache if initialization fails
            let allRelays = getAllRelays()
            ndk = NDK(relayUrls: allRelays)
            print("NDK initialized without cache and \(allRelays.count) relays: \(allRelays)")
        }
        
        // Set NDK on auth manager
        if let ndk = ndk {
            print("🏚️ [NostrManager] Setting NDK on auth manager")
            NDKAuthManager.shared.setNDK(ndk)
            
            // Auth manager will restore sessions automatically when needed
            
            // Configure NIP-89 client tags for Nutsack
            ndk.clientTagConfig = NDKClientTagConfig(
                name: "Nutsack",
                relay: RelayConstants.primal,
                autoTag: true,
                excludedKinds: [
                    // Exclude sensitive event kinds from client tagging
                    EventKind.encryptedDirectMessage,
                    EventKind.cashuSpendingHistory,
                    EventKind.cashuToken,
                ]
            )
            print("🏚️ [NostrManager] Configured NIP-89 client tags")
            
            // Initialize zap manager
            zapManager = NDKZapManager(ndk: ndk)
            print("🏚️ [NostrManager] Zap manager initialized")
            
            // If authenticated after restore, initialize data sources
            if NDKAuthManager.shared.isAuthenticated {
                if let signer = NDKAuthManager.shared.activeSigner {
                    Task {
                        let pubkey = try await signer.pubkey
                        await initializeDataSources(for: pubkey)
                    }
                }
            }
        }
        
        Task {
            await connectToRelays()
        }
        
        // Mark as initialized
        isInitialized = true
        print("🏚️ [NostrManager] Initialization complete")
    }
    
    func connectToRelays() async {
        guard let ndk = ndk else { return }
        
        print("NostrManager - Connecting to relays: \(defaultRelays)")
        await ndk.connect()
        isConnected = true
        print("NostrManager - Connected to relays")
        
        // Check actual connected relays
        // Note: pool is internal, so we can't access it directly
        print("NostrManager - Connected to NDK with relays: \(defaultRelays)")
        
        // Monitor relay status
        await monitorRelayStatus()
    }
    
    private func monitorRelayStatus() async {
        guard let ndk = ndk else { return }
        
        // Monitor relay changes
        for await change in await ndk.relayChanges {
            switch change {
            case .relayConnected(let relay):
                relayStatus[relay.url] = true
            case .relayDisconnected(let relay):
                relayStatus[relay.url] = false
            case .relayAdded(let relay):
                relayStatus[relay.url] = false
            case .relayRemoved(let url):
                relayStatus.removeValue(forKey: url)
            }
        }
    }
    
    func login(with privateKey: String) async throws {
        guard let ndk = ndk else { throw NostrError.ndkNotInitialized }
        
        let signer = try NDKPrivateKeySigner(privateKey: privateKey)
        
        // Create session via NDKAuthManager for proper persistence
        _ = try await NDKAuthManager.shared.createSession(
            with: signer,
            requiresBiometric: false,
            isHardwareBacked: false
        )
        
        // Start session with mute list support
        try await ndk.startSession(
            signer: signer,
            config: NDKSessionConfiguration(
                dataRequirements: [.followList, .muteList],
                preloadStrategy: .progressive
            )
        )
        
        let publicKey = try await signer.pubkey
        print("Logged in with public key: \(publicKey)")
        
        // Initialize declarative data sources
        await initializeDataSources(for: publicKey)
    }
    
    func createNewAccount(displayName: String, about: String? = nil, picture: String? = nil) async throws -> NDKSession {
        print("🏚️ [NostrManager] createNewAccount() called with displayName: \(displayName)")
        print("🏚️ [NostrManager] NDK instance: \(ndk != nil ? "exists" : "nil")")
        print("🏚️ [NostrManager] Is connected: \(isConnected)")
        
        guard let ndk = ndk else { 
            print("🏚️ [NostrManager] ERROR: NDK is not initialized!")
            throw NostrError.ndkNotInitialized 
        }
        
        // Generate new private key
        let signer = try NDKPrivateKeySigner.generate()
        
        // Create auth session for persistence
        let session = try await NDKAuthManager.shared.createSession(
            with: signer,
            requiresBiometric: false,
            isHardwareBacked: false
        )
        
        // Start session with mute list support
        print("🏚️ [NostrManager] Starting session...")
        try await ndk.startSession(
            signer: signer,
            config: NDKSessionConfiguration(
                dataRequirements: [.followList, .muteList],
                preloadStrategy: .progressive
            )
        )
        
        // Create and publish profile
        let metadata = NDKUserProfile(
            name: displayName,
            displayName: displayName,
            about: about ?? "Nutsack wallet user",
            picture: picture
        )
        
        if NDKAuthManager.shared.isAuthenticated {
            print("🏚️ [NostrManager] User is authenticated, publishing metadata...")
            // Create metadata event
            let metadataContent = try JSONCoding.encodeToString(metadata)
            let metadataEvent = try await NDKEventBuilder(ndk: ndk)
                .content(metadataContent)
                .kind(0)
                .build(signer: signer)
            
            _ = try await ndk.publish(metadataEvent)
            
            // Update session with profile
            try await NDKAuthManager.shared.updateActiveSessionProfile(metadata)
        }
        
        // Initialize declarative data sources
        await initializeDataSources(for: session.pubkey)
        
        print("🏚️ [NostrManager] createNewAccount() completed successfully with pubkey: \(session.pubkey)")
        return session
    }
    
    func logout() {
        // Cancel profile observation
        profileObservationTask?.cancel()
        profileObservationTask = nil
        currentUserProfile = nil
        
        // Clean up data sources
        contactsMetadataDataSource = nil
        
        // Clear all cached data and sessions
        Task {
            if let cache = cache {
                try? await cache.clear()
                print("Cleared all cached data")
            }
            
            // Clear all sessions from keychain to prevent "Welcome back" scenario
            for session in NDKAuthManager.shared.availableSessions {
                try? await NDKAuthManager.shared.deleteSession(session)
            }
        }
        
        // Clear active authentication state
        NDKAuthManager.shared.logout()
        
        // Clear NDK signer
        ndk?.signer = nil
        
        // Clear zap manager signer
        // Zap manager gets signer from NDK automatically
        
        print("Logged out and cleared all authentication data")
    }
    
    // MARK: - Auth State Management
    
    /// Check if user is authenticated via NDKAuth
    var isAuthenticated: Bool {
        NDKAuthManager.shared.isAuthenticated
    }
    
    /// Create account using existing nsec
    func createAccountFromNsec(_ nsec: String, displayName: String) async throws -> NDKSession {
        print("🏚️ [NostrManager] createAccountFromNsec() called with displayName: \(displayName)")
        guard let ndk = ndk else { throw NostrError.ndkNotInitialized }
        
        let signer = try NDKPrivateKeySigner(nsec: nsec)
        
        // Create auth session for persistence
        let session = try await NDKAuthManager.shared.createSession(
            with: signer,
            requiresBiometric: false,
            isHardwareBacked: false
        )
        
        // Start session with mute list support
        try await ndk.startSession(
            signer: signer,
            config: NDKSessionConfiguration(
                dataRequirements: [.followList, .muteList],
                preloadStrategy: .progressive
            )
        )
        
        // Initialize declarative data sources
        await initializeDataSources(for: session.pubkey)
        
        print("🏚️ [NostrManager] createAccountFromNsec() completed successfully with pubkey: \(session.pubkey)")
        return session
    }
    
    /// Get current user from auth manager
    var currentUser: NDKUser? {
        get async {
            guard NDKAuthManager.shared.isAuthenticated else { return nil }
            return try? await NDKAuthManager.shared.activeSigner?.user()
        }
    }
    
    // MARK: - Declarative Data Sources
    
    private func initializeDataSources(for pubkey: String) async {
        guard let ndk = ndk else { return }
        
        print("NostrManager - Initializing declarative data sources for user: \(pubkey.prefix(8))...")
        
        // Cancel any existing profile observation
        profileObservationTask?.cancel()
        
        // Start observing user profile using NDKProfileManager
        profileObservationTask = Task { @MainActor in
            // Use maxAge of 3600 (1 hour) for the profile in settings
            for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: TimeConstants.hour) {
                self.currentUserProfile = profile
            }
        }
        
        
        // Load contacts and initialize metadata data source
        Task {
            await loadContactsMetadata(for: pubkey, ndk: ndk)
        }
    }
    
    private func loadContactsMetadata(for pubkey: String, ndk: NDK) async {
        let filter = NDKFilter(
            authors: [pubkey],
            kinds: [3],
            limit: 1
        )
        
        // Use declarative data source to fetch contact list
        let contactDataSource = ndk.observe(
            filter: filter,
            maxAge: 3600,
            cachePolicy: .cacheWithNetwork
        )
        
        var contactListEvent: NDKEvent?
        for await event in contactDataSource.events {
            contactListEvent = event
            break // Take first event
        }
        
        if let contactListEvent = contactListEvent {
            // Parse the contact list
            var contactPubkeys: Set<String> = []
            for tag in contactListEvent.tags {
                if tag.count >= 2 && tag[0] == "p" {
                    contactPubkeys.insert(tag[1])
                }
            }
            
            if !contactPubkeys.isEmpty {
                print("NostrManager - Contact list loaded with \(contactPubkeys.count) contacts")
                // Update contacts metadata data source
                self.contactsMetadataDataSource = MultipleProfilesDataSource(
                    ndk: ndk,
                    pubkeys: contactPubkeys
                )
            }
        }
    }
    
    // MARK: - Negentropy Sync
    
    /// Perform startup sync after wallet has loaded
    func performStartupSync() async {
        guard let ndk = ndk, NDKAuthManager.shared.isAuthenticated else {
            print("NostrManager - Cannot perform startup sync: NDK not ready or user not authenticated")
            return
        }
        
        // Check if we already have connected relays
        let (connectedCount, totalCount) = await ndk.getRelayConnectionSummary()
        print("NostrManager - Initial relay status: \(connectedCount)/\(totalCount) connected")
        
        if connectedCount > 0 {
            print("NostrManager - NDK is ready, proceeding with startup sync immediately")
        } else {
            print("NostrManager - No relays connected yet, waiting for first connection...")
            
            // Wait for the first relay to connect with timeout
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                throw CancellationError()
            }
            
            let observerTask = Task {
                let relayChanges = await ndk.relayChanges
                for await change in relayChanges {
                    switch change {
                    case .relayConnected(_):
                        return // Exit successfully
                    case .relayDisconnected(_):
                        continue // Keep waiting
                    case .relayAdded(_):
                        continue // Keep waiting for connection
                    case .relayRemoved(_):
                        continue // Keep waiting
                    }
                }
            }
            
            do {
                _ = try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await timeoutTask.value }
                    group.addTask { await observerTask.value }
                    
                    // Wait for first task to complete
                    try await group.next()
                    
                    // Cancel remaining tasks
                    group.cancelAll()
                }
            } catch {
                print("NostrManager - Timeout waiting for relay connections, proceeding anyway")
            }
        }
        
        print("NostrManager - Starting negentropy sync...")
        
        // The declarative data sources will automatically sync when they start observing
        // We just need to trigger the sync manually for wallet events
        await syncWalletEvents()
        
        print("NostrManager - Startup sync completed")
    }
    
    /// Sync user's wallet events (kind:7376 and 9321)
    private func syncWalletEvents() async {
        guard let ndk = ndk, let signer = ndk.signer else { return }
        
        do {
            let userPubkey = try await signer.pubkey
            print("NostrManager - Syncing wallet events for user: \(userPubkey.prefix(8))...")
            
            // Create filter for user's wallet events
            let walletEventsFilter = NDKFilter(
                authors: [userPubkey],
                kinds: [
                    EventKind.cashuSpendingHistory, // 7376
                    EventKind.cashuToken            // 9321
                ]
            )
            
            // Sync with all connected relays (receive-only for wallet security)
            let results = try await ndk.syncWithAllRelays(filter: walletEventsFilter, direction: .receive)
            
            var totalDownloaded = 0
            var totalEfficiency = 0
            for (relay, result) in results {
                totalDownloaded += result.downloadedEvents.count
                totalEfficiency += result.efficiencyRatio
                print("NostrManager - Wallet events sync on \(relay): \(result.downloadedEvents.count) new events, \(result.efficiencyRatio)% efficient")
            }
            
            let avgEfficiency = results.isEmpty ? 0 : totalEfficiency / results.count
            print("NostrManager - Wallet events sync completed: \(totalDownloaded) new events, \(avgEfficiency)% avg efficiency")
            
        } catch {
            print("NostrManager - Error syncing wallet events: \(error)")
        }
    }
    
    // MARK: - Relay Management
    
    /// Get all relays (default + user-added)
    private func getAllRelays() -> [String] {
        let userRelays = getUserAddedRelays()
        let allRelays = defaultRelays + userRelays
        return Array(Set(allRelays)) // Remove duplicates
    }
    
    /// Get user-added relays from UserDefaults
    private func getUserAddedRelays() -> [String] {
        return UserDefaults.standard.stringArray(forKey: Self.userRelaysKey) ?? []
    }
    
    /// Add a user relay and persist it
    func addUserRelay(_ relayURL: String) async {
        guard let ndk = ndk else { return }
        
        var userRelays = getUserAddedRelays()
        guard !userRelays.contains(relayURL) && !defaultRelays.contains(relayURL) else {
            print("NostrManager - Relay \(relayURL) already exists")
            return
        }
        
        // Add relay via NDK
        await ndk.addRelayAndConnect(relayURL)
        
        // Persist to UserDefaults for app restarts
        userRelays.append(relayURL)
        UserDefaults.standard.set(userRelays, forKey: Self.userRelaysKey)
        print("NostrManager - Added user relay: \(relayURL)")
        print("NostrManager - User relays now: \(userRelays)")
    }
    
    /// Remove a user relay and persist the change
    func removeUserRelay(_ relayURL: String) async {
        guard let ndk = ndk else { return }
        
        // Don't remove default relays
        guard !defaultRelays.contains(relayURL) else {
            print("NostrManager - Cannot remove default relay: \(relayURL)")
            return
        }
        
        // Remove relay via NDK
        await ndk.removeRelay(relayURL)
        
        // Update UserDefaults
        var userRelays = getUserAddedRelays()
        userRelays.removeAll(value: relayURL)
        UserDefaults.standard.set(userRelays, forKey: Self.userRelaysKey)
        print("NostrManager - Removed user relay: \(relayURL)")
        print("NostrManager - User relays now: \(userRelays)")
    }
    
    /// Get list of user-added relays (for UI display)
    var userAddedRelays: [String] {
        return getUserAddedRelays()
    }
}

enum NostrError: LocalizedError {
    case ndkNotInitialized
    case notLoggedIn
    case invalidPrivateKey
    
    var errorDescription: String? {
        switch self {
        case .ndkNotInitialized:
            return "NDK is not initialized"
        case .notLoggedIn:
            return "Not logged in to Nostr"
        case .invalidPrivateKey:
            return "Invalid private key"
        }
    }
}