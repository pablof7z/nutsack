import SwiftUI
import NDKSwift
import CashuSwift

struct MintsView: View {
    @Environment(WalletManager.self) private var walletManager
    @EnvironmentObject private var appState: AppState

    @State private var availableMints: [MintInfo] = []
    @State private var showAddMint = false
    @State private var showDiscoverMints = false
    @State private var isDiscovering = false
    @State private var isLoading = true
    @State private var discoveredMints: [DiscoveredMint] = []
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading mints...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if availableMints.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No mints configured")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Add mints to start using ecash")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    // Active Mints header
                    Text("Active Mints")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 5, trailing: 16))

                    ForEach(availableMints, id: \.url.absoluteString) { mint in
                        NavigationLink(destination: MintInfoDetailView(mintInfo: mint)) {
                            MintRow(mintInfo: mint)
                        }
                    }
                }

                // Add mint buttons
                Section {
                    Button(action: { showAddMint = true }) {
                        Label("Add Mint", systemImage: "plus.circle")
                    }

                    Button(action: discoverMints) {
                        if isDiscovering {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Discovering...")
                            }
                        } else {
                            Label("Discover Mints", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(isDiscovering)
                }
            }
            .navigationTitle("Mints")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .sheet(isPresented: $showAddMint) {
                AddMintView()
            }
            .sheet(isPresented: $showDiscoverMints) {
                DiscoveredMintsView(discoveredMints: discoveredMints)
            }
            .alert("Notice", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadMints()
            }
            .refreshable {
                await loadMints()
            }
        }
    }

    private func loadMints() async {
        guard walletManager.wallet != nil else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        let mintURLs = await walletManager.getActiveMintsURLs()
        let mintInfos = mintURLs.compactMap { urlString -> MintInfo? in
            guard let url = URL(string: urlString) else { return nil }
            return MintInfo(url: url, name: url.host ?? "Unknown Mint")
        }

        await MainActor.run {
            availableMints = mintInfos
            isLoading = false
        }
    }

    private func discoverMints() {
        // Just show a message to use wallet settings
        Task {
            await MainActor.run {
                errorMessage = "To discover and add mints, please use Wallet Settings."
                showError = true
            }
        }
    }
}

struct MintRow: View {
    let mintInfo: MintInfo
    @Environment(WalletManager.self) private var walletManager
    @State private var balance: Int64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mintInfo.url.host ?? mintInfo.url.absoluteString)
                        .font(.headline)

                    Text(mintInfo.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(balance)")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text("sats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .padding(.vertical, 4)
        .task {
            await updateBalance()
        }
    }

    private func updateBalance() async {
        guard let wallet = walletManager.wallet else { return }
        let mintBalance = await wallet.getBalance(mint: mintInfo.url)
        await MainActor.run {
            balance = mintBalance
        }
    }
}

struct MintInfoDetailView: View {
    let mintInfo: MintInfo
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var showInfo = false
    @State private var isSyncing = false
    @State private var showRemoveAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var balance: Int64 = 0
    @State private var isBlacklisted = false
    @State private var showBlacklistAlert = false

    var body: some View {
        List {
            // Balance section
            Section {
                HStack {
                    Text("Balance")
                    Spacer()
                    Text("\(balance) sats")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            }

            // Mint Information
            Section("Mint Information") {
                LabeledContent("URL", value: mintInfo.url.absoluteString)
                    .textSelection(.enabled)

            }

            // Actions
            Section("Actions") {
                Button(action: { showInfo = true }) {
                    Label("View Full Info", systemImage: "info.circle")
                }

                Button(action: syncMint) {
                    if isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                        }
                    } else {
                        Label("Sync Keyset", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isSyncing)

                Button(role: .destructive, action: { showBlacklistAlert = true }) {
                    Label("Blacklist Mint", systemImage: "xmark.shield")
                        .foregroundColor(.red)
                }

                Button(role: .destructive, action: { showRemoveAlert = true }) {
                    Label("Remove Mint", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(mintInfo.url.host ?? "Mint")
        .platformNavigationBarTitleDisplayMode(inline: true)
        .sheet(isPresented: $showInfo) {
            MintInfoView(mintInfo: mintInfo)
                .presentationDetents([.medium, .large])
        }
        .alert("Remove Mint?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                performRemoveMint()
            }
        } message: {
            Text("This will remove the mint from your wallet. Any tokens from this mint will no longer be usable.")
        }
        .alert("Blacklist Mint?", isPresented: $showBlacklistAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Blacklist", role: .destructive) {
                performBlacklistMint()
            }
        } message: {
            Text("This will block the mint from being used. The mint will be removed from your wallet and cannot be added again until unblocked.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await updateBalance()
        }
    }

    private func updateBalance() async {
        guard let wallet = walletManager.wallet else { return }
        let mintBalance = await wallet.getBalance(mint: mintInfo.url)
        await MainActor.run {
            balance = mintBalance
        }
    }

    private func syncMint() {
        isSyncing = true

        Task {
            do {
                try await walletManager.wallet?.mints.refreshMintKeysets(url: mintInfo.url)

                await MainActor.run {
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to sync mint: \(error.localizedDescription)"
                    showError = true
                    isSyncing = false
                }
            }
        }
    }

    private func performRemoveMint() {
        // Just dismiss - user should manage mints in wallet settings
        dismiss()

        // Show a message that they need to use wallet settings
        Task {
            await MainActor.run {
                errorMessage = "To remove mints, please use Wallet Settings."
                showError = true
            }
        }
    }

    private func performBlacklistMint() {
        appState.blacklistMint(mintInfo.url.absoluteString)
        dismiss()
    }
}

// MARK: - Mint Info View
struct MintInfoView: View {
    let mintInfo: MintInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Technical Details") {
                    LabeledContent("URL") {
                        Text(mintInfo.url.absoluteString)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Mint Information")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Mint View
struct AddMintView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager

    @State private var mintURL = ""
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""

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
                } header: {
                    Text("Mint URL")
                } footer: {
                    Text("Enter the URL of a Cashu mint")
                }

                Section {
                    Button(action: addMint) {
                        if isAdding {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Add Mint")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(mintURL.isEmpty || isAdding)
                }
            }
            .navigationTitle("Add Mint")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addMint() {
        // Just dismiss - user should manage mints in wallet settings
        dismiss()

        // Show a message that they need to use wallet settings
        Task {
            await MainActor.run {
                errorMessage = "To add mints, please use Wallet Settings."
                showError = true
            }
        }
    }
}
