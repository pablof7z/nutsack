import SwiftUI
import NDKSwift

struct MintFailureAlert: View {
    let operation: PendingMintOperation
    let onRetry: () -> Void
    let onBlacklist: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            // Title
            Text("Mint Failed to Issue Tokens")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(
                    label: "Mint",
                    value: formatMintURL(operation.mintURL)
                )
                
                DetailRow(
                    label: "Amount",
                    value: "\(operation.amount) sats"
                )
                
                DetailRow(
                    label: "Quote ID",
                    value: String(operation.quoteId.prefix(16)) + "..."
                )
                
                if let paymentProof = operation.paymentProof {
                    DetailRow(
                        label: "Payment Proof",
                        value: String(paymentProof.prefix(16)) + "..."
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Explanation
            Text("The mint has received your payment but failed to issue tokens after multiple attempts. You can retry, blacklist this mint, or cancel.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    onRetry()
                    dismiss()
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    onBlacklist()
                    dismiss()
                }) {
                    Label("Blacklist Mint", systemImage: "xmark.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: 400)
    }
    
    private func formatMintURL(_ url: String) -> String {
        // Extract domain from URL for display
        if let url = URL(string: url),
           let host = url.host {
            return host
        }
        return url
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Preview

struct MintFailureAlert_Previews: PreviewProvider {
    static var previews: some View {
        MintFailureAlert(
            operation: PendingMintOperation(
                quoteId: "abc123def456ghi789",
                mintURL: "https://mint.example.com",
                amount: 1000,
                invoice: "lnbc1000...",
                paymentProof: "proof123456789",
                createdAt: Date(),
                lastAttemptAt: Date()
            ),
            onRetry: { print("Retry") },
            onBlacklist: { print("Blacklist") },
            onCancel: { print("Cancel") }
        )
        .previewLayout(.sizeThatFits)
    }
}