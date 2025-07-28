import SwiftUI
import NDKSwift

/// Compact relay health indicator for the main wallet view
struct RelayStatusIndicator: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var relayHealth: [WalletHealthMonitor.RelayHealth] = []
    @State private var isLoading = false
    
    private var healthyRelayCount: Int {
        relayHealth.filter { $0.isHealthy }.count
    }
    
    private var totalRelayCount: Int {
        relayHealth.count
    }
    
    private var hasIssues: Bool {
        relayHealth.contains { !$0.isHealthy }
    }
    
    private var statusColor: Color {
        if relayHealth.isEmpty {
            return .secondary
        } else if hasIssues {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusIcon: String {
        if relayHealth.isEmpty {
            return "antenna.radiowaves.left.and.right.slash"
        } else if hasIssues {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var statusText: String {
        if relayHealth.isEmpty {
            return "No wallet relays"
        } else if hasIssues {
            return "\(healthyRelayCount)/\(totalRelayCount) relays healthy"
        } else {
            return "All \(totalRelayCount) relays healthy"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.caption)
            }
            
            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .onAppear {
            Task {
                await refreshHealth()
            }
        }
    }
    
    private func refreshHealth() async {
        guard let wallet = walletManager.wallet else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let health = await wallet.getRelayHealth()
        await MainActor.run {
            self.relayHealth = health
        }
    }
}

#Preview {
    // Create mock objects for preview
    let nostrManager = NostrManager(from: "Status")
    
    RelayStatusIndicator()
        .environment(WalletManager(nostrManager: nostrManager, appState: AppState()))
        .padding()
}
