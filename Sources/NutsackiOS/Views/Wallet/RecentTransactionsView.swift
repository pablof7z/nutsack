import SwiftUI
import SwiftData
import NDKSwift

struct RecentTransactionsView: View {
    @Environment(WalletManager.self) private var walletManager
    
    // Use reactive transactions from wallet manager
    private var recentTransactions: [Transaction] {
        Array(walletManager.transactions.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: TransactionHistoryView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            if recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No transactions yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .animation(.easeInOut(duration: 0.3), value: transaction.status)
                    }
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager
    @State private var senderProfile: NDKUserProfile?
    @State private var recipientProfile: NDKUserProfile?
    @State private var showDetailDrawer = false
    @State private var mintInfo: NDKMintInfo?
    
    var icon: String {
        switch transaction.type {
        case .mint, .deposit: return "bolt.fill"
        case .melt, .withdraw: return "bolt"
        case .send: return "arrow.up"
        case .receive: return "arrow.down"
        case .nutzap: return "bolt.heart.fill"
        case .swap: return "arrow.2.circlepath"
        }
    }
    
    var color: Color {
        // Failed transactions should always show in red
        if transaction.status == .failed {
            return .red
        }
        
        switch transaction.type {
        case .mint, .deposit, .receive, .nutzap: return .green  // Nutzaps are received, so green
        case .melt, .withdraw, .send: return .orange
        case .swap: return .blue
        }
    }
    
    var sign: String {
        // Don't show a sign for failed transactions
        if transaction.status == .failed {
            return ""
        }
        
        switch transaction.direction {
        case .incoming: return "+"
        case .outgoing: return "-"
        case .neutral: return ""
        }
    }
    
    var displayText: String {
        if transaction.type == .nutzap {
            // For incoming nutzaps (received), show sender
            if transaction.direction == .incoming {
                if let senderProfile = senderProfile {
                    let senderName = senderProfile.name ?? senderProfile.displayName ?? "Anonymous"
                    return "Zap from \(senderName)"
                } else if let senderPubkey = transaction.senderPubkey {
                    return "Zap from \(senderPubkey.prefix(8))..."
                } else {
                    return "Zap received"
                }
            }
            // For outgoing nutzaps (sent), show recipient
            else if transaction.direction == .outgoing {
                if let recipientProfile = recipientProfile {
                    let recipientName = recipientProfile.name ?? recipientProfile.displayName ?? "Anonymous"
                    return "Zap to \(recipientName)"
                } else if let recipientPubkey = transaction.recipientPubkey {
                    return "Zap to \(recipientPubkey.prefix(8))..."
                } else {
                    return "Zap sent"
                }
            } else {
                return "Zap"
            }
        } else if let memo = transaction.memo {
            return memo
        } else {
            return transaction.type.displayName
        }
    }
    
    var body: some View {
        Button(action: { showDetailDrawer = true }) {
            HStack {
                // Avatar for nutzaps, icon for other transactions
                if transaction.type == .nutzap {
                    let profile = transaction.direction == .incoming ? senderProfile : recipientProfile
                    let pubkey = transaction.direction == .incoming ? transaction.senderPubkey : transaction.recipientPubkey
                    
                    if pubkey != nil {
                        ZStack {
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
                                            .foregroundColor(.secondary)
                                    )
                            }
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    
                    // Overlay icon based on status
                    if transaction.status == .failed {
                        // Failed icon
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .background(Circle().fill(.white).frame(width: 14, height: 14))
                            .offset(x: 10, y: -10)
                    } else {
                        // Normal zap icon
                        Image(systemName: "bolt.heart.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .background(Circle().fill(.white).frame(width: 12, height: 12))
                            .offset(x: 10, y: -10)
                    }
                        }
                        .frame(width: 30, height: 30)
                    } else {
                        // Fallback to icon if no pubkey
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(color)
                            .frame(width: 30)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(color)
                        .frame(width: 30)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Show mint info or nutzap comment or transaction type
                if let mintURL = transaction.mintURL {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .font(.caption2)
                        Text(mintInfo?.name ?? URL(string: mintURL)?.host ?? mintURL)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                } else if transaction.type == .nutzap && transaction.memo != nil && !transaction.memo!.isEmpty {
                    Text(transaction.memo!)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if transaction.memo != nil && transaction.type != .nutzap {
                    Text(transaction.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(sign)\(transaction.amount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(color)
                    
                    // Show pending indicator
                    if transaction.status == .pending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                }
                
                RelativeTimeView(date: transaction.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(transaction.status == .pending ? 0.85 : (transaction.status == .failed ? 0.7 : 1.0))
        .sheet(isPresented: $showDetailDrawer) {
            TransactionDetailDrawer(transaction: transaction)
        }
        .task {
            // Fetch sender profile for incoming nutzaps
            if transaction.type == .nutzap, 
               transaction.direction == .incoming,
               let senderPubkey = transaction.senderPubkey,
               let ndk = nostrManager.ndk {
                
                // Use declarative data source for profile
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
            
            // Fetch recipient profile for outgoing nutzaps
            if transaction.type == .nutzap,
               transaction.direction == .outgoing,
               let recipientPubkey = transaction.recipientPubkey,
               let ndk = nostrManager.ndk {
                
                // Use declarative data source for profile
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
            
            // Fetch mint info if we have a mint URL
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
    }
}

// MARK: - Transaction History View
struct TransactionHistoryView: View {
    @Environment(WalletManager.self) private var walletManager
    
    @State private var selectedFilter: TransactionFilter = .all
    
    enum TransactionFilter: String, CaseIterable {
        case all = "All"
        case sent = "Sent"
        case received = "Received"
        
        func matches(_ transaction: Transaction) -> Bool {
            switch self {
            case .all: return true
            case .sent: return [.send, .melt, .withdraw, .swap].contains(transaction.type)
            case .received: return [.receive, .mint, .deposit, .nutzap].contains(transaction.type)
            }
        }
    }
    
    var filteredTransactions: [Transaction] {
        walletManager.transactions
            .filter { selectedFilter.matches($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Transactions
            ForEach(filteredTransactions) { transaction in
                TransactionDetailRow(transaction: transaction)
            }
        }
        .navigationTitle("Transaction History")
        .platformNavigationBarTitleDisplayMode(inline: true)
        .listStyle(.plain)
    }
}

struct TransactionDetailRow: View {
    let transaction: Transaction
    @State private var showOfflineToken = false
    @State private var showDetailDrawer = false
    @State private var mintInfo: NDKMintInfo?
    @Environment(WalletManager.self) private var walletManager
    
    var body: some View {
        Button(action: { showDetailDrawer = true }) {
            VStack(alignment: .leading, spacing: 8) {
                TransactionRow(transaction: transaction)
            
            if transaction.status != .completed {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(transaction.status.rawValue.capitalized)
                        .font(.caption2)
                }
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            
            // Show mint info if available and not already shown in TransactionRow
            if let mintURL = transaction.mintURL,
               transaction.type != .nutzap || transaction.memo == nil || transaction.memo!.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.caption2)
                    Text(mintInfo?.name ?? URL(string: mintURL)?.host ?? mintURL)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            
            // Show offline token button if available
            if transaction.offlineToken != nil && transaction.type == .send {
                Button(action: { showOfflineToken = true }) {
                    HStack {
                        Image(systemName: "qrcode")
                            .font(.caption)
                        Text("View Token")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.secondary.opacity(0.1))
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .sheet(isPresented: $showDetailDrawer) {
            TransactionDetailDrawer(transaction: transaction)
        }
        .sheet(isPresented: $showOfflineToken) {
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
        .task {
            // Fetch mint info if we have a mint URL
            if let mintURL = transaction.mintURL,
               let wallet = walletManager.activeWallet,
               let url = URL(string: mintURL) {
                
                do {
                    mintInfo = try await wallet.mints.getMintInfo(url: url)
                } catch {
                    // Silently fail - we'll just show the URL
                }
            }
        }
    }
}

// Transaction.TransactionType extension moved to DataModels.swift

