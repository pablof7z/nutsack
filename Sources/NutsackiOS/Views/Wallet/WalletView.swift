import SwiftUI
import NDKSwift
// import Popovers - Removed for build compatibility

struct WalletView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager

    @Binding var urlState: URLState?
    @Binding var showScanner: Bool

    @State private var navigationDestination: WalletDestination?
    @State private var isLoadingWallet = false
    @State private var scannedInvoice: String?
    @State private var showInvoicePreview = false
    @State private var showWalletSettings = false
    @State private var showSettings = false
    @State private var showWalletOnboarding = false
    @State private var isWalletConfigured = false

    enum WalletDestination: Identifiable, Hashable {
        case mint
        case send
        case receive(urlString: String?)
        case nutzap(pubkey: String? = nil)
        case swap
        case relayHealth
        case contacts
        case walletEvents
        case proofManagement
        case receivedNutzaps

        var id: String {
            switch self {
            case .mint: return "mint"
            case .send: return "send"
            case .receive(let url): return "receive_\(url ?? "nil")"
            case .nutzap(let pubkey): return "nutzap_\(pubkey ?? "nil")"
            case .swap: return "swap"
            case .relayHealth: return "relayHealth"
            case .contacts: return "contacts"
            case .walletEvents: return "walletEvents"
            case .proofManagement: return "proofManagement"
            case .receivedNutzaps: return "receivedNutzaps"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if !isWalletConfigured {
                    EmptyWalletView(showWalletOnboarding: $showWalletOnboarding)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Balance card with expandable pie chart
                            BalanceCard()
                                .padding(.horizontal)
                                .zIndex(1) // Ensure it stays on top during expansion

                            // Contacts horizontal scroll
                            ContactsScrollView(navigationDestination: $navigationDestination)
                                .padding(.top, -8)

                            // Recent transactions
                            RecentTransactionsView()
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)

                    Spacer()

                    // Action buttons
                    ActionButtonsView(navigationDestination: $navigationDestination, showScanner: $showScanner)
                        .padding()
                }
            }
            .background(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ]),
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                    }
                }

                if walletManager.wallet != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showWalletSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showInvoicePreview) {
                if let invoice = scannedInvoice {
                    LightningInvoicePreviewView(invoice: invoice)
                }
            }
            .sheet(isPresented: $showWalletSettings) {
                WalletSettingsView()
                    .environment(nostrManager)
                    .environment(walletManager)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(nostrManager)
                    .environment(walletManager)
            }
            .navigationDestination(item: $navigationDestination) { destination in
                switch destination {
                case .mint:
                    MintView()
                case .send:
                    SendView()
                case .receive(let urlString):
                    ReceiveView(tokenString: urlString)
                case .nutzap(let pubkey):
                    NutzapView(recipientPubkey: pubkey)
                case .swap:
                    SwapView()
                case .relayHealth:
                    RelayHealthView()
                case .contacts:
                    ContactsView(navigationDestination: $navigationDestination)
                case .walletEvents:
                    WalletEventsView()
                case .proofManagement:
                    ProofManagementView()
                case .receivedNutzaps:
                    ReceivedNutzapsView(walletManager: walletManager)
                }
            }
            .onAppear {
                print("🟢 WalletView - onAppear called at \(Date())")
                print("🟢 WalletView - activeWallet exists: \(walletManager.wallet != nil)")
                print("🟢 WalletView - isAuthenticated: \(NDKAuthManager.shared.isAuthenticated)")
                print("🟢 WalletView - signer available: \(nostrManager.ndk?.signer != nil)")
                loadWalletIfNeeded()

                // Check wallet configuration
                Task {
                    isWalletConfigured = await walletManager.isWalletConfigured
                }
            }
            .onChange(of: urlState) { _, newValue in
                if let newValue {
                    navigationDestination = .receive(urlString: newValue.url)
                    urlState = nil
                }
            }
            .onChange(of: NDKAuthManager.shared.isAuthenticated) { _, newValue in
                if newValue && walletManager.wallet == nil {
                    loadWalletIfNeeded()
                }
            }
            .fullScreenCover(isPresented: $showWalletOnboarding) {
                WalletOnboardingView(authMode: .none)
                    .environment(nostrManager)
                    .environment(walletManager)
                    .onDisappear {
                        // Reload wallet after onboarding
                        Task {
                            isWalletConfigured = await walletManager.isWalletConfigured
                        }
                        Task {
                            try? await walletManager.loadWalletForCurrentUser()
                        }
                    }
            }
            .task {
                print("🔵 WalletView - Task started at \(Date())")
                // Monitor for signer availability when authenticated
                var attempts = 0
                while NDKAuthManager.shared.isAuthenticated && walletManager.wallet == nil {
                    attempts += 1
                    print("🔵 WalletView - Task checking signer (attempt \(attempts))")
                    if nostrManager.ndk?.signer != nil {
                        print("🔵 WalletView - Task found signer, calling loadWalletIfNeeded")
                        loadWalletIfNeeded()
                        break
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                print("🔵 WalletView - Task completed")
            }
        }
        .tint(.orange)
    }

    private func loadWalletIfNeeded() {
        print("🟡 loadWalletIfNeeded called from \(Thread.current)")
        guard NDKAuthManager.shared.isAuthenticated else {
            print("🟡 loadWalletIfNeeded - Not authenticated, skipping")
            return
        }
        guard walletManager.wallet == nil else {
            print("🟡 loadWalletIfNeeded - Wallet already active, skipping")
            return
        }
        guard !isLoadingWallet else {
            print("🟡 loadWalletIfNeeded - Already loading wallet, skipping duplicate call")
            return
        }

        print("🟡 loadWalletIfNeeded - Starting wallet load task")
        isLoadingWallet = true
        Task {
            defer { isLoadingWallet = false }
            do {
                print("🟡 loadWalletIfNeeded - Calling loadWalletForCurrentUser")
                try await walletManager.loadWalletForCurrentUser()
                print("✅ loadWalletIfNeeded - Wallet loaded successfully")
            } catch WalletError.signerNotAvailable {
                // Signer not ready yet, retry after a short delay
                print("⚠️ loadWalletIfNeeded - Signer not available yet, retrying...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Retry once more
                do {
                    print("🟡 loadWalletIfNeeded - Retrying loadWalletForCurrentUser")
                    try await walletManager.loadWalletForCurrentUser()
                    print("✅ loadWalletIfNeeded - Wallet loaded successfully on retry")
                } catch {
                    print("❌ loadWalletIfNeeded - Failed to load wallet after retry: \(error)")
                }
            } catch {
                print("❌ loadWalletIfNeeded - Failed to load wallet: \(error)")
            }
        }
    }
}

