import SwiftUI
import NDKSwift
import CashuSwift

struct MintDetailView: View {
    let mintURL: String

    @Environment(WalletManager.self) private var walletManager
    @Environment(NostrManager.self) private var nostrManager
    @Environment(\.dismiss) private var dismiss

    @State private var balance: Int64 = 0
    @State private var mintInfo: NDKMintInfo?
    @State private var walletEvents: [WalletEventInfo] = []
    @State private var proofEntries: [ProofStateManager.ProofEntry] = []
    @State private var isLoadingEvents = true
    @State private var isLoadingProofs = true
    @State private var isValidatingProofs = false
    @State private var validationResult: ProofValidationResult?
    @State private var showValidationDetails = false
    @State private var selectedTab = 0

    struct ProofValidationResult {
        let totalProofs: Int
        let validProofs: Int
        let spentProofs: Int
        let pendingProofs: Int
        let invalidProofs: Int
        let proofStates: [String: CashuSwift.Proof.ProofState]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with mint info and balance
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mintInfo?.name ?? URL(string: mintURL)?.host ?? "Unknown Mint")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(mintURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(balance)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("sats")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Quick actions
                HStack(spacing: 12) {
                    Button(action: { isValidatingProofs = true; Task { await validateAllProofs() } }) {
                        Label("Validate Proofs", systemImage: "checkmark.shield")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isValidatingProofs)

                    if validationResult != nil {
                        Button(action: { showValidationDetails = true }) {
                            Label("View Results", systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))

            // Tab selection
            Picker("View", selection: $selectedTab) {
                Text("Token Events").tag(0)
                Text("Proofs").tag(1)
                Text("Mint Info").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected tab
            switch selectedTab {
            case 0:
                TokenEventsTab(mintURL: mintURL, walletEvents: $walletEvents, isLoading: $isLoadingEvents)
            case 1:
                ProofsTab(proofEntries: $proofEntries, isLoading: $isLoadingProofs, validationResult: validationResult)
            case 2:
                MintInfoTab(mintInfo: mintInfo, mintURL: mintURL)
            default:
                EmptyView()
            }
        }
        .navigationTitle("Mint Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMintData()
        }
        .refreshable {
            await loadMintData()
        }
        .sheet(isPresented: $showValidationDetails) {
            if let result = validationResult {
                ValidationResultsView(result: result, proofEntries: proofEntries)
            }
        }
    }

    private func loadMintData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadBalance() }
            group.addTask { await loadMintInfo() }
            group.addTask { await loadWalletEvents() }
            group.addTask { await loadProofs() }
        }
    }

    private func loadBalance() async {
        guard let wallet = walletManager.wallet else { return }
        guard let url = URL(string: mintURL) else { return }
        let mintBalance = await wallet.getBalance(mint: url)
        await MainActor.run {
            self.balance = mintBalance
        }
    }

    private func loadMintInfo() async {
        guard let wallet = walletManager.wallet else { return }
        guard let url = URL(string: mintURL) else { return }

        do {
            let info = try await wallet.mints.getMintInfo(url: url)
            await MainActor.run {
                self.mintInfo = info
            }
        } catch {
            print("Failed to load mint info: \(error)")
        }
    }

    private func loadWalletEvents() async {
        isLoadingEvents = true

        do {
            // Fetch all wallet events and filter by mint
            let allEvents = try await walletManager.fetchAllWalletEvents()
            let mintEvents = allEvents.filter { event in
                event.tokenData?.mint == mintURL
            }

            await MainActor.run {
                self.walletEvents = mintEvents.sorted { $0.event.createdAt > $1.event.createdAt }
                self.isLoadingEvents = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingEvents = false
            }
        }
    }

    private func loadProofs() async {
        isLoadingProofs = true

        guard let wallet = walletManager.wallet else {
            await MainActor.run { isLoadingProofs = false }
            return
        }

        let entries = await wallet.proofStateManager.getEntries(mint: mintURL)
        await MainActor.run {
            self.proofEntries = entries.filter { $0.state != .deleted }
                .sorted { $0.proof.amount > $1.proof.amount }
            self.isLoadingProofs = false
        }
    }

    private func validateAllProofs() async {
        guard let wallet = walletManager.wallet,
              let url = URL(string: mintURL) else { return }

        do {
            let states = try await wallet.checkProofStates(mintURL: url)

            // Count different states
            var validCount = 0
            var spentCount = 0
            var pendingCount = 0

            for (_, state) in states {
                switch state {
                case .unspent:
                    validCount += 1
                case .spent:
                    spentCount += 1
                case .pending:
                    pendingCount += 1
                }
            }

            let result = ProofValidationResult(
                totalProofs: states.count,
                validProofs: validCount,
                spentProofs: spentCount,
                pendingProofs: pendingCount,
                invalidProofs: 0,
                proofStates: states
            )

            await MainActor.run {
                self.validationResult = result
                self.isValidatingProofs = false
                self.showValidationDetails = true
            }
        } catch {
            print("Failed to validate proofs: \(error)")
            await MainActor.run {
                self.isValidatingProofs = false
            }
        }
    }
}

