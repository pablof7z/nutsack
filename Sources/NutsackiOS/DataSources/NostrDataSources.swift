import Foundation
import NDKSwift
import SwiftUI
import Combine

// MARK: - User Profile Data Source

/// Data source for user profile metadata
@MainActor
public class UserProfileDataSource: ObservableObject {
    @Published public private(set) var profile: NDKUserProfile?
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let dataSource: NDKDataSource<NDKEvent>
    
    public init(ndk: NDK, pubkey: String) {
        self.dataSource = ndk.observe(
            filter: NDKFilter(
                authors: [pubkey],
                kinds: [0]
            ),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await observeProfile()
        }
    }
    
    private func observeProfile() async {
        dataSource.$data
            .compactMap { events in
                events.sorted { $0.createdAt > $1.createdAt }.first
            }
            .map { event in
                JSONCoding.safeDecode(NDKUserProfile.self, from: event.content.data(using: .utf8) ?? Data())
            }
            .assign(to: &$profile)
        
        dataSource.$isLoading.assign(to: &$isLoading)
        dataSource.$error.assign(to: &$error)
    }
}

// MARK: - Multiple Profiles Data Source

/// Data source for multiple user profiles (e.g., for contact lists)
@MainActor
public class MultipleProfilesDataSource: ObservableObject {
    @Published public private(set) var profiles: [String: NDKUserProfile] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let dataSource: NDKDataSource<NDKEvent>
    private let pubkeys: Set<String>
    
    public init(ndk: NDK, pubkeys: Set<String>) {
        self.pubkeys = pubkeys
        self.dataSource = ndk.observe(
            filter: NDKFilter(
                authors: Array(pubkeys),
                kinds: [0]
            ),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await observeProfiles()
        }
    }
    
    private func observeProfiles() async {
        dataSource.$data
            .map { events in
                var profileDict: [String: NDKUserProfile] = [:]
                
                // Group events by author
                let eventsByAuthor = Dictionary(grouping: events) { $0.pubkey }
                
                // Get the latest profile for each author
                for (pubkey, authorEvents) in eventsByAuthor {
                    if let latestEvent = authorEvents.sorted(by: { $0.createdAt > $1.createdAt }).first,
                       let profile = JSONCoding.safeDecode(NDKUserProfile.self, from: latestEvent.content.data(using: .utf8) ?? Data()) {
                        profileDict[pubkey] = profile
                    }
                }
                
                return profileDict
            }
            .assign(to: &$profiles)
        
        dataSource.$isLoading.assign(to: &$isLoading)
        dataSource.$error.assign(to: &$error)
    }
    
    public func profile(for pubkey: String) -> NDKUserProfile? {
        profiles[pubkey]
    }
}

// MARK: - Relay Metadata Data Source

/// Data source for relay metadata (NIP-65)
@MainActor
public class RelayMetadataDataSource: ObservableObject {
    @Published public private(set) var relayMetadata: [String: RelayMetadata] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let dataSource: NDKDataSource<NDKEvent>
    
    public init(ndk: NDK, pubkeys: [String]) {
        self.dataSource = ndk.observe(
            filter: NDKFilter(
                authors: pubkeys,
                kinds: [EventKind.relayList]
            ),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await observeRelayMetadata()
        }
    }
    
    private func observeRelayMetadata() async {
        dataSource.$data
            .map { events in
                var metadataDict: [String: RelayMetadata] = [:]
                
                // Group events by author
                let eventsByAuthor = Dictionary(grouping: events) { $0.pubkey }
                
                // Get the latest metadata for each author
                for (pubkey, authorEvents) in eventsByAuthor {
                    if let latestEvent = authorEvents.sorted(by: { $0.createdAt > $1.createdAt }).first {
                        let metadata = self.parseRelayMetadata(from: latestEvent)
                        metadataDict[pubkey] = metadata
                    }
                }
                
                return metadataDict
            }
            .assign(to: &$relayMetadata)
        
        dataSource.$isLoading.assign(to: &$isLoading)
        dataSource.$error.assign(to: &$error)
    }
    
    private func parseRelayMetadata(from event: NDKEvent) -> RelayMetadata {
        var writeRelays: [String] = []
        var readRelays: [String] = []
        
        for tag in event.tags {
            guard tag.count >= 2, tag[0] == "r" else { continue }
            
            let relay = tag[1]
            
            if tag.count == 2 {
                // No marker specified, treat as both read and write
                writeRelays.append(relay)
                readRelays.append(relay)
            } else if tag.count >= 3 {
                let marker = tag[2]
                if marker == "write" {
                    writeRelays.append(relay)
                } else if marker == "read" {
                    readRelays.append(relay)
                }
            }
        }
        
        return RelayMetadata(
            pubkey: event.pubkey,
            writeRelays: writeRelays,
            readRelays: readRelays,
            lastUpdated: event.createdAt
        )
    }
}

// MARK: - Generic Event Data Source

/// Generic data source for any Nostr event type
@MainActor
public class GenericEventDataSource: ObservableObject {
    @Published public private(set) var events: [NDKEvent] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let dataSource: NDKDataSource<NDKEvent>
    
    public init(
        ndk: NDK,
        filter: NDKFilter,
        sortDescending: Bool = true
    ) {
        self.dataSource = ndk.observe(
            filter: filter,
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await observeEvents(sortDescending: sortDescending)
        }
    }
    
    private func observeEvents(sortDescending: Bool) async {
        dataSource.$data
            .map { events in
                sortDescending
                    ? events.sorted { $0.createdAt > $1.createdAt }
                    : events.sorted { $0.createdAt < $1.createdAt }
            }
            .assign(to: &$events)
        
        dataSource.$isLoading.assign(to: &$isLoading)
        dataSource.$error.assign(to: &$error)
    }
}

// MARK: - Supporting Types

public struct RelayMetadata {
    public let pubkey: String
    public let writeRelays: [String]
    public let readRelays: [String]
    public let lastUpdated: Timestamp
}