import SwiftUI
import SwiftData
import NDKSwift

struct SwapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    
    @State private var sourceMint: MintBalance?
    @State private var destinationMint: MintBalance?
    @State private var isSwapping = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var transferResult: TransferResult?
    
    @State private var mintBalances: [MintBalance] = []
    
    // Allocation slider
    @State private var allocationPercentage: Double = 50.0
    
    var transferAmount: Int64 {
        guard let source = sourceMint, let destination = destinationMint else { return 0 }
        let totalBalance = source.balance + destination.balance
        let targetSourceBalance = Int64(Double(totalBalance) * (allocationPercentage / 100.0))
        return source.balance - targetSourceBalance
    }
    
    var canSwap: Bool {
        guard let source = sourceMint else { return false }
        guard let destination = destinationMint else { return false }
        guard source.url != destination.url else { return false }
        guard transferAmount > 0 else { return false }
        guard source.balance >= transferAmount else { return false }
        guard !isSwapping else { return false }
        return true
    }
    
    @ViewBuilder
    var allocationSection: some View {
        if let source = sourceMint, let destination = destinationMint {
            Section {
                VStack(spacing: 16) {
                    // Visual representation
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 8, height: 8)
                                Text(source.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text("\(Int64(Double(source.balance + destination.balance) * (allocationPercentage / 100.0))) sats")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        // Flow arrow
                        VStack {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("\(abs(transferAmount)) sats")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text(destination.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                            }
                            Text("\(Int64(Double(source.balance + destination.balance) * ((100.0 - allocationPercentage) / 100.0))) sats")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    
                    // Allocation slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("0%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(allocationPercentage))% / \(100 - Int(allocationPercentage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text("100%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $allocationPercentage, in: 0...100, step: 1)
                            .tint(.orange)
                    }
                }
            } header: {
                Text("Balance Allocation")
            } footer: {
                if transferAmount != 0 {
                    Text("Transfer \(abs(transferAmount)) sats between mints")
                } else {
                    Text("Balances are already allocated as desired")
                }
            }
        }
    }
    
    @ViewBuilder
    var mintPickerSection: some View {
        Section {
            HStack(spacing: 16) {
                // Source mint selector
                Menu {
                    ForEach(mintBalances.filter { $0.balance > 0 }, id: \.url) { mintBalance in
                        Button(action: { sourceMint = mintBalance }) {
                            HStack {
                                Text(mintBalance.displayName)
                                Spacer()
                                Text("\(mintBalance.balance) sats")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(.white)
                            }
                        Text(sourceMint?.displayName ?? "Select Mint")
                            .font(.caption)
                            .lineLimit(1)
                        if let source = sourceMint {
                            Text("\(source.balance) sats")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                
                // Swap button
                Button(action: swapMints) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .disabled(sourceMint == nil || destinationMint == nil)
                
                // Destination mint selector
                Menu {
                    ForEach(mintBalances, id: \.url) { mintBalance in
                        Button(action: { destinationMint = mintBalance }) {
                            HStack {
                                Text(mintBalance.displayName)
                                Spacer()
                                Text("\(mintBalance.balance) sats")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(.white)
                            }
                        Text(destinationMint?.displayName ?? "Select Mint")
                            .font(.caption)
                            .lineLimit(1)
                        if let destination = destinationMint {
                            Text("\(destination.balance) sats")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Select Mints")
        }
    }
    
    
    @ViewBuilder
    var actionSection: some View {
        Section {
            Button(action: performSwap) {
                if isSwapping {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Transfer")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!canSwap)
        }
    }
    
    var body: some View {
        Form {
            mintPickerSection
            allocationSection
            actionSection
        }
        .navigationTitle("Balance Reconcile")
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
        .alert("Transfer Successful", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            if let result = transferResult {
                Text("Transferred \(result.amountTransferred) sats\nFee paid: \(result.feePaid) sats")
            }
        }
        .onChange(of: sourceMint) { _, _ in
            updateAllocationPercentage()
        }
        .onChange(of: destinationMint) { _, _ in
            updateAllocationPercentage()
        }
        .onAppear {
            loadMintBalances()
        }
    }
    
    
    private func swapMints() {
        let temp = sourceMint
        sourceMint = destinationMint
        destinationMint = temp
    }
    
    private func updateAllocationPercentage() {
        guard let source = sourceMint, let destination = destinationMint else { return }
        let totalBalance = source.balance + destination.balance
        if totalBalance > 0 {
            allocationPercentage = Double(source.balance) / Double(totalBalance) * 100.0
        }
    }
    
    
    private func performSwap() {
        guard canSwap else { return }
        
        let actualTransferAmount = abs(transferAmount)
        let actualSource = transferAmount > 0 ? sourceMint! : destinationMint!
        let actualDestination = transferAmount > 0 ? destinationMint! : sourceMint!
        
        isSwapping = true
        
        Task {
            do {
                let result = try await walletManager.transferBetweenMints(
                    amount: actualTransferAmount,
                    fromMint: actualSource.url,
                    toMint: actualDestination.url
                )
                
                await MainActor.run {
                    transferResult = result
                    showSuccess = true
                    isSwapping = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSwapping = false
                }
            }
        }
    }
    
    private func loadMintBalances() {
        Task {
            guard let wallet = walletManager.activeWallet else { return }
            
            // Get balances by mint from the wallet
            let balancesByMint = await wallet.getBalancesByMint()
            
            // Create MintBalance objects
            let loadedMintBalances = balancesByMint.map { (mintUrl, balance) in
                MintBalance(url: URL(string: mintUrl)!, balance: balance)
            }.sorted { $0.balance > $1.balance } // Sort by balance descending
            
            await MainActor.run {
                mintBalances = loadedMintBalances
                
                // Auto-select the two mints with highest balances
                if mintBalances.count >= 2 {
                    sourceMint = mintBalances[0]
                    destinationMint = mintBalances[1]
                    updateAllocationPercentage()
                } else if mintBalances.count == 1 {
                    sourceMint = mintBalances[0]
                }
            }
        }
    }
}

// MARK: - Supporting Types
struct MintBalance: Hashable {
    let url: URL
    let balance: Int64
    
    var displayName: String {
        url.host ?? url.absoluteString
    }
}

