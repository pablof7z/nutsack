//
//  BlacklistedMintsView.swift
//  NutsackiOS
//

import SwiftUI
import CashuSwift

#if !os(macOS)

// MARK: - Blacklisted Mints View
struct BlacklistedMintsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(WalletManager.self) private var walletManager
    @State private var showAddMintSheet = false
    @State private var availableMints: [String] = []

    var body: some View {
        List {
            if appState.blacklistedMints.isEmpty {
                ContentUnavailableView(
                    "No Blacklisted Mints",
                    systemImage: "xmark.shield",
                    description: Text("Blacklisted mints will not be used or shown in your wallet")
                )
            } else {
                Section {
                    ForEach(Array(appState.blacklistedMints).sorted(), id: \.self) { mintURL in
                        BlacklistedMintRowSettings(mintURL: mintURL) {
                            appState.unblacklistMint(mintURL)
                        }
                    }
                } header: {
                    Text("Blacklisted Mints")
                } footer: {
                    Text("These mints are blocked from being used in your wallet")
                }
            }

            Section {
                Button(action: { showAddMintSheet = true }) {
                    Label("Add to Blacklist", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Blacklisted Mints")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAddMintSheet) {
            AddToBlacklistSheet(
                currentMints: availableMints,
                blacklistedMints: appState.blacklistedMints
            ) { mintURL in
                appState.blacklistMint(mintURL)
            }
        }
        .task {
            await loadAvailableMints()
        }
    }

    private func loadAvailableMints() async {
        guard let wallet = walletManager.wallet else { return }
        let mintURLs = await wallet.mints.getMintURLs()
        await MainActor.run {
            availableMints = mintURLs
        }
    }
}

// MARK: - Blacklisted Mint Row for Settings
struct BlacklistedMintRowSettings: View {
    let mintURL: String
    let onUnblock: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "xmark.shield.fill")
                .foregroundColor(.red)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(URL(string: mintURL)?.host ?? "Unknown Mint")
                    .font(.headline)
                Text(mintURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Unblock") {
                onUnblock()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add to Blacklist Sheet
struct AddToBlacklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentMints: [String]
    let blacklistedMints: Set<String>
    let onBlock: (String) -> Void
    @State private var manualMintURL = ""

    var availableMintsToBlock: [String] {
        currentMints.filter { !blacklistedMints.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !availableMintsToBlock.isEmpty {
                    Section("Active Mints") {
                        ForEach(availableMintsToBlock, id: \.self) { mintURL in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(URL(string: mintURL)?.host ?? "Unknown Mint")
                                        .font(.headline)
                                    Text(mintURL)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button("Block") {
                                    onBlock(mintURL)
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    TextField("https://mint.example.com", text: $manualMintURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()

                    Button("Add to Blacklist") {
                        if !manualMintURL.isEmpty {
                            onBlock(manualMintURL)
                            dismiss()
                        }
                    }
                    .disabled(manualMintURL.isEmpty)
                } header: {
                    Text("Manual Entry")
                } footer: {
                    Text("Enter a mint URL to block it from being used")
                }
            }
            .navigationTitle("Add to Blacklist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#endif
