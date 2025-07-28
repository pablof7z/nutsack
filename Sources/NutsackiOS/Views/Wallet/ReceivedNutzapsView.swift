import SwiftUI
import NDKSwift

struct ReceivedNutzapsView: View {
    let walletManager: WalletManager
    @State private var nutzaps: [NutzapInfo] = []
    @State private var selectedFilter: NutzapStatusFilter = .all
    @State private var isRedeeming: Set<String> = []
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isRetryingAll: Bool = false
    
    var body: some View {
        List {
            // Summary section
            NutzapSummarySection(nutzaps: nutzaps)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                Text("All").tag(NutzapStatusFilter.all)
                Text("Pending").tag(NutzapStatusFilter.pending)
                Text("Redeemed").tag(NutzapStatusFilter.redeemed)
                Text("Failed").tag(NutzapStatusFilter.failed)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            
            // Nutzap list
            ForEach(filteredNutzaps) { nutzap in
                NutzapRow(
                    nutzap: nutzap,
                    isRedeeming: isRedeeming.contains(nutzap.eventId),
                    onRedeem: { await redeemNutzap(nutzap) }
                )
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle("Received Zaps")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if hasRetryableFailures {
                    Button("Retry All") {
                        Task { await retryAllFailed() }
                    }
                    .disabled(isRetryingAll)
                }
            }
        }
        .alert("Redemption Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadNutzaps()
        }
        .refreshable {
            await loadNutzaps()
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredNutzaps: [NutzapInfo] {
        nutzaps.filter { nutzap in
            switch selectedFilter {
            case .all:
                return true
            case .pending:
                if case .pending = nutzap.status { return true }
                return false
            case .redeemed:
                if case .redeemed = nutzap.status { return true }
                return false
            case .failed:
                if case .failed = nutzap.status { return true }
                return false
            case .retryableFailed:
                if case .failed(let error, _, _) = nutzap.status {
                    return error.isRetryable
                }
                return false
            }
        }
    }
    
    var hasRetryableFailures: Bool {
        nutzaps.contains { nutzap in
            if case .failed(let error, _, _) = nutzap.status {
                return error.isRetryable
            }
            return false
        }
    }
    
    var pendingAmount: Int64 {
        nutzaps.filter { nutzap in
            if case .pending = nutzap.status { return true }
            return false
        }.reduce(0) { $0 + $1.amount }
    }
    
    var redeemedAmount: Int64 {
        nutzaps.filter { nutzap in
            if case .redeemed = nutzap.status { return true }
            return false
        }.reduce(0) { $0 + $1.amount }
    }
    
    var failedCount: Int {
        nutzaps.filter { nutzap in
            if case .failed = nutzap.status { return true }
            return false
        }.count
    }
    
    // MARK: - Methods
    
    private func loadNutzaps() async {
        guard let wallet = walletManager.wallet else { return }
        self.nutzaps = await wallet.getNutzaps()
    }
    
    private func redeemNutzap(_ nutzap: NutzapInfo) async {
        isRedeeming.insert(nutzap.eventId)
        defer { isRedeeming.remove(nutzap.eventId) }
        
        do {
            _ = try await walletManager.wallet?.redeemNutzap(nutzap.eventId)
            await loadNutzaps()
        } catch let error as NutzapRedemptionError {
            errorMessage = error.userFriendlyMessage
            showError = true
        } catch {
            errorMessage = "Failed to redeem nutzap: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func retryAllFailed() async {
        isRetryingAll = true
        defer { isRetryingAll = false }
        
        guard let wallet = walletManager.wallet else { return }
        
        let results = await wallet.retryFailedNutzaps()
        
        // Count successes and failures
        let successCount = results.filter { $0.result.success }.count
        let failureCount = results.count - successCount
        
        if successCount > 0 {
            // Reload to show updated statuses
            await loadNutzaps()
        }
        
        if failureCount > 0 {
            errorMessage = "Retried \(results.count) nutzaps: \(successCount) succeeded, \(failureCount) failed"
            showError = true
        }
    }
}

// MARK: - NutzapInfo Extension

extension NutzapInfo: @retroactive Identifiable {
    public var id: String { eventId }
}

// MARK: - Summary Section

struct NutzapSummarySection: View {
    let nutzaps: [NutzapInfo]
    
    var pendingAmount: Int64 {
        nutzaps.filter { nutzap in
            if case .pending = nutzap.status { return true }
            return false
        }.reduce(0) { $0 + $1.amount }
    }
    
    var redeemedAmount: Int64 {
        nutzaps.filter { nutzap in
            if case .redeemed = nutzap.status { return true }
            return false
        }.reduce(0) { $0 + $1.amount }
    }
    
    var failedCount: Int {
        nutzaps.filter { nutzap in
            if case .failed = nutzap.status { return true }
            return false
        }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Pending card
                SummaryCard(
                    title: "Pending",
                    value: "\(pendingAmount) sats",
                    color: .orange,
                    icon: "clock.fill"
                )
                
                // Redeemed card
                SummaryCard(
                    title: "Redeemed",
                    value: "\(redeemedAmount) sats",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                // Failed card
                if failedCount > 0 {
                    SummaryCard(
                        title: "Failed",
                        value: "\(failedCount)",
                        color: .red,
                        icon: "exclamationmark.triangle.fill"
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Nutzap Row

struct NutzapRow: View {
    let nutzap: NutzapInfo
    let isRedeeming: Bool
    let onRedeem: () async -> Void
    
    var body: some View {
        HStack {
            // Status indicator
            NutzapStatusIndicator(status: nutzap.status)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                // Amount and sender
                HStack {
                    Text("\(nutzap.amount) sats")
                        .font(.headline)
                    
                    Text("from \(nutzap.sender.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Comment if present
                if let comment = nutzap.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Timestamp
                RelativeTimeView(date: Date(timeIntervalSince1970: TimeInterval(nutzap.createdAt)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Error message for failed nutzaps
                if case .failed(let error, let attempts, _) = nutzap.status {
                    Text(error.userFriendlyMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    if attempts > 1 {
                        Text("\(attempts) attempts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action button for failed nutzaps
            if case .failed(let error, _, _) = nutzap.status, error.isRetryable {
                Button {
                    Task { await onRedeem() }
                } label: {
                    if isRedeeming {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isRedeeming)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Status Indicator

struct NutzapStatusIndicator: View {
    let status: NutzapRedemptionStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Image(systemName: statusIcon)
                    .font(.system(size: 8))
                    .foregroundColor(.white)
            )
    }
    
    var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .redeemed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .redeemed:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        }
    }
}