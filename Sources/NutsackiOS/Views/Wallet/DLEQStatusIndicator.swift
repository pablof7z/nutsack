import SwiftUI

struct DLEQStatusIndicator: View {
    @Environment(WalletManager.self) private var walletManager

    @State private var proofStats: (verified: Int, unverified: Int, unknown: Int) = (0, 0, 0)

    var dleqStatus: (verified: Int, unverified: Int, unknown: Int) {
        proofStats
    }

    var statusColor: Color {
        let status = dleqStatus
        if status.unverified > 0 {
            return .yellow
        } else if status.verified > 0 && status.unknown == 0 {
            return .green
        } else if status.unknown > 0 {
            return .gray
        }
        return .gray
    }

    var statusIcon: String {
        let status = dleqStatus
        if status.unverified > 0 {
            return "exclamationmark.shield.fill"
        } else if status.verified > 0 && status.unknown == 0 {
            return "checkmark.shield.fill"
        } else {
            return "shield.fill"
        }
    }

    var statusText: String {
        let status = dleqStatus
        if status.unverified > 0 {
            return "\(status.unverified) unverified"
        } else if status.verified > 0 && status.unknown == 0 {
            return "All verified"
        } else if status.verified > 0 {
            return "\(status.verified) verified"
        } else {
            return "No verification data"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.caption2)
                .foregroundStyle(statusColor)
        }
        .help("Token authenticity status: \(dleqStatus.verified) verified, \(dleqStatus.unverified) unverified, \(dleqStatus.unknown) unknown")
        .task {
            await updateStats()
        }
    }

    private func updateStats() async {
        // Implementation pending: Requires WalletManager to track DLEQ verification status of proofs
        // This would involve tracking each proof's verification state in the wallet
        // Currently showing placeholder values until wallet infrastructure supports this
        proofStats = (0, 0, 0)
    }
}

// Compact version for inline use
struct DLEQBadge: View {
    let isVerified: Bool?

    var body: some View {
        if let verified = isVerified {
            Image(systemName: verified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.caption2)
                .foregroundStyle(verified ? .green : .yellow)
                .help(verified ? "Token authenticity verified" : "Token authenticity not verified")
        }
    }
}
