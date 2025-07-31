import Foundation
import NDKSwift
import SwiftUI
import Combine

// MARK: - Mint Discovery Data Source

/// Data source for discovering Cashu mints
@MainActor
public class MintDiscoveryDataSource: ObservableObject {
    @Published public private(set) var discoveredMints: [DiscoveredMint] = []
    
    private let ndk: NDK
    private let followedPubkeys: [String]
    private var streamTask: Task<Void, Never>?
    private var mintMap: [String: DiscoveredMint] = [:]
    
    public init(ndk: NDK, followedPubkeys: [String] = []) {
        self.ndk = ndk
        self.followedPubkeys = followedPubkeys
    }
    
    public func startStreaming() {
        // Cancel any existing task
        streamTask?.cancel()
        
        streamTask = Task { @MainActor in
            // Stream mint announcements
            let announcementTask = Task {
                let announcementDataSource = ndk.subscribe(
                    filter: NDKFilter(kinds: [EventKind.cashuMintAnnouncement]),
                    maxAge: 300,  // 5 minute cache for discovered mints
                    cachePolicy: .cacheWithNetwork
                )
                
                for await event in announcementDataSource.events {
                    if Task.isCancelled { break }
                    await processMintAnnouncement(event)
                }
            }
            
            // Stream mint recommendations
            let recommendationTask = Task {
                let recommendationDataSource = ndk.subscribe(
                    filter: NDKFilter(
                        authors: followedPubkeys.isEmpty ? nil : followedPubkeys,
                        kinds: [EventKind.mintAnnouncement],
                        tags: ["k": Set([String(EventKind.mintAnnouncement)])]
                    ),
                    maxAge: 300,  // 5 minute cache
                    cachePolicy: .cacheWithNetwork
                )
                
                for await event in recommendationDataSource.events {
                    if Task.isCancelled { break }
                    await processMintRecommendation(event)
                }
            }
            
            // Keep streaming until cancelled
            await announcementTask.value
            await recommendationTask.value
        }
    }
    
    public func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    @MainActor
    private func processMintAnnouncement(_ event: NDKEvent) {
        guard let mintUrl = event.tags.first(where: { $0.first == "u" })?.dropFirst().first else {
            return
        }

        // Parse the content as JSON according to NIP-87
        var mintName = ""
        var mintDescription: String?
        var mintIconURL: String?
        var mintWebsite: String?
        var mintContact: String?

        if !event.content.isEmpty,
           let contentData = event.content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
            // Extract metadata from JSON content
            mintName = json["name"] as? String ?? ""
            mintDescription = json["description"] as? String
            mintIconURL = json["picture"] as? String ?? json["icon"] as? String
            mintWebsite = json["website"] as? String
            mintContact = json["contact"] as? String ?? json["email"] as? String
        }

        // Fallback to mint URL if no name provided
        if mintName.isEmpty {
            if let url = URL(string: mintUrl), let host = url.host {
                mintName = host
            } else {
                mintName = "Unknown Mint"
            }
        }

        let mint = DiscoveredMint(
            url: mintUrl,
            name: mintName,
            announcedBy: event.pubkey,
            announcementId: event.id,
            announcementCreatedAt: event.createdAt,
            recommendedBy: mintMap[mintUrl]?.recommendedBy ?? [],
            description: mintDescription,
            pubkey: event.tags.first(where: { $0.first == "p" })?.dropFirst().first,
            metadata: MintMetadata(
                name: mintName,
                description: mintDescription,
                iconURL: mintIconURL,
                website: mintWebsite,
                contact: mintContact
            )
        )

        mintMap[mintUrl] = mint
        updateDiscoveredMints()
    }
    
    @MainActor
    private func processMintRecommendation(_ event: NDKEvent) {
        guard let mintUrl = event.tags.first(where: { $0.first == "u" })?.dropFirst().first else {
            return
        }

        if var existingMint = mintMap[mintUrl] {
            if !existingMint.recommendedBy.contains(event.pubkey) {
                existingMint.recommendedBy.append(event.pubkey)
                mintMap[mintUrl] = existingMint
            }
        } else {
            let mint = DiscoveredMint(
                url: mintUrl,
                name: event.content.isEmpty ? "Unknown Mint" : event.content,
                announcedBy: nil,
                announcementId: nil,
                announcementCreatedAt: nil,
                recommendedBy: [event.pubkey],
                description: nil,
                pubkey: nil
            )
            mintMap[mintUrl] = mint
        }
        
        updateDiscoveredMints()
    }
    
    @MainActor
    private func updateDiscoveredMints() {
        discoveredMints = Array(mintMap.values).sorted { mint1, mint2 in
            // Sort by recommendation count first
            if mint1.recommendedBy.count != mint2.recommendedBy.count {
                return mint1.recommendedBy.count > mint2.recommendedBy.count
            }
            // Then by announcement date
            if let date1 = mint1.announcementCreatedAt,
               let date2 = mint2.announcementCreatedAt {
                return date1 > date2
            }
            return mint1.name < mint2.name
        }
    }
}

// MARK: - Supporting Types

public struct MintMetadata {
    public let name: String
    public let description: String?
    public let iconURL: String?
    public let website: String?
    public let contact: String?

    public init(
        name: String,
        description: String? = nil,
        iconURL: String? = nil,
        website: String? = nil,
        contact: String? = nil
    ) {
        self.name = name
        self.description = description
        self.iconURL = iconURL
        self.website = website
        self.contact = contact
    }
}

public struct DiscoveredMint: Identifiable {
    public let id: String
    public let url: String
    public let name: String
    public let announcedBy: String?
    public let announcementId: String?
    public let announcementCreatedAt: Timestamp?
    public var recommendedBy: [String]
    public let description: String?
    public let pubkey: String?
    public var mintInfo: NDKMintInfo?
    public let metadata: MintMetadata?

    public init(
        url: String,
        name: String,
        announcedBy: String? = nil,
        announcementId: String? = nil,
        announcementCreatedAt: Timestamp? = nil,
        recommendedBy: [String] = [],
        description: String? = nil,
        pubkey: String? = nil,
        mintInfo: NDKMintInfo? = nil,
        metadata: MintMetadata? = nil
    ) {
        self.id = url
        self.url = url
        self.name = name
        self.announcedBy = announcedBy
        self.announcementId = announcementId
        self.announcementCreatedAt = announcementCreatedAt
        self.recommendedBy = recommendedBy
        self.description = description
        self.pubkey = pubkey
        self.mintInfo = mintInfo
        self.metadata = metadata
    }
}
