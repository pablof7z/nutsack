import SwiftUI
import NDKSwift

struct DiscoveredMintsView: View {
    let discoveredMints: [DiscoveredMint]
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    @State private var selectedMints: Set<String> = []
    @State private var isAdding = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if discoveredMints.isEmpty {
                    emptyStateView
                } else {
                    mintsList
                }
                
                // Bottom action bar
                if !selectedMints.isEmpty {
                    actionBar
                }
            }
            .navigationTitle("Discovered Mints")
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No mints discovered")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("No Cashu mints were found on the network")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var mintsList: some View {
        List {
            Section {
                ForEach(discoveredMints, id: \.url) { mint in
                    DiscoveredMintRow(
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
            } header: {
                Text("\(discoveredMints.count) mints discovered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Text("\(selectedMints.count) mint\(selectedMints.count == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: addSelectedMints) {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Add Selected")
                            .fontWeight(.medium)
                    }
                }
                .disabled(isAdding)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func addSelectedMints() {
        // Just dismiss - user should manage mints in wallet settings
        dismiss()
        
        // Show a message that they need to use wallet settings
        Task {
            await MainActor.run {
                errorMessage = "To add discovered mints, please use Wallet Settings."
                showError = true
            }
        }
    }
}

struct DiscoveredMintRow: View {
    let mint: DiscoveredMint
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                
                // Mint info
                VStack(alignment: .leading, spacing: 4) {
                    Text(mint.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let description = mint.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        // URL
                        Label(mint.url, systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        
                        // Pubkey if available
                        if let pubkey = mint.pubkey {
                            Label(String(pubkey.prefix(8)) + "...", systemImage: "person.circle")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}