import SwiftUI
import NDKSwift
import CashuSwift

struct WalletEventsView: View {
    @EnvironmentObject private var nostrManager: NostrManager
    @Environment(WalletManager.self) private var walletManager

    @State private var walletEvents: [WalletEventInfo] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedEvent: WalletEventInfo?

    var body: some View {
        List {
            if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Loading wallet events...")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                } else if walletEvents.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No wallet events found")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Token events will appear here as you use your wallet")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        ForEach(walletEvents) { eventInfo in
                            NavigationLink(value: eventInfo) {
                                WalletEventRow(eventInfo: eventInfo)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Token Events")
                            Spacer()
                            Text("\(walletEvents.count) total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Shows all NIP-60 token events (kind 7375) published by this wallet. Deleted events are marked with a strikethrough.")
                    }
                }

                if let error = error {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Error loading events", systemImage: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Wallet Events")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: WalletEventInfo.self) { eventInfo in
                WalletEventDetailView(eventInfo: eventInfo)
            }
            .refreshable {
                await loadWalletEvents()
            }
            .onAppear {
                Task {
                    await loadWalletEvents()
                }
            }
    }

    private func loadWalletEvents() async {
        isLoading = true
        error = nil

        do {
            let events = try await walletManager.fetchAllWalletEvents()
            await MainActor.run {
                self.walletEvents = events
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

struct WalletEventRow: View {
    let eventInfo: WalletEventInfo

    private var eventDate: Date {
        Date(timeIntervalSince1970: TimeInterval(eventInfo.event.createdAt))
    }

    private var totalAmount: Int {
        eventInfo.tokenData?.proofs.reduce(0) { $0 + Int($1.amount) } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status indicator
                Image(systemName: eventInfo.isDeleted ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(eventInfo.isDeleted ? .red : .green)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(eventInfo.event.id.prefix(8) + "...")
                            .font(.system(.subheadline, design: .monospaced))
                            .strikethrough(eventInfo.isDeleted)

                        Spacer()

                        if eventInfo.tokenData != nil {
                            Text("\(totalAmount) sats")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }

                    HStack {
                        if let tokenData = eventInfo.tokenData {
                            Label("\(tokenData.proofs.count) proofs", systemImage: "key.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text(URL(string: tokenData.mint)?.host ?? tokenData.mint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        RelativeTimeView(date: eventDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if eventInfo.isDeleted {
                        HStack {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text(eventInfo.deletionReason ?? "Deleted")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let delTags = eventInfo.tokenData?.del, !delTags.isEmpty {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                            Text("Replaces \(delTags.count) event\(delTags.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
