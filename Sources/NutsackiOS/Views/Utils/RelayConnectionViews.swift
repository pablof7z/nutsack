import SwiftUI
import NDKSwift

// MARK: - Connection Status Badge
/// A reusable view that displays relay connection status with both visual indicator and text
public struct ConnectionStatusBadge: View {
    let state: NDKRelayConnectionState
    let style: BadgeStyle
    
    public enum BadgeStyle {
        case full        // Shows dot + text + background
        case compact     // Shows only dot
        case text        // Shows only text
    }
    
    public init(state: NDKRelayConnectionState, style: BadgeStyle = .full) {
        self.state = state
        self.style = style
    }
    
    public var body: some View {
        switch style {
        case .full:
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .cornerRadius(12)
            
        case .compact:
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                
        case .text:
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .disconnecting:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        case .disconnecting:
            return "Disconnecting"
        case .failed:
            return "Failed"
        }
    }
}

// MARK: - Relay Icon View
/// A reusable view that displays a relay icon with fallback
public struct RelayIconView: View {
    let icon: Image?
    let size: CGFloat
    
    public init(icon: Image? = nil, size: CGFloat = 40) {
        self.icon = icon
        self.size = size
    }
    
    public var body: some View {
        Group {
            if let icon = icon {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            }
        }
    }
}

// MARK: - Relay Stats View
/// A compact view showing relay statistics
public struct RelayStatsView: View {
    let stats: NDKRelayStats
    let showLabels: Bool
    
    public init(stats: NDKRelayStats, showLabels: Bool = true) {
        self.stats = stats
        self.showLabels = showLabels
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "arrow.up",
                value: "\(stats.messagesSent)",
                label: showLabels ? "sent" : nil
            )
            
            StatItem(
                icon: "arrow.down",
                value: "\(stats.messagesReceived)",
                label: showLabels ? "received" : nil
            )
            
            if let latency = stats.latency {
                StatItem(
                    icon: "timer",
                    value: String(format: "%.0fms", latency * 1000),
                    label: showLabels ? "latency" : nil
                )
            }
            
            if stats.connectionAttempts > 0 {
                let successRate = Double(stats.successfulConnections) / Double(stats.connectionAttempts) * 100
                StatItem(
                    icon: "checkmark.circle",
                    value: String(format: "%.0f%%", successRate),
                    label: showLabels ? "success" : nil
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String?
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .fontWeight(.medium)
            }
            if let label = label {
                Text(label)
                    .font(.system(size: 9))
            }
        }
    }
}

// MARK: - Relay NIP-11 Info View
/// A view that displays NIP-11 information for a relay
public struct RelayInfoView: View {
    let info: NDKRelayInformation
    let style: InfoStyle
    
    public enum InfoStyle {
        case compact    // Just software/version
        case full       // All available info
    }
    
    public init(info: NDKRelayInformation, style: InfoStyle = .compact) {
        self.info = info
        self.style = style
    }
    
    public var body: some View {
        switch style {
        case .compact:
            VStack(alignment: .trailing, spacing: 2) {
                if let software = info.software {
                    Text(software)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let version = info.version {
                    Text(version)
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
            }
            
        case .full:
            VStack(alignment: .leading, spacing: 8) {
                if let name = info.name {
                    LabeledContent("Name", value: name)
                }
                if let description = info.description {
                    LabeledContent("Description", value: description)
                }
                if let software = info.software {
                    LabeledContent("Software", value: software)
                }
                if let version = info.version {
                    LabeledContent("Version", value: version)
                }
                if let contact = info.contact {
                    LabeledContent("Contact", value: contact)
                }
            }
        }
    }
}