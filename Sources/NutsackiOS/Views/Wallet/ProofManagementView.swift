import SwiftUI
import NDKSwift
import CashuSwift

struct ProofManagementView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var allProofEntries: [ProofStateManager.ProofEntry] = []
    @State private var mintBalances: [String: Int64] = [:]
    @State private var isLoading = true
    @State private var isValidating = false
    @State private var validationResults: [String: [String: CashuSwift.Proof.ProofState]] = [:] // mint -> proof states
    @State private var selectedProofs: Set<String> = [] // proof.C values
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: Error?
    
    var groupedProofs: [String: [ProofStateManager.ProofEntry]] {
        Dictionary(grouping: allProofEntries) { $0.mint }
    }
    
    var selectedProofCount: Int {
        selectedProofs.count
    }
    
    var selectedProofAmount: Int64 {
        allProofEntries
            .filter { selectedProofs.contains($0.proof.C) }
            .reduce(0) { $0 + Int64($1.proof.amount) }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading proofs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allProofEntries.isEmpty {
                    ContentUnavailableView(
                        "No Proofs",
                        systemImage: "key",
                        description: Text("Your wallet doesn't contain any proofs")
                    )
                } else {
                    proofsList
                }
            }
            .navigationTitle("Proof Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .task {
                await loadAllProofs()
            }
            .refreshable {
                await loadAllProofs()
            }
            .confirmationDialog(
                "Delete Selected Proofs",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(selectedProofCount) Proofs (\(selectedProofAmount) sats)", role: .destructive) {
                    Task { await deleteSelectedProofs() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the selected proofs from your wallet. This action cannot be undone.")
            }
            .alert("Delete Error", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: {
                if let error = deleteError {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private var proofsList: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Proofs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(allProofEntries.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if !selectedProofs.isEmpty {
                        VStack(alignment: .trailing) {
                            Text("Selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(selectedProofCount) (\(selectedProofAmount) sats)")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Mints and their proofs
            ForEach(groupedProofs.keys.sorted(), id: \.self) { mint in
                if let proofs = groupedProofs[mint] {
                    Section {
                        ForEach(proofs.sorted { $0.proof.amount > $1.proof.amount }, id: \.proof.C) { entry in
                            ProofManagementRow(
                                entry: entry,
                                validationState: validationResults[mint]?[entry.proof.C],
                                isSelected: selectedProofs.contains(entry.proof.C),
                                onToggleSelection: { toggleSelection(entry.proof.C) }
                            )
                        }
                    } header: {
                        HStack {
                            Text(formatMintName(mint))
                            Spacer()
                            if let balance = mintBalances[mint] {
                                Text("\(balance) sats")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 16) {
                if !selectedProofs.isEmpty {
                    Button(action: { selectedProofs.removeAll() }) {
                        Text("Clear")
                            .font(.caption)
                    }
                    
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(isDeleting)
                }
                
                Button(action: { Task { await validateAllProofs() } }) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Validate", systemImage: "checkmark.shield")
                    }
                }
                .disabled(isValidating || isDeleting)
            }
        }
    }
    
    private func toggleSelection(_ proofC: String) {
        if selectedProofs.contains(proofC) {
            selectedProofs.remove(proofC)
        } else {
            selectedProofs.insert(proofC)
        }
    }
    
    private func loadAllProofs() async {
        isLoading = true
        
        guard let wallet = walletManager.wallet else {
            await MainActor.run { isLoading = false }
            return
        }
        
        // Get all proof entries
        let entries = await wallet.proofStateManager.getAllEntries()
            .filter { $0.state != ProofStateManager.ProofState.deleted }
        
        // Calculate balances per mint
        var balances: [String: Int64] = [:]
        for entry in entries where entry.state == ProofStateManager.ProofState.available {
            balances[entry.mint, default: 0] += Int64(entry.proof.amount)
        }
        
        await MainActor.run {
            self.allProofEntries = entries
            self.mintBalances = balances
            self.isLoading = false
        }
    }
    
    private func validateAllProofs() async {
        isValidating = true
        validationResults.removeAll()
        
        guard let wallet = walletManager.wallet else {
            await MainActor.run { isValidating = false }
            return
        }
        
        // Validate proofs for each mint
        for (mint, _) in groupedProofs {
            guard let mintURL = URL(string: mint) else { continue }
            
            do {
                let states = try await wallet.checkProofStates(mintURL: mintURL)
                await MainActor.run {
                    validationResults[mint] = states
                }
            } catch {
                print("Failed to validate proofs for mint \(mint): \(error)")
            }
        }
        
        await MainActor.run {
            isValidating = false
        }
    }
    
    private func deleteSelectedProofs() async {
        isDeleting = true
        deleteError = nil
        
        guard let wallet = walletManager.wallet else {
            await MainActor.run { isDeleting = false }
            return
        }
        
        do {
            // Get the proofs to delete
            _ = allProofEntries
                .filter { selectedProofs.contains($0.proof.C) }
                .map { $0.proof }
            
            // Group proofs by mint
            var proofsByMint: [String: [CashuSwift.Proof]] = [:]
            for entry in allProofEntries where selectedProofs.contains(entry.proof.C) {
                proofsByMint[entry.mint, default: []].append(entry.proof)
            }
            
            // Create wallet state change for each mint
            for (mint, proofs) in proofsByMint {
                let stateChange = WalletStateChange(
                    store: [],
                    destroy: proofs,
                    mint: mint,
                    memo: "Manual proof deletion"
                )
                
                // Use the wallet's update method which properly creates token events with del tags
                _ = try await wallet.update(stateChange: stateChange)
            }
            
            // Reload proofs
            await loadAllProofs()
            
            await MainActor.run {
                selectedProofs.removeAll()
                isDeleting = false
            }
        } catch {
            await MainActor.run {
                deleteError = error
                isDeleting = false
            }
        }
    }
    
    private func formatMintName(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        return host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "mint.", with: "")
    }
}

// MARK: - Proof Management Row
struct ProofManagementRow: View {
    let entry: ProofStateManager.ProofEntry
    let validationState: CashuSwift.Proof.ProofState?
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var stateIndicator: (color: Color, icon: String, text: String) {
        if let validationState = validationState {
            switch validationState {
            case .unspent:
                return (.green, "checkmark.circle.fill", "Valid")
            case .spent:
                return (.red, "xmark.circle.fill", "Spent")
            case .pending:
                return (.orange, "clock.fill", "Pending")
            }
        }
        
        switch entry.state {
        case .available:
            return (.blue, "circle", "Available")
        case .reserved:
            return (.orange, "lock.circle", "Reserved")
        case .deleted:
            return (.red, "trash.circle", "Deleted")
        }
    }
    
    var isSelectable: Bool {
        // Only allow selection of spent or problematic proofs
        if let validationState = validationState {
            return validationState == .spent
        }
        return entry.state == .available
    }
    
    var body: some View {
        HStack {
            // Selection checkbox
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .orange : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!isSelectable)
            .opacity(isSelectable ? 1.0 : 0.3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(entry.proof.amount) sats")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: stateIndicator.icon)
                            .font(.caption)
                        Text(stateIndicator.text)
                            .font(.caption)
                    }
                    .foregroundColor(stateIndicator.color)
                }
                
                HStack {
                    Text("C: " + entry.proof.C.prefix(12) + "...")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    if let eventId = entry.ownerEventId {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("Event: " + eventId.prefix(8) + "...")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(validationState == .spent ? 0.6 : 1.0)
    }
}