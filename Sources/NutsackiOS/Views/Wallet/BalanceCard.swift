import SwiftUI

struct BalanceCardMint: Identifiable, Equatable {
    let id = UUID()
    let mint: String
    let balance: Int64
    let percentage: Double
    
    static func == (lhs: BalanceCardMint, rhs: BalanceCardMint) -> Bool {
        lhs.mint == rhs.mint && lhs.balance == rhs.balance && lhs.percentage == rhs.percentage
    }
}

struct BalanceCard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(WalletManager.self) private var walletManager
    
    @State private var convertedBalance: String = ""
    @State private var mintBalances: [BalanceCardMint] = []
    @State private var isLoadingMints = false
    @State private var isExpanded = false
    @State private var pulseAnimation = false
    
    private let mintColors: [Color] = [
        Color(red: 0.98, green: 0.54, blue: 0.13), // Orange
        Color(red: 0.13, green: 0.59, blue: 0.95), // Blue
        Color(red: 0.96, green: 0.26, blue: 0.21), // Red
        Color(red: 0.30, green: 0.69, blue: 0.31), // Green
    ]
    
    private let compactChartSize: CGFloat = 20
    private let expandedChartSize: CGFloat = 160
    
    var body: some View {
        VStack(spacing: 12) {
            // Balance display - centered
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatBalance(Int(walletManager.currentBalance)))
                        .font(.system(size: isExpanded ? 48 : 56, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("sats")
                        .font(.system(size: isExpanded ? 20 : 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                
                // Show pending amount if any
                if walletManager.pendingAmount != 0 {
                    Text("\(walletManager.pendingAmount > 0 ? "+" : "")\(abs(walletManager.pendingAmount)) pending")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .opacity(0.8)
                }
                
                // Fiat conversion and/or mini pie chart
                HStack(spacing: 12) {
                    // Compact pie chart on the left - show if there are any mints at all
                    if !mintBalances.isEmpty && !isExpanded {
                        ZStack {
                            ExpandablePieChart(
                                mintBalances: mintBalances,
                                mintColors: mintColors,
                                size: compactChartSize,
                                useGrayscale: true
                            )
                            
                            // Subtle pulsing ring hint
                            Circle()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                .frame(width: compactChartSize + 8, height: compactChartSize + 8)
                                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                .opacity(pulseAnimation ? 0.2 : 0.6)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }
                    }
                    
                    // Show fiat conversion if available
                    if appState.preferredConversionUnit != .sat && !convertedBalance.isEmpty && convertedBalance != "..." {
                        Text(convertedBalance)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .opacity(isExpanded ? 0.5 : 0.8)
                    }
                }
                .animation(.default, value: convertedBalance)
            }
            
            // Expanded pie chart with legend
            if !mintBalances.isEmpty && isExpanded {
                VStack(spacing: 16) {
                    // Large pie chart
                    ExpandablePieChart(
                        mintBalances: mintBalances,
                        mintColors: mintColors,
                        size: expandedChartSize,
                        useGrayscale: false
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(mintBalances.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(mintColors[index % mintColors.count])
                                    .frame(width: 14, height: 14)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(formatMintURL(item.mint))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)
                                    
                                    Text("\(formatBalance(Int(item.balance))) sats (\(String(format: "%.1f", item.percentage))%)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Reconcile button
                    NavigationLink(destination: SwapView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 14))
                            Text("Reconcile")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .task(id: walletManager.currentBalance) {
            await convert()
            await loadMintBalances()
        }
        .task {
            await loadMintBalances()
        }
        .onAppear {
            pulseAnimation = true
        }
        .onChange(of: appState.preferredConversionUnit) { _, _ in
            Task {
                await convert()
            }
        }
        .onChange(of: appState.exchangeRates) { _, _ in
            Task {
                await convert()
            }
        }
    }
    
    private func formatBalance(_ sats: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? String(sats)
    }
    
    private func formatMintURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        var cleanHost = host
        if cleanHost.hasPrefix("www.") {
            cleanHost = String(cleanHost.dropFirst(4))
        }
        
        if cleanHost.count > 20 {
            return String(cleanHost.prefix(17)) + "..."
        }
        
        return cleanHost
    }
    
    @MainActor
    private func convert() async {
        convertedBalance = "..."
        
        guard let prices = appState.exchangeRates else {
            print("⚠️ BalanceCard: No exchange rates available")
            convertedBalance = ""
            // Try to reload exchange rates
            appState.loadExchangeRates()
            return
        }
        
        let bitcoinPrice: Int
        switch appState.preferredConversionUnit {
        case .usd: bitcoinPrice = prices.usd
        case .eur: bitcoinPrice = prices.eur
        case .btc:
            let btcAmount = Double(walletManager.currentBalance) / 100_000_000.0
            convertedBalance = String(format: "%.8f BTC", btcAmount)
            return
        case .sat:
            print("⚠️ BalanceCard: Conversion unit is SAT, not showing fiat balance")
            convertedBalance = ""
            return
        }
        
        let bitcoinAmount = Double(walletManager.currentBalance) / 100_000_000.0
        let fiatValue = bitcoinAmount * Double(bitcoinPrice)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appState.preferredConversionUnit.rawValue.uppercased()
        
        convertedBalance = formatter.string(from: NSNumber(value: fiatValue)) ?? ""
        print("✅ BalanceCard: Converted \(walletManager.currentBalance) sats to \(convertedBalance) (\(appState.preferredConversionUnit.rawValue))")
    }
    
    private func loadMintBalances() async {
        isLoadingMints = true
        defer { isLoadingMints = false }
        
        guard let wallet = walletManager.activeWallet else { return }
        
        // Use the efficient getBalancesByMint method instead of looping
        let balancesByMint = await wallet.getBalancesByMint()
        
        var balances: [BalanceCardMint] = []
        let totalBalance = balancesByMint.values.reduce(0, +)
        
        // Convert to BalanceCardMint array with percentages
        for (mint, balance) in balancesByMint where balance > 0 {
            let percentage = totalBalance > 0 ? (Double(balance) / Double(totalBalance)) * 100 : 0
            balances.append(BalanceCardMint(mint: mint, balance: balance, percentage: percentage))
        }
        
        // Sort by balance (largest first) and take top 4
        balances.sort { $0.balance > $1.balance }
        if balances.count > 4 {
            balances = Array(balances.prefix(4))
        }
        
        await MainActor.run {
            self.mintBalances = balances
        }
    }
}

struct ExpandablePieChart: View {
    let mintBalances: [BalanceCardMint]
    let mintColors: [Color]
    let size: CGFloat
    var useGrayscale: Bool = false
    
    @State private var showChart = false
    
    private let grayscaleColors: [Color] = [
        Color(white: 0.7),
        Color(white: 0.5),
        Color(white: 0.3),
        Color(white: 0.4)
    ]
    
    var body: some View {
        ZStack {
            ForEach(Array(mintBalances.enumerated()), id: \.element.id) { index, item in
                Circle()
                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                    .stroke(
                        useGrayscale ? grayscaleColors[index % grayscaleColors.count] : mintColors[index % mintColors.count],
                        style: StrokeStyle(
                            lineWidth: size > 50 ? size * 0.25 : size * 0.25,
                            lineCap: .butt
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(showChart ? 1 : 0)
                    .opacity(showChart ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.05),
                        value: showChart
                    )
            }
            
            // Subtle inner shadow for depth (only for larger sizes)
            if size > 50 {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.label).opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blur(radius: 2)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showChart = true
            }
        }
        .onChange(of: mintBalances) { _, _ in
            showChart = false
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                showChart = true
            }
        }
    }
    
    private func startAngle(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        
        let previousAngles = mintBalances[0..<index].reduce(0) { sum, item in
            sum + (item.percentage / 100.0)
        }
        
        return previousAngles
    }
    
    private func endAngle(for index: Int) -> CGFloat {
        let cumulativeAngle = mintBalances[0...index].reduce(0) { sum, item in
            sum + (item.percentage / 100.0)
        }
        
        return cumulativeAngle
    }
}