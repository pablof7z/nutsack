import Foundation
import NDKSwift
import SwiftUI
import Observation

@MainActor
@Observable
class NostrManager: NDKNostrManager {
    // MARK: - Configuration Overrides

    override var defaultRelays: [String] {
        [RelayConstants.primal]
    }

    override var userRelaysKey: String {
        "UserAddedRelays"
    }

    override var clientTagConfig: NDKClientTagConfig? {
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

    override var sessionConfiguration: NDKSessionConfiguration {
        NDKSessionConfiguration(
            dataRequirements: [.followList, .muteList],
            preloadStrategy: .progressive
        )
    }

    // MARK: - App-specific initialization

    init(from: String) {
        print("🏚️ [NostrManager] Initializing...", from)
        super.init()
    }

    // MARK: - App-specific methods

    /// Create a new account with Nutsack-specific profile defaults
    public func createNutsackAccount(displayName: String, about: String? = nil, picture: String? = nil) async throws -> NDKSession {
        print("🏚️ [NostrManager] createNutsackAccount() called with displayName: \(displayName)")

        // Use parent implementation with Nutsack defaults
        let session = try await createNewAccount(
            displayName: displayName,
            about: about ?? "Nutsack wallet user",
            picture: picture
        )

        print("🏚️ [NostrManager] createNutsackAccount() completed successfully")
        return session
    }

    // MARK: - Negentropy Sync

    /// Perform startup sync after wallet has loaded
    func performStartupSync() async {
        guard let ndk = ndk, NDKAuthManager.shared.hasActiveSession else {
            print("NostrManager - Cannot perform startup sync: NDK not ready or user not authenticated")
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
}

// Use NDKError from NDKSwift instead of creating custom errors
typealias NostrError = NDKError
