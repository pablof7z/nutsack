import SwiftUI
import NDKSwift
import CashuSwift

struct WalletSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager
    @EnvironmentObject private var appState: AppState

    @State private var mints: [MintInfo] = []
    @State private var relays: [String] = []
    @State private var hasWalletInfo = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAddMintSheet = false
    @State private var showAddRelaySheet = false
    @State private var showDiscoveredMints = false
    @State private var discoveryTask: Task<Void, Never>?
    
    // Wallet warning section
    @ViewBuilder
    private var walletWarningSection: some View {
        if !hasWalletInfo && walletManager.wallet != nil {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Wallet not published - tap to sync across devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await saveSettings() }
                }
            }
        }
    }
    
    // Mints section
    @ViewBuilder
    private var mintsSection: some View {
        Section {
            if mints.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Mints Configured",
                        systemImage: "building.columns",
                        description: Text("Add mints to start using ecash")
                    )
                    .scaleEffect(0.85)

                    HStack(spacing: 12) {
                        Button(action: { showAddMintSheet = true }) {
                            Label("Add URL", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        Button(action: discoverMints) {
                            Label("Discover", systemImage: "sparkle.magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
            } else {
                ForEach(mints, id: \.url.absoluteString) { mint in
                    NavigationLink(destination: MintDetailView(mintURL: mint.url.absoluteString)) {
                        MintSettingsRow(mintInfo: mint) {
                            mints.removeAll { $0.url == mint.url }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
            }
        } header: {
            mintsSectionHeader
        }
    }
    
    // Mints section header
    @ViewBuilder
    private var mintsSectionHeader: some View {
        HStack {
            Text("MINTS")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.none)
            Spacer()
            Menu {
                Button(action: { showAddMintSheet = true }) {
                    Label("Add by URL", systemImage: "link")
                }
                Button(action: discoverMints) {
                    Label("Discover Mints", systemImage: "sparkle.magnifyingglass")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    // Relays section
    @ViewBuilder
    private var relaysSection: some View {
        Section {
            if relays.isEmpty {
                ContentUnavailableView(
                    "No Relays Configured",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Add relays to sync your wallet data")
                )
                .scaleEffect(0.85)
            } else {
                ForEach(relays, id: \.self) { relay in
                    RelaySettingsRow(relayURL: relay) {
                        relays.removeAll { $0 == relay }
                    }
                }
            }
        } header: {
            HStack {
                Text("WALLET RELAYS")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.none)
                Spacer()
                Button(action: { showAddRelaySheet = true }) {
                    Image(systemName: "plus.circle")
                        .font(.footnote)
                }
            }
        } footer: {
            Text("These relays will be used to sync your wallet events and mint lists")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, -6)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                walletWarningSection
                mintsSection
                relaysSection

            }
            .formStyle(.grouped)
            .navigationTitle("Wallet Settings")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveSettings() }
                    }
                    .fontWeight(.bold)
                    .tint(.blue)
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showAddMintSheet) {
                AddMintSheet { url in
                    print("DEBUG: AddMintSheet callback - adding mint URL: \(url)")
                    print("DEBUG: Current mints before addition: \(mints.map { $0.url.absoluteString })")

                    do {
                        let mintInfo = try await fetchMintInfo(url: url)
                        mints.append(mintInfo)
                        print("DEBUG: Successfully added mint with info: \(mintInfo.name ?? "Unknown")")
                    } catch {
                        // Still add the mint even if we can't fetch info
                        // This allows users to add mints that might be temporarily down
                        let fallbackMintInfo = MintInfo(
                            url: url,
                            name: url.host ?? "Unknown Mint"
                        )
                        mints.append(fallbackMintInfo)
                        print("DEBUG: Added mint with fallback info due to error: \(error)")

                        // Show error but don't prevent mint addition
                        errorMessage = "Note: Could not fetch mint details (\(error.localizedDescription)). Mint added with basic info."
                        showError = true
                    }

                    print("DEBUG: Mints after addition: \(mints.map { $0.url.absoluteString })")
                    print("DEBUG: Total mints count: \(mints.count)")
                }
            }
            .sheet(isPresented: $showAddRelaySheet) {
                AddRelaySheet { relay in
                    if !relays.contains(relay) {
                        relays.append(relay)
                    }
                }
            }
            .sheet(isPresented: $showDiscoveredMints) {
                DiscoveredMintsSheet(discoveryTask: discoveryTask) { selectedMints in
                    for mint in selectedMints {
                        // Skip if blacklisted
                        if appState.isMintBlacklisted(mint.url) {
                            continue
                        }

                        if !mints.contains(where: { $0.url.absoluteString == mint.url }) {
                            // Note: mint.url should already be validated by MintDiscoveryManager
                            // but we double-check here for safety
                            let trimmedURL = mint.url.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let url = URL(string: trimmedURL),
                               url.scheme != nil,
                               url.host != nil {
                                do {
                                    let mintInfo = try await fetchMintInfo(url: url)
                                    mints.append(mintInfo)
                                } catch {
                                    // Still add the mint with basic info
                                    let fallbackMintInfo = MintInfo(
                                        url: url,
                                        name: mint.name.isEmpty ? (url.host ?? "Unknown Mint") : mint.name
                                    )
                                    mints.append(fallbackMintInfo)
                                }
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() async {
        isLoading = true

        print("DEBUG: loadCurrentSettings() called")

        // Load current configuration directly from the wallet
        if let wallet = walletManager.wallet {
            // Get mints from the wallet's mint manager, filtering out blacklisted ones
            let mintURLs = await wallet.mints.getMintURLs()
            print("DEBUG: Loaded mint URLs from wallet: \(mintURLs)")

            let mintURLObjects = mintURLs
                .filter { !appState.isMintBlacklisted($0) }
                .compactMap { URL(string: $0) }
            mints = mintURLObjects.map { MintInfo(url: $0, name: $0.host ?? "Unknown Mint") }

            print("DEBUG: Loaded \(mints.count) mints after filtering: \(mints.map { $0.url.absoluteString })")

            // Get relays from the wallet's configuration
            relays = await wallet.walletConfigRelays

            // Check if wallet info exists
            hasWalletInfo = await checkWalletInfo()
        }

        isLoading = false
    }

    private func checkWalletInfo() async -> Bool {
        guard let ndk = nostrManager.ndk,
              let pubkey = try? await ndk.signer?.pubkey else { return false }

        let filter = NDKFilter(
            authors: [pubkey],
            kinds: [17375]
        )

        // Use declarative data source to check if user has published wallet events
        let dataSource = ndk.observe(
            filter: filter,
            maxAge: 3600,
            cachePolicy: .cacheWithNetwork
        )

        for await _ in dataSource.events {
            return true // Found at least one event
        }

        return false
    }

    private func fetchMintInfo(url: URL) async throws -> MintInfo {
        // Use wallet's mint manager to fetch proper mint info
        if let wallet = walletManager.wallet {
            do {
                let ndkMintInfo = try await wallet.mints.getMintInfo(url: url)
                // Convert NDKMintInfo to local MintInfo
                return MintInfo(
                    url: url,
                    name: ndkMintInfo.name ?? url.host ?? "Unknown Mint"
                )
            } catch {
                // Fallback to basic info if fetch fails
                return MintInfo(url: url, name: url.host ?? "Unknown Mint")
            }
        } else {
            // No active wallet, use basic info
            return MintInfo(url: url, name: url.host ?? "Unknown Mint")
        }
    }

    private func saveSettings() async {
        isSaving = true

        do {
            guard let wallet = walletManager.wallet else {
                throw WalletError.noActiveWallet
            }

            // Debug logging
            print("DEBUG: saveSettings() called")
            print("DEBUG: mints array before conversion: \(mints.map { $0.url.absoluteString })")
            print("DEBUG: mints count: \(mints.count)")

            // Convert mints to URL strings, filtering out blacklisted ones
            let allMintURLs = mints.map { $0.url.absoluteString }
            print("DEBUG: All mint URLs: \(allMintURLs)")

            let mintURLs = mints
                .map { $0.url.absoluteString }
                .filter { url in
                    let isBlacklisted = appState.isMintBlacklisted(url)
                    print("DEBUG: Mint \(url) blacklisted: \(isBlacklisted)")
                    return !isBlacklisted
                }

            print("DEBUG: Filtered mint URLs to setup: \(mintURLs)")
            print("DEBUG: Filtered mint count: \(mintURLs.count)")

            // Setup wallet with new configuration
            try await wallet.setup(
                mints: mintURLs,
                relays: relays,
                publishMintList: true
            )

            // Update wallet info flag
            hasWalletInfo = true

            dismiss()
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showError = true
        }

        isSaving = false
    }

    private func discoverMints() {
        // Cancel any existing discovery task
        discoveryTask?.cancel()

        // Start new discovery task
        discoveryTask = Task {
            guard nostrManager.ndk != nil else { return }

            // Just show the sheet - the DiscoveredMintsSheet will handle the discovery
        }

        // Show the sheet immediately
        showDiscoveredMints = true
    }
}

// MARK: - Mint Row
struct MintSettingsRow: View {
    let mintInfo: MintInfo
    let onDelete: () -> Void
    @State private var balance: Int64 = 0
    @State private var favicon: Image?
    @Environment(WalletManager.self) private var walletManager

    var body: some View {
        HStack(spacing: 6) {
            // Favicon
            Group {
                if let favicon = favicon {
                    favicon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "building.columns.fill")
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(mintInfo.name ?? mintInfo.url.host ?? "Unknown Mint")
                    .font(.footnote)
                    .fontWeight(.medium)
                Text(mintInfo.url.host ?? mintInfo.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(balance)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                Text("sats")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.vertical, 1)
        .task {
            await updateBalance()
            await loadFavicon()
        }
    }

    private func updateBalance() async {
        guard let wallet = walletManager.wallet else { return }
        let mintBalance = await wallet.getBalance(mint: mintInfo.url)
        await MainActor.run {
            balance = mintBalance
        }
    }

    private func loadFavicon() async {
        guard let host = mintInfo.url.host else { return }
        let faviconURL = URL(string: "https://\(host)/favicon.ico")

        // Simple favicon loading - in production you'd want proper caching
        if let url = faviconURL,
           let data = try? await URLSession.shared.data(from: url).0,
           let uiImage = UIImage(data: data) {
            await MainActor.run {
                favicon = Image(uiImage: uiImage)
            }
        }
    }
}

// MARK: - Relay Row
struct RelaySettingsRow: View {
    let relayURL: String
    let onDelete: () -> Void
    @State private var relayState: NDKRelay.State?
    @State private var relayIcon: Image?
    @State private var observationTask: Task<Void, Never>?
    @Environment(NostrManager.self) private var nostrManager

    var body: some View {
        HStack(spacing: 6) {
            // Relay Icon
            if let icon = relayIcon {
                icon
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "network")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                // Use NIP-11 name if available, otherwise use hostname
                Text(relayState?.info?.name ?? getRelayHost(relayURL) ?? "Unknown Relay")
                    .font(.footnote)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(getRelayHost(relayURL) ?? relayURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // Connection status indicator
                    if let state = relayState {
                        Circle()
                            .fill(state.connectionState == .connected ? Color.green : 
                                  state.connectionState == .connecting ? Color.orange : Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            Spacer()

            // Show NIP-11 info if available
            if let info = relayState?.info {
                HStack(spacing: 4) {
                    if info.supportedNips?.contains(60) == true {
                        Image(systemName: "bitcoinsign.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    if info.pubkey != nil {
                        Image(systemName: "checkmark.shield")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.vertical, 1)
        .task {
            await loadRelayInfo()
        }
        .onDisappear {
            stopObserving()
        }
    }

    private func getRelayHost(_ url: String) -> String? {
        URL(string: url)?.host
    }

    private func loadRelayInfo() async {
        guard let ndk = nostrManager.ndk else { return }

        // Get the relay from NDK
        let relays = await ndk.relays
        guard let relay = relays.first(where: { $0.url == relayURL }) else {
            // If relay not found in NDK, just use basic formatting
            if getRelayHost(relayURL) != nil {
                await MainActor.run {
                    relayState = NDKRelay.State(
                        connectionState: .disconnected,
                        stats: NDKRelayStats(),
                        info: nil
                    )
                }
            }
            return
        }

        // Start observing relay state
        observationTask = Task {
            for await state in relay.stateStream {
                await MainActor.run {
                    self.relayState = state

                    // Load relay icon from NIP-11 data if available
                    if let iconURL = state.info?.icon,
                       let url = URL(string: iconURL),
                       relayIcon == nil {
                        Task {
                            if let data = try? await URLSession.shared.data(from: url).0,
                               let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    self.relayIcon = Image(uiImage: uiImage)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}

// MARK: - Add Mint Sheet
struct AddMintSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mintURL = ""
    @State private var isValidating = false
    @State private var validationError = ""
    let onAdd: (URL) async -> Void

    var isValidURL: Bool {
        // Trim whitespace
        let trimmed = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        // No spaces in the URL
        if trimmed.contains(" ") {
            return false
        }

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://mint.example.com", text: $mintURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: mintURL) { _, _ in
                            validationError = ""
                        }
                } header: {
                    Text("Mint URL")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enter the URL of a Cashu mint")
                        if !validationError.isEmpty {
                            Text(validationError)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Add Mint")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmedURL = mintURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard isValidURL,
                              let url = URL(string: trimmedURL) else {
                            validationError = "Please enter a valid URL"
                            return
                        }
                        Task {
                            isValidating = true
                            await onAdd(url)
                            dismiss()
                        }
                    }
                    .disabled(mintURL.isEmpty || !isValidURL || isValidating)
                }
            }
        }
    }
}

// MARK: - Add Relay Sheet
struct AddRelaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var relayURL = ""
    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("wss://relay.example.com", text: $relayURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Relay URL")
                } footer: {
                    Text("Enter a Nostr relay URL (must start with wss:// or ws://)")
                }
            }
            .navigationTitle("Add Relay")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard relayURL.starts(with: "wss://") || relayURL.starts(with: "ws://") else { return }
                        onAdd(relayURL)
                        dismiss()
                    }
                    .disabled(relayURL.isEmpty || (!relayURL.starts(with: "wss://") && !relayURL.starts(with: "ws://")))
                }
            }
        }
    }
}

// MARK: - Discovered Mints Sheet  
struct DiscoveredMintsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NostrManager.self) private var nostrManager
    let discoveryTask: Task<Void, Never>?
    let onSelect: ([DiscoveredMint]) async -> Void
    @State private var selectedMints: Set<String> = []
    @State private var discoveredMints: [DiscoveredMint] = []
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            mintsList
                .navigationTitle("Discovered Mints")
                .platformNavigationBarTitleDisplayMode(inline: true)
                .toolbar {
                    toolbarContent
                }
                .task {
                    await startDiscovery()
                }
                .onDisappear {
                    streamTask?.cancel()
                }
        }
    }

    private func startDiscovery() async {
        guard let ndk = nostrManager.ndk else { return }

        streamTask = Task {
            // Get user's followed pubkeys for mint recommendations
            var followedPubkeys: [String] = []
            if let signer = ndk.signer {
                do {
                    let userPubkey = try await signer.pubkey
                    let user = NDKUser(pubkey: userPubkey)
                    user.ndk = ndk
                    let contactList = try? await user.fetchContactList()
                    if let contactList = contactList {
                        // NDKContactList has a contacts property that contains NDKContactEntry objects
                        followedPubkeys = contactList.contacts.map { $0.user.pubkey }
                    }
                } catch {
                    print("Failed to get user pubkey: \(error)")
                }
            }

            // Create discovery data source
            let discoveryDataSource = MintDiscoveryDataSource(ndk: ndk, followedPubkeys: followedPubkeys)

            // Observe discovered mints
            while !Task.isCancelled {
                await MainActor.run {
                    self.discoveredMints = discoveryDataSource.discoveredMints
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Update every second
            }
        }
    }

    @ViewBuilder
    private var mintsList: some View {
        if discoveredMints.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Searching for mints...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("This may take a moment")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .listRowBackground(Color.clear)
        } else {
            List {
                ForEach(discoveredMints) { mint in
                    DiscoveredMintRowItem(
                        mint: mint,
                        isSelected: selectedMints.contains(mint.url),
                        onToggle: {
                            if selectedMints.contains(mint.url) {
                                selectedMints.remove(mint.url)
                            } else {
                                selectedMints.insert(mint.url)
                            }
                        }
                    )
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Add Selected") {
                Task {
                    let selected = discoveredMints.filter { selectedMints.contains($0.url) }
                    await onSelect(selected)
                    dismiss()
                }
            }
            .disabled(selectedMints.isEmpty)
        }
    }
}

// MARK: - Discovered Mint Row Item
private struct DiscoveredMintRowItem: View {
    let mint: DiscoveredMint
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            mintInfo

            Spacer()

            selectionIndicator
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    @ViewBuilder
    private var mintInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mint.name)
                .font(.headline)
            Text(mint.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}
