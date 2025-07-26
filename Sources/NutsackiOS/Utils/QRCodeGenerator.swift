import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A utility for generating QR code images from strings
public struct QRCodeGenerator {
    /// Generates a QR code image from the provided string
    /// - Parameters:
    ///   - string: The string to encode in the QR code
    ///   - scale: The scale factor for the QR code (default: 10)
    /// - Returns: A platform-specific image (UIImage for iOS, NSImage for macOS) or nil if generation fails
    #if os(iOS)
    public static func generate(from string: String, scale: CGFloat = 10) -> UIImage? {
        guard let data = string.data(using: .utf8) else { 
            print("QRCodeGenerator: Failed to convert string to UTF8 data")
            return nil 
        }
        
        // For very long strings (like cashu tokens), use low error correction
        let correctionLevel: String
        if string.count > 500 {
            correctionLevel = "L" // Low error correction for more data capacity
        } else {
            correctionLevel = "M" // Medium error correction for normal data
        }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel
        
        guard let outputImage = filter.outputImage else { 
            print("QRCodeGenerator: CIFilter failed to generate output image")
            return nil 
        }
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { 
            print("QRCodeGenerator: Failed to create CGImage from CIImage")
            return nil 
        }
        
        return UIImage(cgImage: cgImage)
    }
    #else
    public static func generate(from string: String, scale: CGFloat = 10) -> NSImage? {
        guard let data = string.data(using: .utf8) else { 
            print("QRCodeGenerator: Failed to convert string to UTF8 data")
            return nil 
        }
        
        // For very long strings (like cashu tokens), use low error correction
        let correctionLevel: String
        if string.count > 500 {
            correctionLevel = "L" // Low error correction for more data capacity
        } else {
            correctionLevel = "M" // Medium error correction for normal data
        }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = correctionLevel
        
        guard let outputImage = filter.outputImage else { 
            print("QRCodeGenerator: CIFilter failed to generate output image")
            return nil 
        }
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        
        return nsImage
    }
    #endif
}

/// A SwiftUI view that displays a QR code
public struct QRCodeView: View {
    let content: String
    var size: CGFloat = 250
    var backgroundColor: Color = .white
    var cornerRadius: CGFloat = 12
    
    public init(content: String, size: CGFloat = 250, backgroundColor: Color = .white, cornerRadius: CGFloat = 12) {
        self.content = content
        self.size = size
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        Group {
            if let qrImage = QRCodeGenerator.generate(from: content) {
                #if os(iOS)
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(backgroundColor)
                    .cornerRadius(cornerRadius)
                #else
                Image(nsImage: qrImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .background(backgroundColor)
                    .cornerRadius(cornerRadius)
                #endif
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Token too large for QR")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Use copy button below")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

/// A view modifier for displaying content with a QR code
public struct QRCodeDisplayModifier: ViewModifier {
    let content: String
    let title: String
    @Binding var isPresented: Bool
    
    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                QRCodeDisplayView(
                    content: self.content,
                    title: title,
                    isPresented: $isPresented
                )
            }
    }
}

/// A full-screen QR code display view with copy functionality
public struct QRCodeDisplayView: View {
    let content: String
    let title: String
    @Binding var isPresented: Bool
    @State private var copied = false
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer(minLength: 40)
                
                // QR Code
                QRCodeView(content: content)
                
                // Content text
                VStack(spacing: 12) {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                    
                    Button(action: copyContent) {
                        Label(
                            copied ? "Copied!" : "Copy",
                            systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? .green : .orange)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(title)
            .platformNavigationBarTitleDisplayMode(inline: true)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
    
    private func copyContent() {
        content.copyToPasteboard()
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

// MARK: - View Extensions
public extension View {
    /// Presents a QR code display sheet
    func qrCodeSheet(for content: String, title: String, isPresented: Binding<Bool>) -> some View {
        modifier(QRCodeDisplayModifier(content: content, title: title, isPresented: isPresented))
    }
}