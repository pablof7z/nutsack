import SwiftUI
import NDKSwift
import CashuSwift
#if os(iOS)
import UIKit
#endif

struct WalletEventDetailView: View {
    let eventInfo: WalletEventInfo
    @Environment(WalletManager.self) private var walletManager
    @State private var proofStates: [String: CashuSwift.Proof.ProofState] = [:]
    @State private var isCheckingProofs = false
    @State private var checkError: Error?
    @State private var copiedBech32 = false

    private var totalAmount: Int {
        eventInfo.tokenData?.proofs.reduce(0) { $0 + Int($1.amount) } ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Event Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: eventInfo.isDeleted ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(eventInfo.isDeleted ? .red : .green)
                            .font(.title2)

                        Text(eventInfo.isDeleted ? "Deleted Event" : "Active Event")
                            .font(.headline)

                        Spacer()
                    }

                    if eventInfo.isDeleted, let reason = eventInfo.deletionReason {
                        Label(reason, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    if let deletionEvent = eventInfo.deletionEvent {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deleted by:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(deletionEvent.id)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Event Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Information")
                        .font(.headline)

                    LabeledContent("Event ID") {
                        Text(eventInfo.event.id)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    // Bech32 encoding
                    if let bech32 = try? eventInfo.event.encode(includeRelays: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bech32")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Text(String(bech32.prefix(40)) + "...")
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Copy button
                                Button(action: {
                                    #if os(iOS)
                                    UIPasteboard.general.string = bech32
                                    #endif
                                    withAnimation {
                                        copiedBech32 = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedBech32 = false
                                    }
                                }) {
                                    Image(systemName: copiedBech32 ? "checkmark.circle.fill" : "doc.on.doc")
                                        .foregroundColor(copiedBech32 ? .green : .accentColor)
                                }
                                .buttonStyle(.plain)

                                // Open in njump.me button
                                Button(action: {
                                    if let url = URL(string: "https://njump.me/\(bech32)") {
                                        #if os(iOS)
                                        UIApplication.shared.open(url)
                                        #endif
                                    }
                                }) {
                                    Image(systemName: "arrow.up.forward.square")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if copiedBech32 {
                            Text("Copied to clipboard!")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .transition(.opacity)
                        }
                    }

                    LabeledContent("Created") {
                        Text(Date(timeIntervalSince1970: TimeInterval(eventInfo.event.createdAt)), style: .date) +
                        Text(" at ") +
                        Text(Date(timeIntervalSince1970: TimeInterval(eventInfo.event.createdAt)), style: .time)
                    }

                    LabeledContent("Kind") {
                        Text("\(eventInfo.event.kind)")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                // Token Information
                if let tokenData = eventInfo.tokenData {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Token Information")
                                .font(.headline)

                            Spacer()

                            if !eventInfo.isDeleted {
                                Button(action: checkProofStates) {
                                    if isCheckingProofs {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Label("Check States", systemImage: "arrow.clockwise")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(isCheckingProofs)
                            }
                        }

                        LabeledContent("Mint") {
                            Text(URL(string: tokenData.mint)?.host ?? tokenData.mint)
                                .textSelection(.enabled)
                        }

                        LabeledContent("Total Amount") {
                            Text("\(totalAmount) sats")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.orange)
                        }

                        LabeledContent("Number of Proofs") {
                            Text("\(tokenData.proofs.count)")
                        }

                        if let delTags = tokenData.del, !delTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Replaces Events:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                ForEach(delTags, id: \.self) { deletedEventId in
                                    Text(deletedEventId)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Proofs List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Proofs")
                            .font(.headline)

                        if checkError != nil {
                            Label("Error checking proof states", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        ForEach(tokenData.proofs, id: \.C) { proof in
                            ProofRow(proof: proof, state: proofStates[proof.C])
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                // Raw Event Content (for debugging)
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("Raw Event Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Content (Encrypted):")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(eventInfo.event.content)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .cornerRadius(8)

                            Text("Tags:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)

                            ForEach(Array(eventInfo.event.tags.enumerated()), id: \.offset) { _, tag in
                                Text(tag.joined(separator: ", "))
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Event Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func checkProofStates() {
        guard let tokenData = eventInfo.tokenData else { return }

        isCheckingProofs = true
        checkError = nil

        Task {
            do {
                let states = try await walletManager.checkProofStates(
                    for: tokenData.proofs,
                    mint: tokenData.mint
                )

                await MainActor.run {
                    self.proofStates = states
                    self.isCheckingProofs = false
                }
            } catch {
                await MainActor.run {
                    self.checkError = error
                    self.isCheckingProofs = false
                }
            }
        }
    }
}

struct ProofRow: View {
    let proof: CashuSwift.Proof
    let state: CashuSwift.Proof.ProofState?

    private var stateColor: Color {
        switch state {
        case .unspent:
            return .green
        case .spent:
            return .red
        case .pending:
            return .orange
        case nil:
            return .gray
        }
    }

    private var stateText: String {
        switch state {
        case .unspent:
            return "Unspent"
        case .spent:
            return "Spent"
        case .pending:
            return "Pending"
        case nil:
            return "Unknown"
        }
    }

    private var stateIcon: String {
        switch state {
        case .unspent:
            return "checkmark.circle.fill"
        case .spent:
            return "xmark.circle.fill"
        case .pending:
            return "clock.fill"
        case nil:
            return "questionmark.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(proof.amount) sats")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)

                    Text("C: " + proof.C.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("Keyset: " + proof.keysetID.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: stateIcon)
                        .foregroundColor(stateColor)
                        .font(.title3)

                    if state != nil {
                        Text(stateText)
                            .font(.caption)
                            .foregroundColor(stateColor)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }
}
