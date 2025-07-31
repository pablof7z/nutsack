import SwiftUI
import CashuSwift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TokenConfirmationView: View {
    let token: String?
    let amount: Int
    let memo: String
    let mintURL: URL?
    let isOfflineMode: Bool
    let onDismiss: () -> Void

    @State private var copied = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var isGenerating: Bool {
        token == nil || token?.isEmpty == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // QR Code with copy button inside
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color(.label).opacity(colorScheme == .light ? 0.15 : 0),
                                    radius: colorScheme == .light ? 10 : 0,
                                    x: 0,
                                    y: colorScheme == .light ? 4 : 0
                                )
                                .if(colorScheme == .dark) { view in
                                    view.shadow(
                                        color: Color.white.opacity(0.1),
                                        radius: 8,
                                        x: 0,
                                        y: 0
                                    )
                                }

                            if let token = token, !token.isEmpty {
                                VStack(spacing: 20) {
                                    QRCodeView(content: token)
                                        .padding(24)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    
                                    Button(action: copyToken) {
                                        HStack(spacing: 8) {
                                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                                .font(.system(size: 16))
                                                .foregroundStyle(copied ? .green : .orange)
                                            Text(copied ? "Copied!" : "Copy token")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundStyle(copied ? .green : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.bottom, 16)
                                }
                            } else {
                                // Loading state
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(width: 320, height: 400)
                    }
                    .padding(.horizontal)

                    // Amount and checkmark
                    HStack(alignment: .center, spacing: 12) {
                        // Success checkmark
                        if !isGenerating {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.green)
                            }
                        }

                        // Amount text
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(formatAmount(amount))
                                .font(.system(size: 36, weight: .semibold, design: .rounded))
                            Text("sats")
                                .font(.system(size: 18, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Mint info below
                    if let mint = mintURL?.host {
                        Label(mint, systemImage: "building.columns.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8))
                    }

                    // Status text
                    if isGenerating {
                        Text("Generating token...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    // Memo if present
                    if !memo.isEmpty {
                        Text(memo)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Action button
                    if let token = token, !token.isEmpty {
                        Button(action: shareToken) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle(isOfflineMode ? "Offline Token" : "Ecash Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [token ?? ""])
        }
        #endif
    }

    private func formatAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    private func copyToken() {
        guard let token = token else { return }

        #if os(iOS)
        UIPasteboard.general.string = token
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
        #endif

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }

    private func shareToken() {
        guard token != nil else { return }

        #if os(iOS)
        showShareSheet = true
        #else
        copyToken() // On macOS, just copy instead
        #endif
    }
}

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