// MARK: - Token Events Tab
struct TokenEventsTab: View {
    let mintURL: String
    @Binding var walletEvents: [WalletEventInfo]
    @Binding var isLoading: Bool

    var body: some View {
        if isLoading {
            ProgressView("Loading events...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if walletEvents.isEmpty {
            ContentUnavailableView(
                "No Token Events",
                systemImage: "doc.text",
                description: Text("No token events found for this mint")
            )
        } else {
            List {
                Section {
                    ForEach(walletEvents) { eventInfo in
                        NavigationLink(value: eventInfo) {
                            WalletEventRow(eventInfo: eventInfo)
                        }
                    }
                } header: {
                    HStack {
                        Text("Token Events")
                        Spacer()
                        Text("\(walletEvents.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: WalletEventInfo.self) { eventInfo in
                WalletEventDetailView(eventInfo: eventInfo)
            }
        }
    }
}

// MARK: - Proofs Tab
struct ProofsTab: View {
    @Binding var proofEntries: [ProofStateManager.ProofEntry]
    @Binding var isLoading: Bool
    let validationResult: MintDetailView.ProofValidationResult?

    var activeProofs: [ProofStateManager.ProofEntry] {
        proofEntries.filter { $0.state == .available }
    }

    var reservedProofs: [ProofStateManager.ProofEntry] {
        proofEntries.filter { $0.state == .reserved }
    }

    var body: some View {
        if isLoading {
            ProgressView("Loading proofs...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if proofEntries.isEmpty {
            ContentUnavailableView(
                "No Proofs",
                systemImage: "key",
                description: Text("No proofs found for this mint")
            )
        } else {
            List {
                if !activeProofs.isEmpty {
                    Section {
                        ForEach(activeProofs, id: \.proof.C) { entry in
                            ProofEntryRow(entry: entry, validationState: validationResult?.proofStates[entry.proof.C])
                        }
                    } header: {
                        HStack {
                            Text("Available Proofs")
                            Spacer()
                            Text("\(activeProofs.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !reservedProofs.isEmpty {
                    Section {
                        ForEach(reservedProofs, id: \.proof.C) { entry in
                            ProofEntryRow(entry: entry, validationState: validationResult?.proofStates[entry.proof.C])
                        }
                    } header: {
                        HStack {
                            Text("Reserved Proofs")
                            Spacer()
                            Text("\(reservedProofs.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mint Info Tab
struct MintInfoTab: View {
    let mintInfo: NDKMintInfo?
    let mintURL: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let info = mintInfo {
                    mintInfoContent(info: info)
                } else {
                    noMintInfoContent
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func mintInfoContent(info: NDKMintInfo) -> some View {
        // Basic Info
        basicInfoSection(info: info)

        // Contact Info
        ContactInfoSection(contacts: info.contact)

        // Supported Methods
        supportedMethodsSection(nuts: info.nuts)
    }

    @ViewBuilder
    private func basicInfoSection(info: NDKMintInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mint Information")
                .font(.headline)

            LabeledContent("Name", value: info.name ?? "Unknown")
            LabeledContent("Public Key", value: String(info.pubkey?.prefix(16) ?? "Unknown") + "...")
                .font(.system(.body, design: .monospaced))

            if let description = info.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(description)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func supportedMethodsSection(nuts: NDKMintInfo.Nuts?) -> some View {
        if let nuts = nuts {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported NIPs")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    if nuts.nut04 != nil {
                        nutRow(number: "04", description: "Mint tokens")
                    }
                    if nuts.nut05 != nil {
                        nutRow(number: "05", description: "Melt tokens")
                    }
                    if nuts.nut07 != nil {
                        nutRow(number: "07", description: "Spendable check")
                    }
                    if nuts.nut08 != nil {
                        nutRow(number: "08", description: "Melt with Lightning")
                    }
                    if nuts.nut09 != nil {
                        nutRow(number: "09", description: "Restore")
                    }
                    if nuts.nut10 != nil {
                        nutRow(number: "10", description: "Spending conditions")
                    }
                    if nuts.nut12 != nil {
                        nutRow(number: "12", description: "DLEQ proofs")
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func nutRow(number: String, description: String) -> some View {
        HStack {
            Text("NUT-\(number)")
                .font(.system(.body, design: .monospaced))
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }

    private var noMintInfoContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Mint information not available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(mintURL)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Proof Entry Row
struct ProofEntryRow: View {
    let entry: ProofStateManager.ProofEntry
    let validationState: CashuSwift.Proof.ProofState?

    @State private var isExpanded = false

    var stateColor: Color {
        if let validationState = validationState {
            switch validationState {
            case .unspent: return .green
            case .spent: return .red
            case .pending: return .orange
            }
        }

        switch entry.state {
        case .available: return .green
        case .reserved: return .orange
        case .deleted: return .red
        }
    }

    var stateText: String {
        if let validationState = validationState {
            switch validationState {
            case .unspent: return "Valid ✓"
            case .spent: return "Spent ✗"
            case .pending: return "Pending"
            }
        }

        switch entry.state {
        case .available: return "Available"
        case .reserved: return "Reserved"
        case .deleted: return "Deleted"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(entry.proof.amount) sats")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)

                        if validationState != nil {
                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text(stateText)
                                .font(.caption)
                                .foregroundColor(stateColor)
                                .fontWeight(.medium)
                        }
                    }

                    Text("C: " + entry.proof.C.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if validationState == nil {
                        Text(stateText)
                            .font(.caption)
                            .foregroundColor(stateColor)
                    }

                    if let eventId = entry.ownerEventId {
                        Text("Event: " + eventId.prefix(8) + "...")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()

                    Group {
                        LabeledContent("Secret") {
                            Text(entry.proof.secret.prefix(32) + "...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Keyset ID") {
                            Text(entry.proof.keysetID.prefix(16) + "...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        if let eventId = entry.ownerEventId {
                            LabeledContent("Owner Event") {
                                Text(eventId)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if let timestamp = entry.ownerTimestamp {
                            LabeledContent("Created") {
                                Text(Date(timeIntervalSince1970: TimeInterval(timestamp)), style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Validation Results View
struct ValidationResultsView: View {
    let result: MintDetailView.ProofValidationResult
    let proofEntries: [ProofStateManager.ProofEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section("Summary") {
                    HStack {
                        Label("Total Proofs", systemImage: "key.fill")
                        Spacer()
                        Text("\(result.totalProofs)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Label("Valid", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("\(result.validProofs)")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Label("Spent", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(result.spentProofs)")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }

                    if result.pendingProofs > 0 {
                        HStack {
                            Label("Pending", systemImage: "clock.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(result.pendingProofs)")
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Invalid/Spent Proofs Details
                if result.spentProofs > 0 {
                    Section("Spent Proofs") {
                        ForEach(proofEntries.filter { entry in
                            result.proofStates[entry.proof.C] == .spent
                        }, id: \.proof.C) { entry in
                            ProofEntryRow(entry: entry, validationState: .spent)
                        }
                    }
                }
            }
            .navigationTitle("Validation Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Contact Info Section
private struct ContactInfoSection: View {
    let contacts: [NDKMintInfo.Contact]?

    var body: some View {
        if let contacts = contacts, !contacts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contact")
                    .font(.headline)

                ForEach(Array(contacts.enumerated()), id: \.offset) { _, contact in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(contact.method):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(contact.info)
                            .font(.body)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}
