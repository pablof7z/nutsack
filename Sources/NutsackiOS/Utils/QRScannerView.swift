import SwiftUI
import NDKSwiftUI

#if os(iOS)
// Use the shared QR scanner from NDKSwiftUI
typealias QRScannerView = NDKUIQRScanner
#else
// Placeholder for non-iOS platforms
struct QRScannerView: View {
    let onScan: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        Text("QR scanning is only available on iOS")
            .foregroundColor(.secondary)
    }
}
#endif
