import SwiftUI
import NDKSwift

struct RelayHealthView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var relayHealth: [WalletHealthMonitor.RelayHealth] = []
    @State private var isLoading = true
    @State private var lastUpdateTime: Date?
    @State private var showingRepairSheet = false
    @State private var selectedUnhealthyRelay: WalletHealthMonitor.RelayHealth?
    @State private var showWalletSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with refresh button
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Wallet Relay Health")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let lastUpdate = lastUpdateTime {
                                Text("Last updated: \(lastUpdate, style: .time)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await refreshHealth()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                    
                    // Health summary
                    if !relayHealth.isEmpty {
                        healthSummaryCard
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Relay list
                if isLoading {
                    Spacer()
                    ProgressView("Checking relay health...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if relayHealth.isEmpty {
                    emptyStateView
                } else {
                    relayListView
                }
            }
            .onAppear {
                Task {
                    await refreshHealth()
                }
            }
            .sheet(isPresented: $showingRepairSheet) {
                if let unhealthyRelay = selectedUnhealthyRelay {
                    RelayRepairSheet(relayHealth: unhealthyRelay) {
                        // Refresh after repair
                        Task {
                            await refreshHealth()
                        }
                    }
                }
            }
            .sheet(isPresented: $showWalletSettings) {
                WalletSettingsView()
            }
        }
    }
    
    private var healthSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                // Healthy relays
                VStack {
                    Text("\(healthyRelayCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Healthy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Unhealthy relays
                VStack {
                    Text("\(unhealthyRelayCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(unhealthyRelayCount > 0 ? .red : .secondary)
                    Text("Issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Total relays
                VStack {
                    Text("\(relayHealth.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Overall status
            HStack {
                Image(systemName: overallHealthIcon)
                    .foregroundColor(overallHealthColor)
                Text(overallHealthMessage)
                    .font(.subheadline)
                    .foregroundColor(overallHealthColor)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var relayListView: some View {
        List {
            ForEach(Array(relayHealth.enumerated()), id: \.element.relay.url) { index, health in
                RelayHealthRow(
                    relayHealth: health,
                    onRepairTapped: {
                        selectedUnhealthyRelay = health
                        showingRepairSheet = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Wallet Relays")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your wallet doesn't have specific relay tags configured. All wallet operations use your default outbox relays.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Configure Wallet Relays") {
                showWalletSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Health Calculations
    
    private var healthyRelayCount: Int {
        relayHealth.filter { $0.isHealthy }.count
    }
    
    private var unhealthyRelayCount: Int {
        relayHealth.filter { !$0.isHealthy }.count
    }
    
    private var overallHealthIcon: String {
        if unhealthyRelayCount == 0 {
            return "checkmark.circle.fill"
        } else if unhealthyRelayCount < relayHealth.count {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var overallHealthColor: Color {
        if unhealthyRelayCount == 0 {
            return .green
        } else if unhealthyRelayCount < relayHealth.count {
            return .orange
        } else {
            return .red
        }
    }
    
    private var overallHealthMessage: String {
        if unhealthyRelayCount == 0 {
            return "All relays are healthy"
        } else if unhealthyRelayCount < relayHealth.count {
            return "Some relays have issues"
        } else {
            return "All relays have issues"
        }
    }
    
    // MARK: - Actions
    
    private func refreshHealth() async {
        guard let wallet = walletManager.wallet else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let health = await wallet.getRelayHealth()
        await MainActor.run {
            self.relayHealth = health
            self.lastUpdateTime = Date()
        }
    }
}

struct RelayHealthRow: View {
    let relayHealth: WalletHealthMonitor.RelayHealth
    let onRepairTapped: () -> Void
    
    private var displayURL: String {
        let url = relayHealth.relay.url
        if url.hasPrefix("wss://") {
            return String(url.dropFirst(6))
        } else if url.hasPrefix("ws://") {
            return String(url.dropFirst(5))
        }
        return url
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Status indicator
                Circle()
                    .fill(relayHealth.isHealthy ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                // Relay URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayURL)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(relayHealth.knownEvents) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Health status
                if relayHealth.isHealthy {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Button("Repair") {
                        onRepairTapped()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // Issue details
            if !relayHealth.isHealthy {
                VStack(alignment: .leading, spacing: 4) {
                    if !relayHealth.missingEvents.isEmpty {
                        HStack {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Missing \(relayHealth.missingEvents.count) events")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !relayHealth.extraEvents.isEmpty {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("\(relayHealth.extraEvents.count) deleted events still present")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RelayRepairSheet: View {
    let relayHealth: WalletHealthMonitor.RelayHealth
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    @State private var isRepairing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Repair Relay")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(relayHealth.relay.url)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Issue summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Issues Found:")
                        .font(.headline)
                    
                    if !relayHealth.missingEvents.isEmpty {
                        HStack {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.orange)
                            Text("Missing \(relayHealth.missingEvents.count) events")
                            Spacer()
                        }
                    }
                    
                    if !relayHealth.extraEvents.isEmpty {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.red)
                            Text("\(relayHealth.extraEvents.count) stale events")
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                Spacer()
                
                // Repair button
                Button(action: performRepair) {
                    HStack {
                        if isRepairing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wrench")
                        }
                        Text(isRepairing ? "Repairing..." : "Repair Relay")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRepairing)
                
                Text("This will republish missing events to the relay.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Relay Repair")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert("Repair Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func performRepair() {
        guard let wallet = walletManager.wallet else { return }
        
        Task {
            isRepairing = true
            defer { isRepairing = false }
            
            do {
                try await wallet.repairRelay(relayHealth.relay, missingEventIds: relayHealth.missingEvents)
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Repair failed: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    isRepairing = false
                }
            }
        }
    }
}

#Preview {
    // Create mock objects for preview
    let nostrManager = NostrManager(from: "Health")
    
    RelayHealthView()
        .environment(WalletManager(nostrManager: nostrManager, appState: AppState()))
}