// MARK: - Empty Wallet View
struct EmptyWalletView: View {
    @Environment(NostrManager.self) private var nostrManager
    @Binding var showWalletOnboarding: Bool

    var body: some View {
        Color.clear
            .onAppear {
                print("🔍 [EmptyWalletView] Detected authenticated user with no wallet")
                print("🔍 [EmptyWalletView] NostrManager has signer: \(nostrManager.ndk?.signer != nil)")
                print("🔍 [EmptyWalletView] NDKAuthManager.isAuthenticated: \(NDKAuthManager.shared.isAuthenticated)")

                // If we have auth state but no signer, clear the lingering auth state
                if nostrManager.ndk?.signer == nil && NDKAuthManager.shared.isAuthenticated {
                    print("🔍 [EmptyWalletView] Clearing lingering auth state - no signer found")
                    nostrManager.logout()
                    // Don't show wallet onboarding, let ContentView handle showing AuthenticationFlow
                } else {
                    showWalletOnboarding = true
                }
            }
    }
}

// Premium button style with subtle press effect
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Action Buttons
struct ActionButtonsView: View {
    @Binding var navigationDestination: WalletView.WalletDestination?
    @Binding var showScanner: Bool
    @State private var showReceiveMenu = false
    @State private var showSendMenu = false
    @State private var scanButtonPressed = false

    var body: some View {
        ZStack {
            // Base layer - receive and send buttons touching
            HStack(spacing: 0) {
                // Receive button
                Button(action: { navigationDestination = .mint }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 20, weight: .medium))
                        Text("Receive")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)
                    .padding(.trailing, 40) // Offset for floating circle (80px width / 2)
                }
                .buttonStyle(PremiumButtonStyle())

