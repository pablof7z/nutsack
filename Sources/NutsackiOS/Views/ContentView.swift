import SwiftUI
import SwiftData
import NDKSwift
// import Popovers - Removed for build compatibility

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(NostrManager.self) private var nostrManager
    @Environment(WalletManager.self) private var walletManager
    
    
    @State private var urlState: URLState?
    @State private var showScanner = false
    @State private var scannedInvoice: String?
    @State private var showInvoicePreview = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            if nostrManager.authManager.isAuthenticated {
                // Main app interface - shown when authenticated
                WalletView(urlState: $urlState, showScanner: $showScanner)
            } else {
                // Use SplashView as the authentication screen
                SplashView()
            }
        }
        .ignoresSafeArea()
        .onOpenURL { url in
            handleUrl(url)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scannedValue in
                handleScannedValue(scannedValue)
            }
        }
        .sheet(isPresented: $showInvoicePreview) {
            if let invoice = scannedInvoice {
                LightningInvoicePreviewView(invoice: invoice)
            }
        }
    }
    
    
    private func handleUrl(_ url: URL) {
        print("URL passed to application: \(url.absoluteString)")
        
        if url.scheme == "cashu" || url.scheme == "nostr" {
            urlState = URLState(url: url.absoluteString, timestamp: Date())
        }
    }
    
    private func handleScannedValue(_ scannedValue: String) {
        showScanner = false
        
        // Check if it's a lightning invoice
        if isLightningInvoice(scannedValue) {
            scannedInvoice = scannedValue
            showInvoicePreview = true
        } else if scannedValue.lowercased().starts(with: "cashu") {
            // Handle cashu token by updating wallet view URL state
            urlState = URLState(url: scannedValue, timestamp: Date())
        } else {
            // Handle other QR codes (nostr URLs, etc)
            urlState = URLState(url: scannedValue, timestamp: Date())
        }
    }
    
    private func isLightningInvoice(_ text: String) -> Bool {
        let cleanText = text.replacingOccurrences(of: "lightning:", with: "")
        return LightningConstants.isLightningInvoice(cleanText)
    }
}

struct URLState: Equatable {
    let url: String
    let timestamp: Date
}


// MARK: - Lightning Invoice Preview View
struct LightningInvoicePreviewView: View {
    let invoice: String
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var decodedAmount: Int64?
    @State private var decodedDescription: String?
    @State private var availableBalance: Int = 0
    @State private var isPaying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                        }
                        
                        Text("Lightning Invoice")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Review payment details before proceeding")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Payment Details Card
                    VStack(spacing: 0) {
                        if let amount = decodedAmount {
                            VStack(spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Amount")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(amount) sats")
                                            .font(.title)
                                            .fontWeight(.bold)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Fee (est.)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Text("~1 sat")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Total Payment")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("\(amount + 1) sats")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(amount + 1 > availableBalance ? .red : .orange)
                                }
                            }
                            .padding(20)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(16)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                                
                                Text("Invalid Invoice")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text("Unable to decode the lightning invoice")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(16)
                        }
                    }
                    
                    // Description if available
                    if let description = decodedDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Balance Check
                    if let amount = decodedAmount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Balance")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Text("\(availableBalance) sats")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if amount + 1 > availableBalance {
                                    Text("Insufficient balance")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                } else {
                                    Text("✓ Sufficient balance")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(12)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Payment Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: payInvoice) {
                        if isPaying {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Pay")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(decodedAmount == nil || isPaying || (decodedAmount ?? 0) + 1 > availableBalance)
                }
            }
        }
        .onAppear {
            decodeInvoice()
            loadBalance()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSuccess) {
            if let amount = decodedAmount {
                NavigationStack {
                    VStack(spacing: 30) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .padding(.top, 40)
                        
                        VStack(spacing: 8) {
                            Text("Payment Successful!")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("\(Int(amount)) sats")
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            showSuccess = false
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)
                        .padding(.bottom)
                    }
                    .padding()
                    .navigationTitle("Success")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
    
    private func decodeInvoice() {
        var cleanInvoice = invoice.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanInvoice.starts(with: "lightning:") {
            cleanInvoice = String(cleanInvoice.dropFirst(10))
        }
        
        if cleanInvoice.lowercased().starts(with: "lnbc") || cleanInvoice.lowercased().starts(with: "lntb") || cleanInvoice.lowercased().starts(with: "lnbcrt") {
            let trimmed = cleanInvoice.dropFirst(4)
            var amountStr = ""
            var multiplier: Int64 = 1
            
            for char in trimmed {
                if char.isNumber {
                    amountStr.append(char)
                } else if char == "m" {
                    multiplier = 100
                    break
                } else if char == "u" {
                    multiplier = 100000
                    break
                } else if char == "n" {
                    multiplier = 100000000
                    break
                } else if char == "p" {
                    multiplier = 100000000000
                    break
                } else {
                    break
                }
            }
            
            if let amount = Int64(amountStr) {
                decodedAmount = (amount * multiplier) / 1000
            }
            
            decodedDescription = "Lightning payment"
        }
    }
    
    private func loadBalance() {
        Task {
            do {
                guard let wallet = walletManager.activeWallet else { return }
                let balance = try await wallet.getBalance() ?? 0
                await MainActor.run {
                    availableBalance = Int(balance)
                }
            } catch {
                print("Failed to get balance: \(error)")
            }
        }
    }
    
    private func payInvoice() {
        guard let amount = decodedAmount else { return }
        
        isPaying = true
        
        Task {
            do {
                let _ = try await walletManager.payLightning(
                    invoice: invoice.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount
                )
                
                // Transaction will be recorded automatically via NIP-60 history events
                await MainActor.run {
                    showSuccess = true
                    isPaying = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isPaying = false
                }
            }
        }
    }
}