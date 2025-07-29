import SwiftUI
import NDKSwift

struct ReceiveView: View {
    let tokenString: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager

    @State private var inputToken = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showScanner = false
    @State private var receivedAmount: Int?
    @State private var showSuccess = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Paste ecash token", text: $inputToken, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.system(.body, design: .monospaced))

                        Button(action: { showScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    if !inputToken.isEmpty {
                        // Token preview
                        HStack {
                            Image(systemName: "banknote")
                                .foregroundStyle(.orange)
                            Text("Ecash token detected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Ecash Token")
            } footer: {
                Text("Paste or scan an ecash token to redeem it")
            }

            Section {
                Button(action: redeemToken) {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Redeem Token")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(inputToken.isEmpty || isProcessing)
            }
        }
        .navigationTitle("Receive Ecash")
        .platformNavigationBarTitleDisplayMode(inline: true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScan: { scannedValue in
                    inputToken = scannedValue
                    showScanner = false
                },
                onDismiss: {
                    showScanner = false
                }
            )
        }
        .fullScreenCover(isPresented: $showSuccess) {
            if let amount = receivedAmount {
                PaymentReceivedAnimation(amount: Int64(amount)) {
                    dismiss()
                }
            }
        }
        .onAppear {
            if let token = tokenString {
                inputToken = token
                // Auto-redeem if token was provided
                redeemToken()
            }
        }
    }

    private func redeemToken() {
        guard !inputToken.isEmpty else { return }

        isProcessing = true

        Task {
            do {
                // Redeem the token
                let amount = try await walletManager.receive(
                    tokenString: inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
                )

                // Transaction will be recorded automatically via NIP-60 history events
                await MainActor.run {
                    receivedAmount = Int(amount)
                    showSuccess = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Receive Success View
struct ReceiveSuccessView: View {
    let amount: Int
    let onDone: () -> Void

    @State private var animationAmount = 0.0

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Success animation
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .scaleEffect(animationAmount > 0 ? 1 : 0.5)
            }

            VStack(spacing: 8) {
                Text("Received!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(amount) sats")
                    .font(.title)
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animationAmount = 1.5
            }
        }
    }
}
