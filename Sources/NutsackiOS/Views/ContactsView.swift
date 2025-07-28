import SwiftUI
import NDKSwift

struct ContactsView: View {
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager
    @Binding var navigationDestination: WalletView.WalletDestination?
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var resolvedUser: NDKUser?
    @State private var isResolving = false
    @State private var showQRScanner = false
    @State private var contacts: [String] = []
    
    // Default users to show when no contacts
    private let defaultUsers = [
        // Pablo Fernandez
        try! Bech32.pubkey(from: "npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft"),
        // Jack Dorsey
        try! Bech32.pubkey(from: "npub1sg6plzptd64u62a878hep2kev88swjh3tw00gjsfl8f237lmu63q0uf63m"),
        // Calle (Cashu creator)
        try! Bech32.pubkey(from: "npub12rv5lskctqxxs2c8rf2zlzc7xx3qpvzs3w4etgemauy9thegr43sf485vg")
    ]
    
    
    var filteredContacts: [String] {
        if searchText.isEmpty {
            return contacts
        }
        
        return contacts.filter { pubkey in
            // Filter by pubkey/npub
            let npub = NDKUser(pubkey: pubkey).npub
            if npub.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Also check profile data if available
            if let profileDataSource = nostrManager.contactsMetadataDataSource,
               let profile = profileDataSource.profile(for: pubkey) {
                if let name = profile.name, name.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let displayName = profile.displayName, displayName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let nip05 = profile.nip05, nip05.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
            }
            
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Search input section
                VStack(spacing: 12) {
                    HStack {
                        TextField("npub, NIP-05, or hex pubkey", text: $searchText)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                        
                        #if os(iOS)
                        Button(action: { showQRScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                    .padding(.horizontal)
                    
                    if isResolving {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Resolving...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    } else if let user = resolvedUser {
                        NavigationLink(value: user.pubkey) {
                            HStack {
                                // Profile picture
                                UserProfilePicture(user: user)
                                
                                VStack(alignment: .leading) {
                                    UserDisplayName(user: user)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    UserNIP05(user: user)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "bolt.heart.fill")
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
                
                // Contacts list
                List {
                    if contacts.isEmpty {
                        Section {
                            ForEach(defaultUsers, id: \.self) { pubkey in
                                ContactRow(pubkey: pubkey)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggested Contacts")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Follow people on Nostr to see your contacts here")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .textCase(nil)
                            .padding(.bottom, 4)
                        }
                    } else {
                        ForEach(filteredContacts, id: \.self) { pubkey in
                            ContactRow(pubkey: pubkey)
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(nostrManager)
                    .environment(walletManager)
            }
            .refreshable {
                // Data sources handle refreshing automatically
            }
            .onChange(of: searchText) { _, _ in
                resolveSearchInput()
            }
            #if os(iOS)
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedCode in
                    searchText = scannedCode
                    showQRScanner = false
                }
            }
            #endif
        .navigationDestination(for: String.self) { pubkey in
            NutzapView(recipientPubkey: pubkey)
                .environment(nostrManager)
                .environment(walletManager)
        }
        .task {
            await loadContacts()
        }
    }
    
    private func resolveSearchInput() {
        // Clear previous resolution if search text is empty or too short
        guard !searchText.isEmpty else {
            resolvedUser = nil
            return
        }
        
        // Only resolve if it looks like a pubkey, npub, or NIP-05
        guard searchText.starts(with: "npub1") || 
              HexValidator.isValid32ByteHex(searchText) || 
              searchText.contains("@") else {
            resolvedUser = nil
            return
        }
        
        isResolving = true
        
        Task {
            do {
                guard let ndk = nostrManager.ndk else {
                    throw NostrError.ndkNotInitialized
                }
                
                var pubkey: String?
                
                // Try to parse as npub
                if searchText.starts(with: "npub1") {
                    pubkey = try? Bech32.pubkey(from: searchText)
                }
                // Try as hex pubkey
                else if HexValidator.isValid32ByteHex(searchText) {
                    pubkey = searchText
                }
                // Try as NIP-05
                else if searchText.contains("@") {
                    let user = try await NDKUser.fromNip05(searchText, ndk: ndk)
                    pubkey = user.pubkey
                }
                
                if let pubkey = pubkey {
                    let user = NDKUser(pubkey: pubkey)
                    
                    await MainActor.run {
                        resolvedUser = user
                        isResolving = false
                    }
                } else {
                    await MainActor.run {
                        resolvedUser = nil
                        isResolving = false
                    }
                }
            } catch {
                await MainActor.run {
                    resolvedUser = nil
                    isResolving = false
                }
            }
        }
    }
    
    @MainActor
    private func loadContacts() async {
        guard let ndk = nostrManager.ndk else { return }
        
        do {
            // Get user's contact list
            guard let signer = ndk.signer else { return }
            let pubkey = try await signer.pubkey
            
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
                var contactPubkeys: [String] = []
                for tag in contactListEvent.tags {
                    if tag.count >= 2 && tag[0] == "p" {
                        contactPubkeys.append(tag[1])
                    }
                }
                
                // Update contacts
                contacts = contactPubkeys
            }
        } catch {
            print("Failed to load contacts: \(error)")
        }
    }
}

struct ContactRow: View {
    let pubkey: String
    @Environment(NostrManager.self) private var nostrManager
    
    private var user: NDKUser {
        NDKUser(pubkey: pubkey)
    }
    
    var body: some View {
        NavigationLink(value: pubkey) {
            HStack {
                // Profile picture
                UserProfilePicture(pubkey: pubkey, size: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    UserDisplayName(pubkey: pubkey)
                        .font(.headline)
                        .lineLimit(1)
                    
                    UserNIP05(pubkey: pubkey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}