import Foundation
import NDKSwift
import SwiftUI
import Combine

// MARK: - Mint Discovery Data Source

/// Data source for discovering Cashu mints
@MainActor
public class MintDiscoveryDataSource: ObservableObject {
    @Published public private(set) var discoveredMints: [DiscoveredMint] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let announcementDataSource: NDKDataSource<NDKEvent>
    private let recommendationDataSource: NDKDataSource<NDKEvent>
    private var cancellables = Set<AnyCancellable>()
    
    public init(ndk: NDK, followedPubkeys: [String] = []) {
        // Mint announcements (kind: 38172)
        self.announcementDataSource = ndk.observe(
            filter: NDKFilter(kinds: [EventKind.cashuMintAnnouncement]),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        // Mint recommendations (kind: 38000)
        self.recommendationDataSource = ndk.observe(
            filter: NDKFilter(
                authors: followedPubkeys.isEmpty ? nil : followedPubkeys,
                kinds: [EventKind.mintAnnouncement]
            ),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await startObserving()
        }
    }
    
    private func startObserving() async {
        // Combine announcements and recommendations
        Publishers.CombineLatest(
            announcementDataSource.$data,
            recommendationDataSource.$data
        )
        .map { [weak self] announcements, recommendations in
            self?.processMintsFromEvents(
                announcements: announcements,
                recommendations: recommendations
            ) ?? []
        }
        .sink { [weak self] discoveredMints in
            self?.discoveredMints = discoveredMints
        }
        .store(in: &cancellables)
        
        // Combine loading states
        Publishers.CombineLatest(
            announcementDataSource.$isLoading,
            recommendationDataSource.$isLoading
        )
        .map { $0 || $1 }
        .sink { [weak self] isLoading in
            self?.isLoading = isLoading
        }
        .store(in: &cancellables)
    }
    
    private func processMintsFromEvents(
        announcements: [NDKEvent],
        recommendations: [NDKEvent]
    ) -> [DiscoveredMint] {
        var mintMap: [String: DiscoveredMint] = [:]
        
        // Process mint announcements
        for event in announcements {
            guard let mintUrl = event.tags.first(where: { $0.first == "u" })?.dropFirst().first else {
                continue
            }
            
            let mint = DiscoveredMint(
                url: mintUrl,
                name: event.content,
                announcedBy: event.pubkey,
                announcementId: event.id,
                announcementCreatedAt: event.createdAt,
                recommendedBy: [],
                description: event.tags.first(where: { $0.first == "d" })?.dropFirst().first,
                pubkey: event.tags.first(where: { $0.first == "p" })?.dropFirst().first
            )
            
            mintMap[mintUrl] = mint
        }
        
        // Process mint recommendations
        for event in recommendations {
            guard let mintUrl = event.tags.first(where: { $0.first == "u" })?.dropFirst().first else {
                continue
            }
            
            if var existingMint = mintMap[mintUrl] {
                existingMint.recommendedBy.append(event.pubkey)
                mintMap[mintUrl] = existingMint
            } else {
                let mint = DiscoveredMint(
                    url: mintUrl,
                    name: event.content,
                    announcedBy: nil,
                    announcementId: nil,
                    announcementCreatedAt: nil,
                    recommendedBy: [event.pubkey],
                    description: nil,
                    pubkey: nil
                )
                mintMap[mintUrl] = mint
            }
        }
        
        return Array(mintMap.values).sorted { mint1, mint2 in
            // Sort by recommendation count first
            if mint1.recommendedBy.count != mint2.recommendedBy.count {
                return mint1.recommendedBy.count > mint2.recommendedBy.count
            }
            // Then by announcement date
            if let date1 = mint1.announcementCreatedAt,
               let date2 = mint2.announcementCreatedAt {
                return date1 > date2
            }
            return false
        }
    }
}

// MARK: - Wallet Settings Data Source

/// Data source for wallet-specific settings (NIP-78)
@MainActor
public class WalletSettingsDataSource: ObservableObject {
    @Published public private(set) var settings: WalletSettings?
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let dataSource: NDKDataSource<NDKEvent>
    private var cancellables = Set<AnyCancellable>()
    
    public init(ndk: NDK, pubkey: String) {
        self.dataSource = ndk.observe(
            filter: NDKFilter(
                authors: [pubkey],
                kinds: [EventKind.applicationSpecificData],
                tags: ["d": ["nutsack"]]
            ),
            maxAge: 0,  // Real-time updates
            cachePolicy: .cacheWithNetwork
        )
        
        Task {
            await observeSettings()
        }
    }
    
    private func observeSettings() async {
        dataSource.$data
            .compactMap { events in
                events.sorted { $0.createdAt > $1.createdAt }.first
            }
            .map { event in
                self.parseWalletSettings(from: event)
            }
            .sink { [weak self] settings in
                self?.settings = settings
            }
            .store(in: &cancellables)
        
        dataSource.$isLoading
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
            
        dataSource.$error
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)
    }
    
    private func parseWalletSettings(from event: NDKEvent) -> WalletSettings? {
        guard let data = event.content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return WalletSettings(
            defaultMintUrl: json["defaultMintUrl"] as? String,
            swapToDefaultMint: json["swapToDefaultMint"] as? Bool ?? false,
            autoBackup: json["autoBackup"] as? Bool ?? true,
            nutzapSettings: parseNutzapSettings(json["nutzap"] as? [String: Any])
        )
    }
    
    private func parseNutzapSettings(_ json: [String: Any]?) -> NutzapSettings {
        guard let json = json else {
            return NutzapSettings()
        }
        
        return NutzapSettings(
            defaultMintUrl: json["defaultMintUrl"] as? String,
            p2pkLocked: json["p2pkLocked"] as? Bool ?? true,
            includeRefundSecrets: json["includeRefundSecrets"] as? Bool ?? false
        )
    }
}

// MARK: - Supporting Types

public struct WalletSettings {
    public let defaultMintUrl: String?
    public let swapToDefaultMint: Bool
    public let autoBackup: Bool
    public let nutzapSettings: NutzapSettings
}

public struct NutzapSettings {
    public let defaultMintUrl: String?
    public let p2pkLocked: Bool
    public let includeRefundSecrets: Bool
    
    public init(
        defaultMintUrl: String? = nil,
        p2pkLocked: Bool = true,
        includeRefundSecrets: Bool = false
    ) {
        self.defaultMintUrl = defaultMintUrl
        self.p2pkLocked = p2pkLocked
        self.includeRefundSecrets = includeRefundSecrets
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
    
    public init(
        url: String,
        name: String,
        announcedBy: String? = nil,
        announcementId: String? = nil,
        announcementCreatedAt: Timestamp? = nil,
        recommendedBy: [String] = [],
        description: String? = nil,
        pubkey: String? = nil,
        mintInfo: NDKMintInfo? = nil
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
    }
}