                // Send button - direct to send view
                Button(action: { navigationDestination = .send }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .medium))
                        Text("Send")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)
                    .padding(.leading, 40) // Offset for floating circle (80px width / 2)
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.18),
                                Color(white: 0.12)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: Color(.label).opacity(0.2), radius: 20, x: 0, y: 10)

            // Floating scan button on top
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scanButtonPressed = true
                }
                showScanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scanButtonPressed = false
                }
            }) {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange,
                                Color.orange.opacity(0.85)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                    .overlay(
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(scanButtonPressed ? 0.92 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 76) // Match the reduced scan button
    }
}

// MARK: - Contacts Scroll View
struct ContactsScrollView: View {
    @Binding var navigationDestination: WalletView.WalletDestination?
    @Environment(NostrManager.self) private var nostrManager
    @State private var contacts: [NDKUser] = []
    @State private var scrollOffset: CGFloat = 0

    // Default users to show when no contacts
    private let defaultUsers: [NDKUser] = {
        // Pre-calculated pubkeys for reliability
        let defaultPubkeys = [
            // Pablo Fernandez
            "fcb220c3af11b08325c8ad74c37b2ab5b9e665e3c39076c20c8d36c5b5c3de78",
            // Jack Dorsey  
            "82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2",
            // Calle (Cashu creator)
            "50d94fc2d8580c682b071a542f8b1e31a200b0508bab95a33bef0855df281d63"
        ]
        return defaultPubkeys.map { NDKUser(pubkey: $0) }
    }()

    var body: some View {
        ScrollViewReader { _ in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Show default users if no contacts, otherwise show contacts
                    ForEach(contacts.isEmpty ? defaultUsers : contacts, id: \.pubkey) { contact in
                        ContactAvatarView(user: contact) {
                            navigationDestination = .nutzap(pubkey: contact.pubkey)
                        }
                    }

                    // View All button at the end
                    Button(action: {
                        navigationDestination = .contacts
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.15))
                                    .frame(width: 64, height: 64)

                                Image(systemName: "ellipsis")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Text("All")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .id("viewAll")
                }
                .padding(.horizontal)
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self,
                                  value: geometry.frame(in: .named("scroll")).minX)
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { @MainActor value in
                scrollOffset = value
                // If scrolled far enough to the right (view all button visible)
                if value < -UIScreen.main.bounds.width {
                    navigationDestination = .contacts
                }
            }
        }
        .task {
            await loadContacts()
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

                // Limit to first 20 contacts for performance
                let limitedPubkeys = Array(contactPubkeys.prefix(20))

                // Create NDKUser objects and show them immediately
                contacts = limitedPubkeys.map { NDKUser(pubkey: $0) }
            }
        } catch {
            print("Failed to load contacts: \(error)")
        }
    }
}

struct ContactAvatarView: View {
    let user: NDKUser
    let onTap: () -> Void
    @State private var profile: NDKUserProfile?
    @State private var profileTask: Task<Void, Never>?
    @Environment(NostrManager.self) private var nostrManager

    var displayName: String {
        profile?.displayName ?? profile?.name ?? String(user.pubkey.prefix(8))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Group {
                    if let imageUrl = profile?.picture, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(Color(white: 0.15))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text(String(displayName.prefix(1)).uppercased())
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                    } else {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(String(displayName.prefix(1)).uppercased())
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )

                Text(displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            guard let ndk = nostrManager.ndk else { return }

            profileTask = Task {
                // Use declarative data source for profile
                let profileDataSource = ndk.observe(
                    filter: NDKFilter(
                        authors: [user.pubkey],
                        kinds: [0]
                    ),
                    maxAge: 3600,
                    cachePolicy: .cacheWithNetwork
                )

                for await event in profileDataSource.events {
                    if let profile = JSONCoding.safeDecode(NDKUserProfile.self, from: event.content) {
                        await MainActor.run {
                            self.profile = profile
                        }
                        break
                    }
                }
            }
        }
        .onDisappear {
            profileTask?.cancel()
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Helper Views
