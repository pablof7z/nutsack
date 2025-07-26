import Foundation
import NDKSwift

/// Manager for discovering Cashu mints using NIP-87
@MainActor
class MintDiscoveryManager {
    private let ndk: NDK
    
    init(ndk: NDK) {
        self.ndk = ndk
    }
    
    /// Validates a mint URL to ensure it's a proper HTTP/HTTPS URL
    private func isValidMintURL(_ urlString: String) -> Bool {
        // Trim whitespace
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a valid URL
        guard let url = URL(string: trimmed) else { return false }
        
        // Must have a scheme
        guard let scheme = url.scheme?.lowercased() else { return false }
        
        // Only allow http or https
        guard scheme == "http" || scheme == "https" else { return false }
        
        // Must have a host
        guard let host = url.host, !host.isEmpty else { return false }
        
        // Check for common invalid patterns
        // No spaces in the URL
        if trimmed.contains(" ") { return false }
        
        // Host should be a valid domain
        let hostPattern = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#
        let hostRegex = try? NSRegularExpression(pattern: hostPattern, options: .caseInsensitive)
        let hostRange = NSRange(location: 0, length: host.utf16.count)
        
        if let regex = hostRegex {
            if regex.firstMatch(in: host, options: [], range: hostRange) == nil {
                return false
            }
        }
        
        return true
    }
    
    /// Discover mints through NIP-87 announcements and recommendations with streaming updates
    func discoverMintsStream() -> AsyncStream<[DiscoveredMint]> {
        AsyncStream { continuation in
            Task {
                var discoveredMints: [DiscoveredMint] = []
                var mintsByURL: [URL: DiscoveredMint] = [:]
                
                // Subscribe to mint announcements (kind: 38172)
                let announcementFilter = NDKFilter(
                    kinds: [EventKind.cashuMintAnnouncement],
                    limit: 100
                )
                
                // Use declarative data source for announcements
                let announcementDataSource = ndk.observe(
                    filter: announcementFilter,
                    maxAge: 0, // Real-time updates
                    cachePolicy: .cacheWithNetwork
                )
                
                // Subscribe to recommendations (kind: 38000)
                let recommendationFilter = NDKFilter(
                    kinds: [EventKind.mintAnnouncement],
                    limit: 100
                )
                
                // Use declarative data source for recommendations
                let recommendationDataSource = ndk.observe(
                    filter: recommendationFilter,
                    maxAge: 0, // Real-time updates
                    cachePolicy: .cacheWithNetwork
                )
                
                // Process announcements as they stream in
                Task {
                    for await announcementEvent in announcementDataSource.events {
                            let announcement = NDKCashuMintAnnouncement(event: announcementEvent)
                        
                        if let mintURL = announcement.mintURL,
                           isValidMintURL(mintURL),
                           let url = URL(string: mintURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            
                            let discoveredMint = DiscoveredMint(
                                url: url.absoluteString,
                                name: announcement.name ?? url.host ?? "Unknown Mint",
                                announcedBy: announcement.event.pubkey,
                                announcementId: announcementEvent.id,
                                announcementCreatedAt: announcementEvent.createdAt,
                                recommendedBy: [],
                                description: announcement.description,
                                pubkey: announcement.event.pubkey
                            )
                            
                            mintsByURL[url] = discoveredMint
                            
                            // Rebuild and sort the array
                            discoveredMints = Array(mintsByURL.values).sorted { first, second in
                                if !first.recommendedBy.isEmpty && second.recommendedBy.isEmpty {
                                    return true
                                } else if first.recommendedBy.isEmpty && !second.recommendedBy.isEmpty {
                                    return false
                                }
                                let firstDate = first.announcementCreatedAt ?? 0
                                let secondDate = second.announcementCreatedAt ?? 0
                                return firstDate > secondDate
                            }
                            
                            continuation.yield(discoveredMints)
                        }
                    }
                }
                
                // Process recommendations as they stream in
                Task {
                    for await recommendationEvent in recommendationDataSource.events {
                        let recommendation = NDKMintRecommendation(event: recommendationEvent)
                        
                        if let mintURL = recommendation.mintURL,
                           isValidMintURL(mintURL),
                           let url = URL(string: mintURL.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            
                            if var existingMint = mintsByURL[url] {
                                // Update existing mint with recommendation
                                if !existingMint.recommendedBy.contains(recommendationEvent.pubkey) {
                                    existingMint.recommendedBy.append(recommendationEvent.pubkey)
                                }
                                mintsByURL[url] = existingMint
                            } else {
                                // Create new mint from recommendation only
                                let discoveredMint = DiscoveredMint(
                                    url: url.absoluteString,
                                    name: url.host ?? "Unknown Mint",
                                    announcedBy: nil,
                                    announcementId: nil,
                                    announcementCreatedAt: nil,
                                    recommendedBy: [recommendationEvent.pubkey],
                                    description: recommendation.reason,
                                    pubkey: nil
                                )
                                mintsByURL[url] = discoveredMint
                            }
                            
                            // Rebuild and sort the array
                            discoveredMints = Array(mintsByURL.values).sorted { first, second in
                                if !first.recommendedBy.isEmpty && second.recommendedBy.isEmpty {
                                    return true
                                } else if first.recommendedBy.isEmpty && !second.recommendedBy.isEmpty {
                                    return false
                                }
                                let firstDate = first.announcementCreatedAt ?? 0
                                let secondDate = second.announcementCreatedAt ?? 0
                                return firstDate > secondDate
                            }
                            
                            continuation.yield(discoveredMints)
                        }
                    }
                }
                
                // Clean up on cancellation
                continuation.onTermination = { @Sendable _ in
                    // Data sources clean up automatically
                }
            }
        }
    }
}

// DiscoveredMint is now defined in WalletDataSources.swift