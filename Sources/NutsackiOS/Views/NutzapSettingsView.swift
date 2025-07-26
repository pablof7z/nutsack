import SwiftUI
import NDKSwift

struct NutzapSettingsView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(NostrManager.self) private var nostrManager
    
    @State private var p2pkPubkey: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var copiedToClipboard = false
    
    var body: some View {
        Form {
            publicKeySection
            mintsSection
        }
        .navigationTitle("Zap Settings")
        .platformNavigationBarTitleDisplayMode(inline: true)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .task {
            await loadP2PKPubkey()
        }
    }
    
    private var publicKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("P2PK Public Key", systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(p2pkPubkey.isEmpty ? "Loading..." : p2pkPubkey)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    #if os(iOS)
                    Button(action: copyPubkey) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        } header: {
            Text("Your Zap Receiving Key")
        } footer: {
            Text("This is your wallet's P2PK public key. Others need this to send you zaps.")
        }
    }
    
    private var mintsSection: some View {
        Section {
            AsyncContentView(
                operation: { 
                    guard let wallet = walletManager.activeWallet else { return [] }
                    let mintStrings = await wallet.mints.getMintURLs()
                    let mintURLs = mintStrings.compactMap { URL(string: $0) }
                    return mintURLs.map { MintInfo(url: $0) }
                }
            ) { (mints: [MintInfo]) in
                ForEach(Array(mints.enumerated()), id: \.offset) { (index, mint) in
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text(mint.url.host ?? mint.url.absoluteString)
                                .font(.subheadline)
                            Text(mint.url.absoluteString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Accepted Mints")
        } footer: {
            Text("People can only send you zaps using these mints")
        }
    }
    
    
    private func loadP2PKPubkey() async {
        do {
            let pubkey = try await walletManager.getP2PKPubkey()
            await MainActor.run {
                p2pkPubkey = pubkey
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load P2PK public key: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    
    #if os(iOS)
    private func copyPubkey() {
        UIPasteboard.general.string = p2pkPubkey
        
        withAnimation(.easeInOut(duration: 0.2)) {
            copiedToClipboard = true
        }
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        NutzapSettingsView()
    }
}