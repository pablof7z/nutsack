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
        "fcb220c3af11b08325c8ad74c37b2ab5b9e665e3c39076c20c8d36c5b5c3de78",
        // Jack Dorsey
        "82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2",
        // Calle (Cashu creator)
        "50d94fc2d8580c682b071a542f8b1e31a200b0508bab95a33bef0855df281d63"
    ]

    var filteredContacts: [String] {
        if searchText.isEmpty {
            return contacts
        }

        var filtered: [String] = []
        for pubkey in contacts {
            // Filter by pubkey/npub
            let npub = NDKUser(pubkey: pubkey).npub
            if npub.localizedCaseInsensitiveContains(searchText) {
                filtered.append(pubkey)
                continue
            }

            // Profile search disabled for now - would need async implementation
            // TODO: Implement profile-based search with declarative data sources
        }
        return filtered
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
                QRScannerView(
                    onScan: { scannedCode in
                        searchText = scannedCode
                        showQRScanner = false
                    },
                    onDismiss: {
                        showQRScanner = false
                    }
                )
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
                    throw NDKError.notConfigured("NDK not initialized")
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
