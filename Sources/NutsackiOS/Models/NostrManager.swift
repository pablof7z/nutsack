import Foundation
import NDKSwift
import SwiftUI

@MainActor
class NostrManager: ObservableObject {
    @Published private(set) var isInitialized = false
    let ndk: NDK
    var cache: NDKCache? {
        return ndk.cache
    }
    private var authManager: NDKAuthManager?
    private var _profileManager: NDKProfileManager?
    var profileManager: NDKProfileManager? {
        return _profileManager
    }
    
    // MARK: - Configuration

    var defaultRelays: [String] {
        [RelayConstants.primal]
    }

    var appRelaysKey: String {
        "NutsackAppAddedRelays"
    }

    var clientTagConfig: NDKClientTagConfig? {
        NDKClientTagConfig(
            name: "Nutsack",
            relay: RelayConstants.primal,
            autoTag: true,
            excludedKinds: [
                EventKind.encryptedDirectMessage,
                EventKind.cashuSpendingHistory,
                EventKind.cashuToken
            ]
        )
    }

    var sessionConfiguration: NDKSessionConfiguration {
        NDKSessionConfiguration(
            dataRequirements: [.followList, .muteList],
            preloadStrategy: .progressive
        )
    }

    // MARK: - App-specific initialization

    init(from: String) {
        print("🏚️ [NostrManager] Initializing...", from)
        
        // Initialize NDK synchronously
        self.ndk = NDK(cache: nil)
        
        Task {
            await setupAsync()
        }
    }
    
    func setupAsync() async {
        // Initialize SQLite cache and update NDK's cache
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dbPath = documentsPath.appendingPathComponent("nutsack_cache.db").path
            if let sqliteCache = try? await NDKSQLiteCache(path: dbPath) {
                // Update NDK's cache to use SQLite
                ndk.cache = sqliteCache
            }
        }
        
        // Add default relays
        for relay in defaultRelays {
            await ndk.addRelay(relay)
        }
        
        // Connect to relays
        await ndk.connect()
        
        // Initialize auth manager
        authManager = NDKAuthManager(ndk: ndk)
        await authManager?.initialize()
        
        // Initialize profile manager
        _profileManager = NDKProfileManager(ndk: ndk)
        
        // If authenticated, restore session
        if let authManager = authManager, authManager.isAuthenticated, let signer = authManager.activeSigner {
            do {
                try await ndk.startSession(signer: signer, config: sessionConfiguration)
                print("🔍 [NostrManager] Restored session for user: \(authManager.activePubkey?.prefix(8) ?? "unknown")")
            } catch {
                print("🔍 [NostrManager] Failed to restore session: \(error)")
                // Don't clear the session here, let user manually logout if needed
            }
        } else {
            print("🔍 [NostrManager] No existing session to restore")
        }
        
        isInitialized = true
    }

    // MARK: - App-specific methods

    /// Create a new account with Nutsack-specific profile defaults
    public func createNutsackAccount(displayName: String, about: String? = nil, picture: String? = nil) async throws {
        print("🏚️ [NostrManager] createNutsackAccount() called with displayName: \(displayName)")

        // Generate new key
        let signer = try NDKPrivateKeySigner.generate()
        
        // Start NDK session directly
        if let authManager = authManager {
            print("Starting session")
            
            // Add session to auth manager for persistence
            _ = try await authManager.addSession(signer, requiresBiometric: false)
            
            try await ndk.startSession(signer: signer, config: sessionConfiguration)
            print("Finish session")
        }
        
        // Create profile metadata content directly
        var profileDict: [String: String] = [:]
        profileDict["name"] = displayName
        profileDict["about"] = about ?? "Nutsack wallet user"
        if let picture = picture {
            profileDict["picture"] = picture
        }
        let metadataData = try JSONSerialization.data(withJSONObject: profileDict, options: [])
        let metadataString = String(data: metadataData, encoding: .utf8) ?? "{}"
        
        let profileEvent = try await NDKEventBuilder(ndk: ndk)
            .kind(0)
            .content(metadataString)
            .build(signer: ndk.signer!)
        
        _ = try await ndk.publish(profileEvent)

        print("🏚️ [NostrManager] createNutsackAccount() completed successfully")
    }
    
    /// Import an existing account
    public func importAccount(signer: NDKPrivateKeySigner, displayName: String? = nil) async throws {
        print("🏚️ [NostrManager] importAccount() called")
        
        // Start NDK session
        if let authManager = authManager {
            print("Starting session for import")
            
            // Add session to auth manager for persistence
            _ = try await authManager.addSession(signer, requiresBiometric: false)
            
            try await ndk.startSession(signer: signer, config: sessionConfiguration)
            print("Finish session for import")
        }
        
        print("🏚️ [NostrManager] importAccount() completed successfully")
    }

    // MARK: - Negentropy Sync

    /// Perform startup sync after wallet has loaded
    func performStartupSync() async {
        guard ndk.signer != nil else {
            print("NostrManager - Cannot perform startup sync: User not authenticated")
            return
        }

        // Check if we already have connected relays
        let (connectedCount, totalCount) = await ndk.getRelayConnectionSummary()
        print("NostrManager - Initial relay status: \(connectedCount)/\(totalCount) connected")

        if connectedCount == 0 {
            print("NostrManager - No relays connected yet, waiting for first connection...")

            // Wait for the first relay to connect with timeout
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                throw CancellationError()
            }

            let observerTask = Task {
                let relayChanges = await ndk.relayChanges
                for await change in relayChanges {
                    if case .relayConnected = change {
                        return // Exit successfully
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
        await syncWalletEvents()
        print("NostrManager - Startup sync completed")
    }

    /// Sync user's wallet events (kind:7376 and 9321)
    private func syncWalletEvents() async {
        guard let signer = ndk.signer else { return }

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
    
    var isAuthenticated: Bool {
        return authManager?.isAuthenticated ?? false
    }
    
    func logout() async {
        // Remove all sessions from auth manager (complete logout)
        if let authManager = authManager {
            for session in authManager.availableSessions {
                try? await authManager.removeSession(session)
            }
            authManager.logout()
        }
        
        // Clear signer from NDK
        ndk.signer = nil
    }
    
    // MARK: - Relay Management
    
    func addRelay(_ url: String) async {
        await ndk.addRelay(url)
        
        // Save to user defaults
        var savedRelays = UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
        if !savedRelays.contains(url) {
            savedRelays.append(url)
            UserDefaults.standard.set(savedRelays, forKey: appRelaysKey)
        }
    }
    
    func removeRelay(_ url: String) async {
        await ndk.removeRelay(url)
        
        // Remove from user defaults
        var savedRelays = UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
        savedRelays.removeAll { $0 == url }
        UserDefaults.standard.set(savedRelays, forKey: appRelaysKey)
    }
    
    var userAddedRelays: [String] {
        return UserDefaults.standard.stringArray(forKey: appRelaysKey) ?? []
    }
}

// Use NDKError from NDKSwift instead of creating custom errors
typealias NostrError = NDKError
