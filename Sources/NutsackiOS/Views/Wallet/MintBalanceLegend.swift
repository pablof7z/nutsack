import SwiftUI
import Foundation

struct MintBalanceLegend: View {
    let mintBalances: [(mint: String, balance: Int64, percentage: Double)]
    let mintColors: [Color]
    let opacity: Double
    @State private var selectedMint: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(mintBalances.enumerated()), id: \.element.mint) { index, item in
                NavigationLink(destination: MintDetailView(mintURL: item.mint)) {
                    HStack(spacing: 12) {
                        // Color indicator
                        RoundedRectangle(cornerRadius: 4)
                            .fill(mintColors[index % mintColors.count])
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatMintName(item.mint))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Text("\(formatSats(item.balance)) sats")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("·")
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("\(Int(item.percentage))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(opacity)
    }
    
    private func formatSats(_ sats: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? String(sats)
    }
    
    private func formatMintName(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        let cleanHost = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "mint.", with: "")
        
        if cleanHost.count > 25 {
            return String(cleanHost.prefix(22)) + "..."
        }
        
        return cleanHost
    }
}