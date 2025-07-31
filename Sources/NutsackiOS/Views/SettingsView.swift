import SwiftUI
import NDKSwift

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var nostrManager: NostrManager
    @Environment(WalletManager.self) private var walletManager

    @State private var currentUser: NDKUser?
    @State private var copiedNpub = false

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section {
                    if let currentUser = currentUser {
                        NavigationLink(destination: AccountDetailView(user: currentUser, metadata: nil)) {
                            HStack {
                                // Profile picture
                                UserProfilePicture(user: currentUser, size: 50)

                                VStack(alignment: .leading, spacing: 4) {
                                    UserDisplayName(user: currentUser)
                                        .font(.headline)

                                    HStack(spacing: 4) {
                                        Text(String(currentUser.npub.prefix(16)) + "...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Button(action: { copyNpub(currentUser.npub) }) {
                                            Image(systemName: copiedNpub ? "checkmark.circle.fill" : "doc.on.doc")
                                                .font(.caption)
                                                .foregroundColor(copiedNpub ? .green : .secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Text("No user logged in")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Account")
                }

                // Preferences
                Section {
                    Picker("Theme", selection: $appState.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("Currency", selection: $appState.preferredConversionUnit) {
                        ForEach(CurrencyUnit.allCases, id: \.self) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }

                    NavigationLink(destination: RelayManagementView()) {
                        Label("Relays", systemImage: "network")
                    }

                    NavigationLink(destination: BackupView()) {
                        Label("Backup", systemImage: "lock.shield")
                    }

                    NavigationLink(destination: UnpublishedEventsView()) {
                        HStack {
                            Label("Unpublished Events", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            UnpublishedEventsBadge()
                        }
                    }
                } header: {
                    Text("Preferences")
                }

                // Blacklisted Mints Section
                Section {
                    NavigationLink(destination: BlacklistedMintsView()) {
                        HStack {
                            Label("Blacklisted Mints", systemImage: "xmark.shield")
                            Spacer()
                            if !appState.blacklistedMints.isEmpty {
                                Text("\(appState.blacklistedMints.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Manage mints that are blocked from being used in your wallet")
                }

                // Nutzap Settings
                Section {
                    NavigationLink(destination: NutzapSettingsView()) {
                        Label("Zap Settings", systemImage: "bolt.heart")
                    }

                    NavigationLink(destination: WalletEventsView()) {
                        Label("Wallet Events", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink(destination: RelayHealthView()) {
                        Label("Relay Health", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    NavigationLink(destination: ProofManagementView()) {
                        Label("Manage Proofs", systemImage: "key")
                    }

                    NavigationLink(destination: ReceivedNutzapsView(walletManager: walletManager)) {
                        Label("Received Zaps", systemImage: "bolt.fill")
                    }
                } header: {
                    Text("Wallet")
                } footer: {
                    Text("Configure how others can send zaps to your wallet")
                }

                // Debug section
                #if DEBUG
                Section {
                    NavigationLink(destination: DebugView()) {
                        Label("Debug", systemImage: "ladybug")
                    }
                    
                    Toggle(isOn: $appState.debugSimulateMintFailure) {
                        Label("Simulate Mint Failures", systemImage: "exclamationmark.triangle")
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("When enabled, mint operations will fail after payment to test error handling")
                }
                #endif

                // Danger zone
                Section {
                    Button(role: .destructive, action: logout) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .bottom) {
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGroupedBackground))
            }
            .task {
                await loadUserData()
            }
        }
    }

    private func copyNpub(_ npub: String) {
        #if os(iOS)
        UIPasteboard.general.string = npub
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(npub, forType: .string)
        #endif
        withAnimation {
            copiedNpub = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedNpub = false
            }
        }
    }
    
    private func loadUserData() async {
        let ndk = nostrManager.ndk
        guard let signer = ndk.signer else { return }
        
        do {
            let pubkey = try await signer.pubkey
            currentUser = NDKUser(pubkey: pubkey)
        } catch {
            print("Failed to get current user: \(error)")
        }
    }

    private func logout() {
        // Clear wallet data and cancel subscriptions
        walletManager.clearWalletData()

        // Clear authentication data
        Task {
            await nostrManager.logout()
        }

    }
}

// MARK: - Account Detail View
struct AccountDetailView: View {
    let user: NDKUser
    let metadata: NDKUserMetadata?
    @EnvironmentObject private var nostrManager: NostrManager
    @State private var showPrivateKey = false
    @State private var copiedKey = false
    @State private var copiedNpub = false
    @State private var nsecKey: String?
    @State private var userMetadata: NDKUserMetadata?

    var npub: String {
        user.npub
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Display Name", value: displayName)

                if let about = userMetadata?.about ?? metadata?.about {
                    LabeledContent("About") {
                        Text(about)
                            .font(.caption)
                    }
                }

                if let nip05 = userMetadata?.nip05 ?? metadata?.nip05 {
                    LabeledContent("NIP-05", value: nip05)
                }
            } header: {
                Text("Profile")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Public Key (npub)")
                        Spacer()
                    }

                    Text(npub)
                        .font(.caption)
                        .textSelection(.enabled)

                    Button(action: copyPublicKey) {
                        Label(
                            copiedNpub ? "Copied!" : "Copy npub",
                            systemImage: copiedNpub ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(copiedNpub ? .green : .blue)
                }

                if let nsecKey = nsecKey {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Private Key (nsec)")
                            Spacer()
                            Button(action: togglePrivateKey) {
                                Image(systemName: showPrivateKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                        }

                        if showPrivateKey {
                            Text(nsecKey)
                                .font(.caption)
                                .textSelection(.enabled)

                            Button(action: copyPrivateKey) {
                                Label(
                                    copiedKey ? "Copied!" : "Copy Private Key",
                                    systemImage: copiedKey ? "checkmark.circle.fill" : "doc.on.doc"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(copiedKey ? .green : .orange)
                        }
                    }
                } else {
                    Text("Private key access through secure authentication")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Keys")
            } footer: {
                Text("Keep your private key secure. Anyone with this key can access your account.")
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadPrivateKey()
            Task {
                await loadUserMetadata()
            }
        }
    }

    private func loadPrivateKey() {
        guard let signer = nostrManager.ndk.signer as? NDKPrivateKeySigner else {
            nsecKey = nil
            return
        }

        Task {
            do {
                let nsec = try signer.nsec
                await MainActor.run {
                    nsecKey = nsec
                }
            } catch {
                print("Failed to load private key: \(error)")
                await MainActor.run {
                    nsecKey = nil
                }
            }
        }
    }

    private func togglePrivateKey() {
        withAnimation {
            showPrivateKey.toggle()
        }
    }

    private func copyPublicKey() {
        #if os(iOS)
        UIPasteboard.general.string = npub
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(npub, forType: .string)
        #endif
        withAnimation {
            copiedNpub = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedNpub = false
            }
        }
    }

    private func copyPrivateKey() {
        guard let nsec = nsecKey else { return }
        #if os(iOS)
        UIPasteboard.general.string = nsec
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(nsec, forType: .string)
        #endif
        withAnimation {
            copiedKey = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedKey = false
            }
        }
    }
    
    private var displayName: String {
        userMetadata?.displayName ?? userMetadata?.name ?? metadata?.displayName ?? metadata?.name ?? "Nostr User"
    }
    
    private func loadUserMetadata() async {
        guard let profileManager = nostrManager.profileManager else { return }
        
        for await metadata in profileManager.subscribe(for: user.pubkey, maxAge: 3600) {
            await MainActor.run {
                userMetadata = metadata
            }
            break // We only need the first result
        }
    }
}

// MARK: - Backup View
struct BackupView: View {
    var body: some View {
        List {
            Section {
                Text("Backup features coming soon")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Wallet Backup")
            } footer: {
                Text("Your wallets are automatically backed up to Nostr using NIP-60")
            }
        }
        .navigationTitle("Backup")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Logo
                Image(systemName: "banknote.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange.gradient)
                    .padding(.top, 40)

                Text("Nutsack")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Lightning-fast payments with Nostr")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Description
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.headline)

                    Text("""
                    Nutsack is a Cashu ecash wallet that integrates seamlessly with Nostr. It implements NIP-60 for wallet backup and NIP-61 for nutzaps.

                    Built with NDKSwift, this wallet showcases the power of combining ecash with the Nostr protocol for a truly decentralized payment experience.
                    """)
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Unpublished Events Badge
struct UnpublishedEventsBadge: View {
    @EnvironmentObject private var nostrManager: NostrManager
    @State private var unpublishedCount = 0
    @State private var timer: Timer?

    var body: some View {
        Group {
            if unpublishedCount > 0 {
                Text("\(unpublishedCount)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .onAppear {
            updateUnpublishedCount()
            startPeriodicUpdate()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func updateUnpublishedCount() {
        Task {
            guard let cache = nostrManager.cache else { return }
            let unpublishedEvents = await cache.getUnpublishedEvents(maxAge: 3600, limit: nil)
            await MainActor.run {
                unpublishedCount = unpublishedEvents.count
            }
        }
    }

    private func startPeriodicUpdate() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            updateUnpublishedCount()
        }
    }
}

// MARK: - Unpublished Events View
struct UnpublishedEventsView: View {
    @EnvironmentObject private var nostrManager: NostrManager
    @State private var unpublishedEvents: [(event: NDKEvent, targetRelays: Set<String>)] = []
    @State private var isLoading = true
    @State private var isRetrying = false
    @State private var lastRetryTime: Date?
    @State private var showRetrySuccess = false
    @State private var retriedCount = 0
    @State private var selectedEvent: NDKEvent?
    @State private var showingEventDetails = false

    var body: some View {
        List {
            // Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if isLoading {
                                Text("Checking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(unpublishedEvents.count) events pending")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if unpublishedEvents.count > 0 {
                            Button(action: retryAllEvents) {
                                if isRetrying {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Retry All")
                                        .foregroundColor(.orange)
                                }
                            }
                            .disabled(isRetrying)
                        }
                    }
                    .padding(.vertical, 4)

                    if let lastRetryTime = lastRetryTime {
                        Text("Last retry: \(lastRetryTime, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Status")
                }

                // Events List
                if !unpublishedEvents.isEmpty {
                    Section {
                        ForEach(Array(unpublishedEvents.enumerated()), id: \.offset) { index, eventInfo in
                            UnpublishedEventRow(
                                event: eventInfo.event,
                                targetRelays: eventInfo.targetRelays,
                                onRetry: {
                                    retryEvent(at: index)
                                },
                                onTap: {
                                    selectedEvent = eventInfo.event
                                    showingEventDetails = true
                                }
                            )
                        }
                    } header: {
                        Text("Pending Events")
                    } footer: {
                        Text("These events were published optimistically but haven't been confirmed by relays yet. You can retry individual events or all at once.")
                    }
                } else if !isLoading {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)

                            Text("All events published successfully!")
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            Text("Your events have been confirmed by the relays.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        .navigationTitle("Unpublished Events")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .refreshable {
            await loadUnpublishedEvents()
        }
        .onAppear {
            Task {
                await loadUnpublishedEvents()
            }
        }
        .alert("Retry Successful", isPresented: $showRetrySuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully retried \(retriedCount) events")
        }
        .sheet(isPresented: $showingEventDetails) {
            if let event = selectedEvent {
                UnpublishedEventDetailView(event: event)
            }
        }
    }

    private func loadUnpublishedEvents() async {
        guard let cache = nostrManager.cache else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        let events = await cache.getUnpublishedEvents(maxAge: 3600, limit: nil)
        await MainActor.run {
            unpublishedEvents = events
            isLoading = false
        }
    }

    private func retryAllEvents() {
        let ndk = nostrManager.ndk

        isRetrying = true

        Task {
            do {
                let retriedEvents = try await ndk.retryUnpublishedEvents(maxAge: 3600, limit: nil)
                await MainActor.run {
                    isRetrying = false
                    lastRetryTime = Date()
                    retriedCount = retriedEvents.count
                    showRetrySuccess = true
                }

                // Reload the list
                await loadUnpublishedEvents()
            } catch {
                await MainActor.run {
                    isRetrying = false
                }
                print("Failed to retry events: \(error)")
            }
        }
    }

    private func retryEvent(at index: Int) {
        let ndk = nostrManager.ndk
        guard index < unpublishedEvents.count else { return }

        let eventInfo = unpublishedEvents[index]

        Task {
            do {
                _ = try await ndk.publish(eventInfo.event)

                // Reload the list
                await loadUnpublishedEvents()
            } catch {
                print("Failed to retry individual event: \(error)")
            }
        }
    }
}

// MARK: - Unpublished Event Row
struct UnpublishedEventRow: View {
    let event: NDKEvent
    let targetRelays: Set<String>
    let onRetry: () -> Void
    let onTap: () -> Void

    @State private var isRetrying = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // Event content preview
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eventKindName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if !event.content.isEmpty {
                            Text(event.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }

                    Spacer()
                }

                // Metadata
                HStack {
                    Text("Created: \(Date(timeIntervalSince1970: TimeInterval(event.createdAt)), style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("\(targetRelays.count) relays")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Target relays (abbreviated)
                if !targetRelays.isEmpty {
                    Text("Targets: \(abbreviatedRelayList)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: retryEvent) {
                if isRetrying {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
            }
            .disabled(isRetrying)
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .padding(.vertical, 4)
    }

    private var eventKindName: String {
        switch event.kind {
        case 0: return "Profile"
        case 1: return "Note"
        case 3: return "Contacts"
        case 4: return "Direct Message"
        case 5: return "Deletion"
        case 6: return "Repost"
        case 7: return "Reaction"
        case 17375: return "NIP-60 Wallet"
        default: return "Event \(event.kind)"
        }
    }

    private var abbreviatedRelayList: String {
        let sorted = targetRelays.sorted()
        if sorted.count <= 2 {
            return sorted.map { shortRelayName($0) }.joined(separator: ", ")
        } else {
            let first = sorted.prefix(2).map { shortRelayName($0) }
            return first.joined(separator: ", ") + " +\(sorted.count - 2)"
        }
    }

    private func shortRelayName(_ url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        // Remove common prefixes and show just the domain
        return host.replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "relay.", with: "")
    }

    private func retryEvent() {
        isRetrying = true
        onRetry()

        // Reset retry state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRetrying = false
        }
    }
}

// MARK: - Debug View
#if DEBUG
struct DebugView: View {
    @EnvironmentObject private var nostrManager: NostrManager
    @State private var cacheStats: CacheStatistics?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdateTime: Date?

    var body: some View {
        NavigationStack {
            List {
                // Cache Statistics Section
                Section {
                    NavigationLink(destination: CacheStatsView()) {
                        HStack {
                            Label("Cache Statistics", systemImage: "cylinder.split.1x2")
                            Spacer()
                            if let stats = cacheStats {
                                Text("\(stats.totalEvents) events")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Database")
                } footer: {
                    if let lastUpdate = lastUpdateTime {
                        Text("Last updated: \(lastUpdate, style: .relative)")
                    } else {
                        Text("View detailed cache statistics and event counts")
                    }
                }

                // Quick Stats Overview
                if let stats = cacheStats {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "cylinder.fill")
                                    .foregroundColor(.blue)
                                Text("Cache Overview")
                                    .font(.headline)
                            }

                            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                                GridRow {
                                    Text("Total Events:")
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.totalEvents)")
                                        .fontWeight(.medium)
                                }

                                GridRow {
                                    Text("Event Types:")
                                        .foregroundStyle(.secondary)
                                    Text("\(stats.eventsByKind.count) kinds")
                                        .fontWeight(.medium)
                                }

                                GridRow {
                                    Text("Most Common:")
                                        .foregroundStyle(.secondary)
                                    Text(stats.mostCommonKind)
                                        .fontWeight(.medium)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Quick Stats")
                    }
                }

                // Error Display
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    } header: {
                        Text("Error")
                    }
                }
            }
            .navigationTitle("Debug")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await loadCacheStats()
            }
            .onAppear {
                Task {
                    await loadCacheStats()
                }
            }
        }
    }

    private func loadCacheStats() async {
        guard let cache = nostrManager.cache else {
            await MainActor.run {
                errorMessage = "No cache available"
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Query all events to get statistics
            let filter = NDKFilter() // Empty filter to get all events
            let allEvents = try await cache.queryEvents(filter)
            
            // Group events by kind
            var eventsByKind: [Int: Int] = [:]
            for event in allEvents {
                eventsByKind[event.kind, default: 0] += 1
            }
            
            let stats = CacheStatistics(
                totalEvents: allEvents.count,
                eventsByKind: eventsByKind
            )
            
            await MainActor.run {
                cacheStats = stats
                lastUpdateTime = Date()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load cache stats: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Cache Statistics View
struct CacheStatsView: View {
    @EnvironmentObject private var nostrManager: NostrManager
    @State private var cacheStats: CacheStatistics?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Total Events Section
            Section {
                if let stats = cacheStats {
                    HStack {
                        Image(systemName: "cylinder.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Events")
                                .font(.headline)
                            Text("\(stats.totalEvents) events in database")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(stats.totalEvents)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                } else if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading cache statistics...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No cache data available")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Overview")
            }

            // Events by Kind Section
            if let stats = cacheStats, !stats.eventsByKind.isEmpty {
                Section {
                    ForEach(stats.sortedEventKinds, id: \.kind) { kindStat in
                        HStack {
                            Text("Kind \(kindStat.kind)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(kindStat.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Events by Kind")
                } footer: {
                    Text("Breakdown of events stored in the cache by Nostr event kind")
                }
            }

            // Error Display
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } header: {
                    Text("Error")
                }
            }
        }
        .navigationTitle("Cache Statistics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable {
            await loadCacheStats()
        }
        .onAppear {
            Task {
                await loadCacheStats()
            }
        }
    }

    private func loadCacheStats() async {
        guard let cache = nostrManager.cache else {
            await MainActor.run {
                errorMessage = "No cache available"
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // Query all events to get statistics
            let filter = NDKFilter() // Empty filter to get all events
            let allEvents = try await cache.queryEvents(filter)
            
            // Group events by kind
            var eventsByKind: [Int: Int] = [:]
            for event in allEvents {
                eventsByKind[event.kind, default: 0] += 1
            }
            
            let stats = CacheStatistics(
                totalEvents: allEvents.count,
                eventsByKind: eventsByKind
            )
            
            await MainActor.run {
                cacheStats = stats
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load cache stats: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#endif

// MARK: - Cache Statistics Extensions
extension CacheStatistics {
    var sortedEventKinds: [EventKindStatistic] {
        eventsByKind.map { kind, count in
            EventKindStatistic(kind: kind, count: count)
        }.sorted { $0.count > $1.count }
    }

    var mostCommonKind: String {
        guard let mostCommon = sortedEventKinds.first else { return "None" }
        return "Kind \(mostCommon.kind) (\(mostCommon.count))"
    }
}

struct EventKindStatistic {
    let kind: Int
    let count: Int
}

// MARK: - Unpublished Event Detail View
struct UnpublishedEventDetailView: View {
    let event: NDKEvent
    @Environment(\.dismiss) private var dismiss
    @State private var copiedToClipboard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Event Metadata
                    VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Event ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text(event.id)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Kind")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text("\(event.kind)")
                                .font(.system(.body, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Created At")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text("\(Date(timeIntervalSince1970: TimeInterval(event.createdAt)), formatter: DateFormatter.fullDateTimeFormatter)")
                                .font(.system(.caption, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Author")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text(NDKUser(pubkey: event.pubkey).npub)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Tags
                    if !event.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                ForEach(Array(event.tags.enumerated()), id: \.offset) { index, tag in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20, alignment: .trailing)

                                        Text(tag.joined(separator: ", "))
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 2)
                                }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Content
                    if !event.content.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                Text("Content")
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                Text(event.content)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Raw JSON
                    VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Raw Event JSON")
                                    .font(.headline)
                                Spacer()
                                Button(action: copyRawJSON) {
                                    Label(
                                        copiedToClipboard ? "Copied!" : "Copy",
                                        systemImage: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc"
                                    )
                                    .font(.caption)
                                    .foregroundColor(copiedToClipboard ? .green : .accentColor)
                                }
                            }
                            .padding(.bottom, 4)

                            ScrollView(.horizontal) {
                                Text(formattedJSON)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formattedJSON: String {
        let eventDict: [String: Any] = [
            "id": event.id,
            "pubkey": event.pubkey,
            "created_at": event.createdAt,
            "kind": event.kind,
            "tags": event.tags,
            "content": event.content,
            "sig": event.sig
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: eventDict, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "Failed to format JSON"
    }

    private func copyRawJSON() {
        #if os(iOS)
        UIPasteboard.general.string = formattedJSON
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedJSON, forType: .string)
        #endif

        withAnimation {
            copiedToClipboard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
