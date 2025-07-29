import SwiftUI
import NDKSwiftUI

// Type aliases for backward compatibility
public typealias QRCodeGenerator = NDKUIQRCodeGenerator
public typealias QRCodeView = NDKUIQRCodeView
public typealias QRCodeDisplayModifier = NDKUIQRCodeDisplayModifier
public typealias QRCodeDisplayView = NDKUIQRCodeDisplayView

// MARK: - View Extensions
public extension View {
    /// Presents a QR code display sheet (compatibility wrapper)
    func qrCodeSheet(for content: String, title: String, isPresented: Binding<Bool>) -> some View {
        self.ndkQRCodeSheet(for: content, title: title, isPresented: isPresented)
    }
}
