import SwiftUI
import UIKit

// Script to generate app icons
// Run this in a SwiftUI app context to generate the icons

struct IconGenerator {
    @MainActor
    static func generateAllIcons() {
        let sizes: [(name: String, size: CGFloat)] = [
            ("Icon-1024", 1024),
            ("Icon-60@3x", 180),
            ("Icon-60@2x", 120),
            ("Icon-76@2x", 152),
            ("Icon-83.5@2x", 167)
        ]
        
        for (name, size) in sizes {
            if let image = exportIcon(size: size) {
                saveImage(image, name: name)
                print("Generated \(name).png (\(Int(size))×\(Int(size)))")
            }
        }
    }
    
    @MainActor
    static func exportIcon(size: CGFloat) -> UIImage? {
        let view = AppIconView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
    
    static func saveImage(_ image: UIImage, name: String) {
        guard let data = image.pngData() else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentsPath.appendingPathComponent("\(name).png")
        
        do {
            try data.write(to: filePath)
            print("Saved to: \(filePath)")
        } catch {
            print("Error saving \(name): \(error)")
        }
    }
}

// To use this, add a temporary button in your app:
// Button("Generate Icons") {
//     IconGenerator.generateAllIcons()
// }