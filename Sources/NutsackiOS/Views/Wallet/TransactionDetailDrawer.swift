import SwiftUI
import NDKSwift
import CashuSwift
#if os(iOS)
import UIKit
#endif

struct TransactionDetailDrawer: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager
    @State private var senderProfile: NDKUserProfile?
    @State private var recipientProfile: NDKUserProfile?
    @State private var showTokenDetail = false
    @State private var showShareSheet = false
    @State private var copiedToClipboard = false
    @State private var copiedBech32 = false
    @State private var mintInfo: NDKMintInfo?
    @State private var loadedNostrEvent: NDKEvent?
    
    private var formattedDate: String {
        DateFormatters.display.string(from: transaction.createdAt)
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .completed: return .green
        case .pending, .processing: return .orange
        case .failed, .expired: return .red
        }
    }
    
    private var directionIcon: String {
        switch transaction.direction {
        case .incoming: return "arrow.down.circle.fill"
        case .outgoing: return "arrow.up.circle.fill"
        case .neutral: return "arrow.2.circlepath.circle.fill"
        }
    }
    
    private var directionColor: Color {
        switch transaction.direction {
        case .incoming: return .green
        case .outgoing: return .orange
        case .neutral: return .blue
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // For Nutzaps, show the user avatar prominently
            if transaction.type == .nutzap {
                let profile = transaction.direction == .incoming ? senderProfile : recipientProfile
                let pubkey = transaction.direction == .incoming ? transaction.senderPubkey : transaction.recipientPubkey
                
                if let pubkey = pubkey {
                    VStack(spacing: 12) {
                        // User avatar
                        AsyncImage(url: URL(string: profile?.picture ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            // Direction indicator
                            Image(systemName: transaction.direction == .incoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(directionColor)
                                .background(Circle().fill(.white).frame(width: 30, height: 30))
                                .offset(x: 25, y: 25)
                        )
                        
                        // User name
                        VStack(spacing: 4) {
                            Text(transaction.direction == .incoming ? "From" : "To")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let profile = profile {
                                Text(profile.name ?? profile.displayName ?? "Anonymous")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Text(pubkey.prefix(16) + "...")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
            } else {
                // Regular transaction icon
                Image(systemName: directionIcon)
                    .font(.system(size: 50))
                    .foregroundStyle(directionColor)
            }
            
            // Amount
            Text("\(transaction.direction == .outgoing ? "-" : "+")\(transaction.amount) sats")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(directionColor)
            
            // Transaction Type
            Text(transaction.type.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    
                    // Transaction Details
                    VStack(alignment: .leading, spacing: 16) {
                        // Status
                        TransactionInfoRow(
                            label: "Status",
                            value: transaction.status.rawValue.capitalized,
                            valueColor: statusColor,
                            icon: statusIcon(for: transaction.status)
                        )
                        
                        // Error details for failed transactions
                        if transaction.status == .failed, let errorDetails = transaction.errorDetails {
                            TransactionInfoRow(
                                label: "Error",
                                value: errorDetails,
                                valueColor: .red,
                                icon: "exclamationmark.triangle",
                                multiline: true
                            )
                        }
                        
                        // Date and Time
                        TransactionInfoRow(
                            label: "Date",
                            value: formattedDate,
                            icon: "calendar"
                        )
                        
                        // Memo/Description
                        if let memo = transaction.memo, !memo.isEmpty {
                            TransactionInfoRow(
                                label: "Memo",
                                value: memo,
                                icon: "text.alignleft",
                                multiline: true
                            )
                        }
                        
                        // Mint URL
                        if let mintURL = transaction.mintURL {
                            TransactionInfoRow(
                                label: "Mint",
                                value: mintInfo?.name ?? URL(string: mintURL)?.host ?? mintURL,
                                icon: "server.rack",
                                action: {
                                    if let url = URL(string: mintURL) {
                                        #if os(iOS)
                                        UIApplication.shared.open(url)
                                        #endif
                                    }
                                }
                            )
                            
                            // Show mint description if available
                            if let description = mintInfo?.description, !description.isEmpty {
                                TransactionInfoRow(
                                    label: "Mint Info",
                                    value: description,
                                    icon: "info.circle",
                                    multiline: true
                                )
                            }
                        }
                        
                        // Lightning Invoice
                        if let invoice = transaction.lightningInvoice {
                            TransactionInfoRow(
                                label: "Lightning Invoice",
                                value: String(invoice.prefix(20)) + "...",
                                icon: "bolt",
                                action: {
                                    #if os(iOS)
                                    UIPasteboard.general.string = invoice
                                    #endif
                                    withAnimation {
                                        copiedToClipboard = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedToClipboard = false
                                    }
                                }
                            )
                            
                            if copiedToClipboard {
                                Text("Copied to clipboard!")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.opacity)
                            }
                        }
                        
                        // Nostr Event
                        if transaction.nostrEventID != nil {
                            HStack {
                                TransactionInfoRow(
                                    label: "Nostr Event",
                                    value: "View event details",
                                    icon: "link"
                                )
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    // Copy button
                                    if let event = loadedNostrEvent,
                                       let bech32 = try? event.encode(includeRelays: true) {
                                        Button(action: {
                                            #if os(iOS)
                                            UIPasteboard.general.string = bech32
                                            #endif
                                            withAnimation {
                                                copiedBech32 = true
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                copiedBech32 = false
                                            }
                                        }) {
                                            Image(systemName: copiedBech32 ? "checkmark.circle.fill" : "doc.on.doc")
                                                .foregroundColor(copiedBech32 ? .green : .accentColor)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // Open in njump.me button
                                        Button(action: {
                                            if let url = URL(string: "https://njump.me/\(bech32)") {
                                                #if os(iOS)
                                                UIApplication.shared.open(url)
                                                #endif
                                            }
                                        }) {
                                            Image(systemName: "arrow.up.forward.square")
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if copiedBech32 {
                                Text("Copied to clipboard!")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.opacity)
                                    .padding(.horizontal)
                            }
                        }
                        
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // View Token Button
                        if transaction.offlineToken != nil && (transaction.type == .send || transaction.type == .receive) {
                            Button(action: { showTokenDetail = true }) {
                                Label("View Token", systemImage: "qrcode")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        
                        // Share Transaction Button
                        Button(action: { showShareSheet = true }) {
                            Label("Share Transaction", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadProfiles()
        }
        .sheet(isPresented: $showTokenDetail) {
            if let token = transaction.offlineToken {
                TokenConfirmationView(
                    token: token,
                    amount: transaction.amount,
                    memo: transaction.memo ?? "",
                    mintURL: transaction.mintURL.flatMap { URL(string: $0) },
                    isOfflineMode: true,
                    onDismiss: { }
                )
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [transactionShareText()])
        }
        #endif
    }
    
    private func statusIcon(for status: Transaction.TransactionStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .processing: return "arrow.trianglehead.2.clockwise"
        case .failed: return "xmark.circle.fill"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }
    
    private func loadProfiles() async {
        guard let ndk = nostrManager.ndk else { return }
        
        // Load Nostr event if we have an event ID
        if let eventID = transaction.nostrEventID {
            let eventDataSource = ndk.observe(
                filter: NDKFilter(
                    ids: [eventID]
                ),
                maxAge: 3600,
                cachePolicy: .cacheWithNetwork
            )
            
            for await event in eventDataSource.events {
                loadedNostrEvent = event
                break
            }
        }
        
        // Load sender profile
        if let senderPubkey = transaction.senderPubkey {
            let profileDataSource = ndk.observe(
                filter: NDKFilter(
                    authors: [senderPubkey],
                    kinds: [0]
                ),
                maxAge: 3600,
                cachePolicy: .cacheWithNetwork
            )
            
            for await event in profileDataSource.events {
                if let profileData = event.content.data(using: .utf8),
                   let profile = JSONCoding.safeDecode(NDKUserProfile.self, from: profileData) {
                    senderProfile = profile
                    break
                }
            }
        }
        
        // Load recipient profile
        if let recipientPubkey = transaction.recipientPubkey {
            let profileDataSource = ndk.observe(
                filter: NDKFilter(
                    authors: [recipientPubkey],
                    kinds: [0]
                ),
                maxAge: 3600,
                cachePolicy: .cacheWithNetwork
            )
            
            for await event in profileDataSource.events {
                if let profileData = event.content.data(using: .utf8),
                   let profile = JSONCoding.safeDecode(NDKUserProfile.self, from: profileData) {
                    recipientProfile = profile
                    break
                }
            }
        }
        
        // Load mint info
        if let mintURL = transaction.mintURL,
           let wallet = walletManager.activeWallet,
           let url = URL(string: mintURL) {
            
            do {
                mintInfo = try await wallet.mints.getMintInfo(url: url)
            } catch {
                // Silently fail - we'll just show the URL
                NDKLogger.log(.debug, category: .wallet, "Failed to fetch mint info for \(mintURL): \(error)")
            }
        }
    }
    
    private func transactionShareText() -> String {
        var text = "Transaction Details\n"
        text += "==================\n\n"
        text += "Type: \(transaction.type.displayName)\n"
        text += "Amount: \(transaction.amount) sats\n"
        text += "Status: \(transaction.status.rawValue.capitalized)\n"
        text += "Date: \(formattedDate)\n"
        
        if let memo = transaction.memo, !memo.isEmpty {
            text += "Memo: \(memo)\n"
        }
        
        if let eventID = transaction.nostrEventID {
            text += "\nNostr Event ID: \(eventID)\n"
            
            if let event = loadedNostrEvent,
               let bech32 = try? event.encode(includeRelays: true) {
                text += "Bech32 Event: \(bech32)\n"
                text += "View on njump.me: https://njump.me/\(bech32)\n"
            }
        }
        
        return text
    }
}

// MARK: - Supporting Views

struct TransactionInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var icon: String? = nil
    var multiline: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon ?? "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let action = action {
                Button(action: action) {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(valueColor)
                        .multilineTextAlignment(multiline ? .leading : .trailing)
                        .lineLimit(multiline ? nil : 1)
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .font(.body)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(multiline ? .leading : .trailing)
                    .lineLimit(multiline ? nil : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileDetailRow: View {
    let label: String
    let pubkey: String
    let profile: NDKUserProfile?
    
    private var displayName: String {
        if let profile = profile {
            return profile.name ?? profile.displayName ?? pubkey.prefix(16) + "..."
        }
        return pubkey.prefix(16) + "..."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: "person.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                if let picture = profile?.picture, let url = URL(string: picture) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                
                Text(displayName)
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

