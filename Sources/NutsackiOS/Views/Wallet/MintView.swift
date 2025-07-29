import SwiftUI
import NDKSwift
import CashuSwift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MintView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager

    @State private var amount = ""
    @State private var selectedMintURL: String = ""
    @State private var availableMints: [MintInfo] = []
    @State private var isMinting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var mintQuote: CashuMintQuote?
    @State private var showInvoice = false
    @State private var depositTask: Task<Void, Never>?
    @State private var loadMintTask: Task<Void, Never>?
    @State private var showPaymentAnimation = false
    @State private var mintedAmount: Int64 = 0
    @State private var manualCheckContinuation: AsyncStream<Void>.Continuation?
    @FocusState private var amountFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    amountInputSection
                    mintSelectionSection
                }
                .padding(.vertical)
                .padding(.bottom, 120) // Add space for the fixed button and keyboard
            }

            createInvoiceButton
        }
        .navigationTitle("Mint Ecash")
        .platformNavigationBarTitleDisplayMode(inline: true)
        #if os(iOS)
        .ignoresSafeArea(.keyboard, edges: [])
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create Invoice") {
                    createMintQuote()
                }
                .foregroundColor(.orange)
                .disabled(!isValidAmount || isMinting)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showInvoice) {
            if let quote = mintQuote {
                InvoiceView(
                    invoice: quote.invoice,
                    amount: Int(quote.amount),
                    onPaid: { checkMintStatus() },
                    onCheckNow: { manualCheckContinuation?.yield() }
                )
            }
        }
        .task {
            await startMintLoading()
        }
        .onDisappear {
            depositTask?.cancel()
            loadMintTask?.cancel()
        }
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showPaymentAnimation) {
            PaymentReceivedAnimation(amount: mintedAmount) {
                dismiss()
            }
        }
    }

    private func loadMints() async {
        guard let wallet = walletManager.wallet else { return }
        let mintURLs = await wallet.mints.getMintURLs()
        let mints = mintURLs.compactMap { urlString -> MintInfo? in
            guard let url = URL(string: urlString) else { return nil }
            return MintInfo(url: url, name: url.host ?? "Unknown Mint")
        }
        await MainActor.run {
            availableMints = mints
            if selectedMintURL.isEmpty && !mints.isEmpty {
                selectedMintURL = mints.first?.url.absoluteString ?? ""
            }
        }
    }

    private func startMintLoading() async {
        // Initial load
        await loadMints()

        // If no mints found, periodically check until they're available
        if availableMints.isEmpty {
            loadMintTask = Task {
                var attempts = 0
                while attempts < 10 && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await loadMints()

                    if !availableMints.isEmpty {
                        break
                    }
                    attempts += 1
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var formattedAmount: String {
        if amount.isEmpty {
            return "0"
        }

        // Format with thousand separators
        if let number = Int(amount) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            return formatter.string(from: NSNumber(value: number)) ?? amount
        }
        return amount
    }

    private var isValidAmount: Bool {
        guard let amountInt = Int(amount), amountInt > 0 else { return false }
        return !selectedMintURL.isEmpty
    }

    // MARK: - View Components
    private var amountInputSection: some View {
        VStack(spacing: 16) {
            // Hidden text field that drives the amount
            TextField("0", text: $amount)
                .keyboardType(.numberPad)
                .opacity(0)
                .frame(height: 0)
                .focused($amountFieldFocused)

            // Visual amount display
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formattedAmount)
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("sats")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    amountFieldFocused = true
                }

                // USD equivalent (placeholder)
                Text("≈ $0.00 USD")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
            }

            // Quick amount buttons
            HStack(spacing: 12) {
                ForEach(AmountPresets.nutzapAmounts, id: \.self) { preset in
                    Button(action: { setAmount(preset) }) {
                        Text("\(preset / 1000)k")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var mintSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Mint")
                .font(.headline)
                .padding(.horizontal)

            if availableMints.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading mints...")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(availableMints, id: \.url.absoluteString) { mint in
                        mintRow(for: mint)
                    }
                }
            }
        }
    }

    private func mintRow(for mint: MintInfo) -> some View {
        HStack {
            // Mint icon
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "building.columns")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(mint.name ?? mint.url.host ?? "Unknown Mint")
                    .font(.system(size: 16, weight: .medium))

                Text(mint.url.host ?? mint.url.absoluteString)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedMintURL == mint.url.absoluteString {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMintURL = mint.url.absoluteString
        }
        .padding(.horizontal)
    }

    private var createInvoiceButton: some View {
        VStack {
            Divider()

            Button(action: createMintQuote) {
                if isMinting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.3))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                } else {
                    Text("Create Invoice")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(!isValidAmount || isMinting)
            .padding()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helper Functions
    private func setAmount(_ preset: Int) {
        amount = "\(preset)"
    }

    private func createMintQuote() {
        guard let amountInt = Int(amount),
              amountInt > 0,
              !selectedMintURL.isEmpty else { return }

        isMinting = true

        Task {
            do {
                // Request mint quote from the wallet
                guard let wallet = walletManager.wallet else {
                    throw WalletError.noActiveWallet
                }
                let quote = try await wallet.requestMint(
                    amount: Int64(amountInt),
                    mintURL: selectedMintURL
                )

                await MainActor.run {
                    mintQuote = quote
                    showInvoice = true
                    isMinting = false
                }

                // Start monitoring for deposit
                startDepositMonitoring(quote: quote)

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isMinting = false
                }
            }
        }
    }

    private func startDepositMonitoring(quote: CashuMintQuote) {
        depositTask?.cancel()

        // Create manual check trigger stream
        let (triggerStream, continuation) = AsyncStream<Void>.makeStream()
        manualCheckContinuation = continuation

        depositTask = Task {
            do {
                guard let wallet = walletManager.wallet else { return }
                let depositSequence = await wallet.monitorDeposit(
                    quote: quote,
                    manualCheckTrigger: triggerStream
                )
                for try await status in depositSequence {
                    switch status {
                    case .pending:
                        // Still waiting for payment
                        print("Deposit pending for quote: \(quote.quoteId)")

                    case .minted(let proofs):
                        // Success! Tokens have been minted
                        print("Successfully minted \(proofs.count) proofs")

                        // Calculate total amount from proofs
                        let totalAmount = proofs.reduce(0) { $0 + $1.amount }

                        await MainActor.run {
                            // Update wallet balance in UI
                            // The wallet manager already saved the proofs
                            mintedAmount = Int64(totalAmount)
                            showInvoice = false
                            showPaymentAnimation = true
                        }
                        return

                    case .expired:
                        await MainActor.run {
                            errorMessage = "Lightning invoice expired"
                            showError = true
                            showInvoice = false
                        }
                        return

                    case .cancelled:
                        return
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to monitor deposit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func checkMintStatus() {
        // This is called when the invoice view is shown
        // The actual monitoring is handled by startDepositMonitoring
    }
}

// MARK: - Invoice View
struct InvoiceView: View {
    let invoice: String
    let amount: Int
    let onPaid: () -> Void
    let onCheckNow: () -> Void

    @State private var copied = false
    @State private var isChecking = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Amount
                VStack(spacing: 8) {
                    Text("\(amount)")
                        .font(.system(size: 48, weight: .bold))
                    Text("sats")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // QR Code
                QRCodeView(content: invoice)

                // Invoice text
                VStack(spacing: 12) {
                    Text(invoice)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)

                    Button(action: copyInvoice) {
                        Label(
                            copied ? "Copied!" : "Copy Invoice",
                            systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .orange)
                }
                .padding(.horizontal)

                // Check Now button
                Button(action: checkNow) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Check Payment Status")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isChecking)

                Spacer()

                // Status
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Waiting for payment...")
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Lightning Invoice")
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func copyInvoice() {
        invoice.copyToPasteboard()
        withAnimation {
            copied = true
        }

        // Reset copied state after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation {
                    copied = false
                }
            }
        }
    }

    private func checkNow() {
        withAnimation {
            isChecking = true
        }

        // Trigger manual check
        onCheckNow()

        // Reset checking state after a brief delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                withAnimation {
                    isChecking = false
                }
            }
        }
    }
}
