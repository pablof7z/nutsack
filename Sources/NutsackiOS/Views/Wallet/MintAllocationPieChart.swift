import SwiftUI
import Foundation

struct MintAllocationPieChart: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var mintBalances: [(mint: String, balance: Int64, percentage: Double)] = []
    @State private var selectedSlice: String?
    @State private var animationProgress: Double = 0
    @State private var isLoading = true

    // Customizable properties
    var chartSize: CGFloat = 240
    var showTitle: Bool = true
    var showLegend: Bool = true
    var expansionProgress: CGFloat = 1.0
    var onBalancesLoaded: ([(mint: String, balance: Int64, percentage: Double)]) -> Void = { _ in }

    private var innerRadius: CGFloat {
        if expansionProgress < 0.5 {
            return 0 // Solid circle when small
        } else {
            return chartSize * 0.3 * ((expansionProgress - 0.5) * 2) // Gradually hollow out
        }
    }

    // Beautiful color palette for the pie chart
    private let mintColors: [Color] = [
        Color(red: 0.98, green: 0.54, blue: 0.13), // Orange
        Color(red: 0.13, green: 0.59, blue: 0.95), // Blue
        Color(red: 0.96, green: 0.26, blue: 0.21), // Red
        Color(red: 0.30, green: 0.69, blue: 0.31), // Green
        Color(red: 0.61, green: 0.15, blue: 0.69), // Purple
        Color(red: 1.00, green: 0.92, blue: 0.23), // Yellow
        Color(red: 0.00, green: 0.74, blue: 0.83), // Cyan
        Color(red: 1.00, green: 0.60, blue: 0.00)  // Deep Orange
    ]

    var body: some View {
        VStack(spacing: 20) {
            if showTitle {
                titleView
            }

            if mintBalances.isEmpty && !isLoading {
                // Don't show empty state for embedded usage
                if showTitle {
                    emptyStateView
                }
            } else {
                if showLegend {
                    chartAndLegendView
                } else {
                    chartView
                }
            }
        }
        .padding(showTitle ? 20 : 0)
        .background(showTitle ? backgroundView : nil)
        .onAppear {
            Task {
                await loadMintBalances()
                withAnimation(.easeOut(duration: 0.8)) {
                    animationProgress = 1.0
                }
            }
        }
    }

    private var titleView: some View {
        HStack {
            Text("Mint Allocation")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("No funds distributed yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: chartSize)
    }

    private var chartAndLegendView: some View {
        HStack(spacing: 30) {
            chartView
            legendView
        }
    }

    private var chartView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: chartSize, height: chartSize)

            // Pie slices
            ForEach(Array(mintBalances.enumerated()), id: \.element.mint) { index, item in
                PieSlice(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index),
                    innerRadius: innerRadius,
                    outerRadius: chartSize / 2,
                    color: mintColors[index % mintColors.count],
                    isSelected: selectedSlice == item.mint && showLegend,
                    animationProgress: animationProgress
                )
                .onTapGesture {
                    if showLegend {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSlice = selectedSlice == item.mint ? nil : item.mint
                        }
                    }
                }
            }

            // Center hole with total
            centerTotalView
        }
        .frame(width: chartSize, height: chartSize)
    }

    private var centerTotalView: some View {
        Group {
            if expansionProgress > 0.5 && showLegend {
                VStack(spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatSats(mintBalances.reduce(0) { $0 + $1.balance }))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("sats")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .opacity(Double((expansionProgress - 0.5) * 2))
            } else if expansionProgress > 0.5 {
                // Simplified center for BalanceCard usage
                VStack(spacing: 2) {
                    Text("\(mintBalances.count)")
                        .font(.system(size: 18 + (10 * expansionProgress), weight: .bold))
                        .foregroundColor(.white)
                    Text("mints")
                        .font(.system(size: 10 + (4 * expansionProgress)))
                        .foregroundColor(.secondary)
                }
                .opacity(Double((expansionProgress - 0.5) * 2))
            }
        }
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(mintBalances.enumerated()), id: \.element.mint) { index, item in
                legendItem(for: item, at: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(for item: (mint: String, balance: Int64, percentage: Double), at index: Int) -> some View {
        HStack(spacing: 8) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(mintColors[index % mintColors.count])
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(selectedSlice == item.mint ? Color(.label) : Color.clear, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(formatMintName(item.mint))
                    .font(.caption)
                    .fontWeight(selectedSlice == item.mint ? .semibold : .regular)
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(formatSats(item.balance)) sats")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("(\(Int(item.percentage))%)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()
        }
        .opacity(selectedSlice == nil || selectedSlice == item.mint ? 1.0 : 0.5)
        .scaleEffect(selectedSlice == item.mint ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedSlice)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }

    private func loadMintBalances() async {
        isLoading = true
        defer { isLoading = false }

        guard let wallet = walletManager.wallet else { return }

        // Get balances grouped by mint directly
        let balancesByMint = await wallet.getBalancesByMint()

        var balances: [(mint: String, balance: Int64, percentage: Double)] = []
        let totalBalance = balancesByMint.values.reduce(0, +)

        // Calculate percentages
        if totalBalance > 0 {
            for (mint, balance) in balancesByMint {
                let percentage = (Double(balance) / Double(totalBalance)) * 100
                balances.append((mint: mint, balance: balance, percentage: percentage))
            }
        }

        // Sort by balance (largest first)
        balances.sort { $0.balance > $1.balance }

        await MainActor.run {
            self.mintBalances = balances
            self.onBalancesLoaded(balances)
        }
    }

    private func startAngle(for index: Int) -> Angle {
        guard index > 0 else { return .degrees(-90) }

        let previousAngles = mintBalances[0..<index].reduce(0.0) { sum, item in
            sum + (item.percentage / 100.0 * 360.0)
        }

        return .degrees(previousAngles - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        // For the last slice, ensure it closes perfectly at 270 degrees (top of circle)
        if index == mintBalances.count - 1 {
            return .degrees(270) // Ensure perfect closure at top
        }

        let cumulativeAngle = mintBalances[0...index].reduce(0.0) { sum, item in
            sum + (item.percentage / 100.0 * 360.0)
        }

        return .degrees(cumulativeAngle - 90)
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

        // Remove common prefixes
        let cleanHost = host
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "mint.", with: "")

        // Truncate if too long
        if cleanHost.count > 20 {
            return String(cleanHost.prefix(17)) + "..."
        }

        return cleanHost
    }
}

// Custom pie slice shape
struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let color: Color
    let isSelected: Bool
    let animationProgress: Double

    var body: some View {
        ZStack {
            // Shadow for selected slice
            if isSelected {
                PieSliceShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius + 5
                )
                .fill(color.opacity(0.3))
                .blur(radius: 8)
            }

            // Main slice
            PieSliceShape(
                startAngle: startAngle,
                endAngle: startAngle + (endAngle - startAngle) * animationProgress,
                innerRadius: innerRadius,
                outerRadius: isSelected ? outerRadius + 5 : outerRadius
            )
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color,
                        color.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Highlight edge
            PieSliceShape(
                startAngle: startAngle,
                endAngle: startAngle + (endAngle - startAngle) * animationProgress,
                innerRadius: innerRadius,
                outerRadius: isSelected ? outerRadius + 5 : outerRadius
            )
            .stroke(color.opacity(0.8), lineWidth: 1)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // If it's a full circle (360 degrees), draw it specially to avoid gaps
        let angleDifference = endAngle.degrees - startAngle.degrees
        if abs(angleDifference - 360.0) < 0.01 || abs(angleDifference - (-360.0)) < 0.01 {
            // Full circle case
            if innerRadius > 0 {
                // Donut shape
                path.addEllipse(in: CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                ))
                path.addEllipse(in: CGRect(
                    x: center.x - innerRadius,
                    y: center.y - innerRadius,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                ))
            } else {
                // Full circle
                path.addEllipse(in: CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                ))
            }
        } else {
            // Regular pie slice

            // Start point on outer radius
            let outerStartPoint = CGPoint(
                x: center.x + outerRadius * Foundation.cos(startAngle.radians),
                y: center.y + outerRadius * Foundation.sin(startAngle.radians)
            )
            path.move(to: outerStartPoint)

            // Outer arc
            path.addArc(
                center: center,
                radius: outerRadius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )

            // Line to inner arc (or center if innerRadius is 0)
            if innerRadius > 0 {
                let innerEndPoint = CGPoint(
                    x: center.x + innerRadius * Foundation.cos(endAngle.radians),
                    y: center.y + innerRadius * Foundation.sin(endAngle.radians)
                )
                path.addLine(to: innerEndPoint)

                // Inner arc (reversed)
                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: endAngle,
                    endAngle: startAngle,
                    clockwise: true
                )
            } else {
                // Line to center for solid pie slice
                path.addLine(to: center)
            }

            // Close the path
            path.closeSubpath()
        }

        return path
    }
}
