import SwiftUI
import SwiftData
import NDKSwift
import CashuSwift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WalletManager.self) private var walletManager
    
    @State private var amount = ""
    @State private var memo = ""
    @State private var selectedMintURL: URL?
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedToken: String?
    @State private var showTokenView = false
    
    @State private var availableBalance: Int = 0
    @State private var mints: [MintInfo] = []
    @State private var mintBalances: [String: Int64] = [:] // mint URL to balance
    @State private var isOfflineMode = false
    
    // Offline mode states
    @State private var availableAmounts: [Int64] = []
    @State private var proofCombinations: [Int64: [CashuSwift.Proof]] = [:]
    @State private var selectedAmount: Int64?
    @State private var availableProofs: [CashuSwift.Proof] = []
    @State private var pickerAmounts: [Int64] = []
    @State private var selectedPickerIndex = 0
    @State private var isLoadingOfflineAmounts = false
    
    @FocusState private var amountFieldFocused: Bool
    
    // Common amounts to suggest
    private let commonAmounts: [Int64] = AmountPresets.extendedAmounts.map { Int64($0) }
    
    var availableBalanceForMint: Int {
        return availableBalance
    }
    
    var amountInt: Int {
        Int(amount) ?? 0
    }
    
    var formattedAmount: String {
        if amount.isEmpty {
            return "0"
        }
        
        if let number = Int(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: number)) ?? amount
        }
        return amount
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount Section
                    VStack(spacing: 16) {
                        if !isOfflineMode {
                            // Hidden text field that drives the amount
                            TextField("0", text: $amount)
                                .keyboardType(.numberPad)
                                .opacity(0)
                                .frame(height: 0)
                                .focused($amountFieldFocused)
                            
                            // Visual amount display (same style as MintView)
                            VStack(spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(formattedAmount)
                                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    
                                    Text("sats")
                                        .font(.system(size: 20, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    amountFieldFocused = true
                                }
                                
                                // Available balance
                                Text("Available: \(availableBalanceForMint) sats")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(amountInt > availableBalanceForMint ? .red : .secondary)
                                    .opacity(0.8)
                            }
                        }
                        
                        // Offline mode toggle (moved under input)
                        VStack(spacing: 12) {
                            Toggle("Offline Mode", isOn: $isOfflineMode)
                                .tint(.orange)
                                .padding(.horizontal)
                            
                            Text(isOfflineMode ? 
                                 "" : 
                                 "Send tokens directly with network connection")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Offline mode amount selection
                    if isOfflineMode && selectedMintURL != nil && isLoadingOfflineAmounts {
                        // Show loading indicator
                        VStack(spacing: 12) {
                            Text("Select Amount")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack {
                                Spacer()
                                ProgressView("Loading available amounts...")
                                    .padding()
                                Spacer()
                            }
                        }
                    } else if isOfflineMode && selectedMintURL != nil && !availableAmounts.isEmpty {
                        // Offline mode: Amount picker
                        VStack(spacing: 16) {
                            Text("Select Amount")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Picker wheel
                            Picker("Amount", selection: $selectedPickerIndex) {
                                ForEach(Array(pickerAmounts.enumerated()), id: \.offset) { index, amount in
                                    HStack(spacing: 8) {
                                        Text(formatAmount(amount))
                                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        Text("sats")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    .tag(index)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .clipped()
                            .onChange(of: selectedPickerIndex) { _, newIndex in
                                if newIndex < pickerAmounts.count {
                                    selectedAmount = pickerAmounts[newIndex]
                                }
                            }
                            
                        }
                    }
                    
                    // Mint Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Mint")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if !mints.isEmpty {
                            // Filter to only show mints with balance
                            let mintsWithBalance = mints.filter { mintBalances[$0.url.absoluteString] ?? 0 > 0 }
                            
                            if mintsWithBalance.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text("No mints with available balance")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // Auto-select option
                                        VStack(spacing: 8) {
                                            Circle()
                                                .fill(selectedMintURL == nil ? Color.orange : Color.orange.opacity(0.15))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Image(systemName: "sparkles")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(selectedMintURL == nil ? .white : .orange)
                                                )
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedMintURL == nil ? Color.orange : Color.clear, lineWidth: 2)
                                                )
                                            
                                            VStack(spacing: 2) {
                                                Text("Auto")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                let totalBalance = mintBalances.values.reduce(0, +)
                                                Text("\(totalBalance) sats")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .frame(width: 70)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedMintURL = nil
                                        }
                                        
                                        // Mints with balance, sorted by balance (highest first)
                                        ForEach(mintsWithBalance.sorted(by: { 
                                            (mintBalances[$0.url.absoluteString] ?? 0) > (mintBalances[$1.url.absoluteString] ?? 0)
                                        }), id: \.url.absoluteString) { mint in
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(selectedMintURL == mint.url ? Color.orange : Color.orange.opacity(0.15))
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Image(systemName: "building.columns")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(selectedMintURL == mint.url ? .white : .orange)
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .stroke(selectedMintURL == mint.url ? Color.orange : Color.clear, lineWidth: 2)
                                                    )
                                                
                                                VStack(spacing: 2) {
                                                    Text(mint.url.host ?? "Mint")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    
                                                    if let balance = mintBalances[mint.url.absoluteString] {
                                                        Text("\(balance) sats")
                                                            .font(.caption2)
                                                            .foregroundColor(.orange)
                                                    }
                                                }
                                            }
                                            .frame(width: 70)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedMintURL = mint.url
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        if isOfflineMode && selectedMintURL != nil && availableAmounts.isEmpty {
                            Text("This mint has no proofs that can be spent offline")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Memo Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Memo")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextField("Note (optional)", text: $memo, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(.horizontal)
                        
                        Text("Add a note for the recipient")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 140) // Add space for the fixed button and keyboard
            }
            
            // Generate Token Button - Outside ScrollView
            VStack {
                Divider()
                
                Button(action: generateToken) {
                    if isSending {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating...")
                        }
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                        .padding()
                        .background(Color.orange.opacity(0.3))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    } else {
                        Text("Generate Token")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .disabled(isOfflineMode ? 
                    (selectedAmount == nil || isSending || selectedMintURL == nil) :
                    (amount.isEmpty || amountInt <= 0 || amountInt > availableBalanceForMint || isSending || availableBalanceForMint == 0))
                .padding()
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Send Ecash")
        .platformNavigationBarTitleDisplayMode(inline: true)
        #if os(iOS)
        .ignoresSafeArea(.keyboard, edges: [])
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    amountFieldFocused = false
                }
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Generate Token") { 
                    generateToken()
                }
                .foregroundColor(.orange)
                .disabled(isOfflineMode ? 
                    (selectedAmount == nil || isSending || selectedMintURL == nil) :
                    (amount.isEmpty || amountInt <= 0 || amountInt > availableBalanceForMint || isSending || availableBalanceForMint == 0))
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showTokenView) {
            TokenConfirmationView(
                token: generatedToken,
                amount: isOfflineMode ? Int(selectedAmount ?? 0) : amountInt,
                memo: memo,
                mintURL: selectedMintURL,
                isOfflineMode: isOfflineMode,
                onDismiss: {
                    // Navigate back to wallet when done
                    dismiss()
                }
            )
        }
        .onAppear {
            loadMints()
            updateAvailableBalance()
        }
        .onChange(of: selectedMintURL) { _, _ in
            updateAvailableBalance()
            if isOfflineMode && selectedMintURL != nil {
                Task {
                    await loadAvailableAmounts()
                }
            }
        }
        .onChange(of: isOfflineMode) { _, newValue in
            if newValue && selectedMintURL != nil {
                Task {
                    await loadAvailableAmounts()
                }
            }
        }
    }
    
    private func generateToken() {
        if isOfflineMode {
            guard let selectedAmt = selectedAmount else { return }
            let amount = selectedAmt
            
            guard let proofs = proofCombinations[amount],
                  let mintURL = selectedMintURL else { return }
            
            guard !proofs.isEmpty else { return }
            
            isSending = true
            
            Task {
                do {
                    // Generate offline token
                    let (token, _) = try await walletManager.sendOffline(
                        proofs: proofs,
                        mint: mintURL,
                        memo: memo.isEmpty ? nil : memo
                    )
                    
                    await MainActor.run {
                        generatedToken = token
                        showTokenView = true
                        isSending = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        isSending = false
                    }
                }
            }
        } else {
            guard amountInt > 0 else { return }
            
            isSending = true
            
            Task {
                do {
                    // Show success immediately - the transaction appears as pending
                    await MainActor.run {
                        showTokenView = true
                    }
                    
                    // Generate ecash token (this creates pending transaction immediately)
                    let tokenString = try await walletManager.send(
                        amount: Int64(amountInt),
                        memo: memo.isEmpty ? nil : memo,
                        fromMint: selectedMintURL
                    )
                    
                    // Update with actual token
                    await MainActor.run {
                        generatedToken = tokenString
                        isSending = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                        isSending = false
                        showTokenView = false
                    }
                }
            }
        }
    }
    
    private func updateAvailableBalance() {
        Task {
            if let mintURL = selectedMintURL {
                let balance = await walletManager.activeWallet?.getBalance(mint: mintURL) ?? 0
                await MainActor.run {
                    availableBalance = Int(balance)
                }
            } else {
                // Get total balance
                do {
                    let totalBalance = try await walletManager.activeWallet?.getBalance() ?? 0
                    await MainActor.run {
                        availableBalance = Int(totalBalance)
                    }
                } catch {
                    print("Failed to get balance: \(error)")
                }
            }
        }
    }
    
    private func loadMints() {
        Task {
            guard let wallet = walletManager.activeWallet else { return }
            
            // Get balances for all mints (this gives us the full list like the pie chart)
            let balancesByMint = await wallet.getBalancesByMint()
            
            // Create mint info from all mints that have balances
            let loadedMints = balancesByMint.compactMap { (mintURL, _) -> MintInfo? in
                guard let url = URL(string: mintURL) else { return nil }
                return MintInfo(url: url, name: url.host ?? "Unknown Mint")
            }
            
            await MainActor.run {
                mints = loadedMints
                mintBalances = balancesByMint
                
                // Select the mint with the highest balance by default
                if let richestMint = balancesByMint.max(by: { $0.value < $1.value })?.key,
                   let richestURL = URL(string: richestMint) {
                    selectedMintURL = richestURL
                } else {
                    selectedMintURL = mints.first?.url
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }
    
    private func loadAvailableAmounts() async {
        guard let mintURL = selectedMintURL else { return }
        
        await MainActor.run {
            isLoadingOfflineAmounts = true
        }
        
        do {
            // Get real unspent proofs from wallet
            let proofsByMint = try await walletManager.getUnspentProofsByMint()
            
            guard let mintProofs = proofsByMint[mintURL] else {
                await MainActor.run {
                    availableProofs = []
                    availableAmounts = []
                    proofCombinations = [:]
                    pickerAmounts = []
                    isLoadingOfflineAmounts = false
                }
                return
            }
            
            print("Found \(mintProofs.count) proofs for mint \(mintURL)")
            
            // Sort proofs by amount (largest first)
            let sortedProofs = mintProofs.sorted(by: { $0.amount > $1.amount })
            
            // Use a smart approach that doesn't explode exponentially
            var amounts: [Int64] = []
            var combinations: [Int64: [CashuSwift.Proof]] = [:]
            
            // Calculate total available
            let totalAmount = sortedProofs.reduce(0) { $0 + Int64($1.amount) }
            print("Total available: \(totalAmount) sats from \(sortedProofs.count) proofs")
            
            // Always add the total amount option
            amounts.append(totalAmount)
            combinations[totalAmount] = sortedProofs
            
            // Add common denominations that we can definitely make
            for targetAmount in commonAmounts where targetAmount <= totalAmount {
                // Try to construct this amount using a greedy algorithm
                var remaining = targetAmount
                var usedProofs: [CashuSwift.Proof] = []
                let availableProofs = sortedProofs
                
                // First try to find exact matches
                if let exactMatch = availableProofs.first(where: { Int64($0.amount) == remaining }) {
                    usedProofs.append(exactMatch)
                    amounts.append(targetAmount)
                    combinations[targetAmount] = usedProofs
                    continue
                }
                
                // Otherwise use greedy approach - start with largest proofs
                for proof in availableProofs {
                    if Int64(proof.amount) <= remaining {
                        usedProofs.append(proof)
                        remaining -= Int64(proof.amount)
                        if remaining == 0 { break }
                    }
                }
                
                if remaining == 0 {
                    amounts.append(targetAmount)
                    combinations[targetAmount] = usedProofs
                }
            }
            
            // Add some intermediate amounts based on proof distribution
            // Group proofs by amount
            let proofsByAmount = Dictionary(grouping: sortedProofs, by: { Int64($0.amount) })
            
            // For each unique proof amount, offer multiples of it (if we have multiple)
            for (amount, proofs) in proofsByAmount where proofs.count > 1 {
                for multiplier in 1...min(5, proofs.count) {
                    let suggestedAmount = amount * Int64(multiplier)
                    if !amounts.contains(suggestedAmount) {
                        amounts.append(suggestedAmount)
                        combinations[suggestedAmount] = Array(proofs.prefix(multiplier))
                    }
                }
            }
            
            // Sort amounts
            let sortedAmounts = amounts.sorted().filter { $0 > 0 }
            
            await MainActor.run {
                availableProofs = sortedProofs
                availableAmounts = amounts
                proofCombinations = combinations
                pickerAmounts = sortedAmounts
                
                // Select middle amount by default
                if !sortedAmounts.isEmpty {
                    selectedPickerIndex = sortedAmounts.count / 2
                    selectedAmount = sortedAmounts[selectedPickerIndex]
                }
                isLoadingOfflineAmounts = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoadingOfflineAmounts = false
            }
        }
    }
    
    
}
