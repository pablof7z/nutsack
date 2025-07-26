import SwiftUI

struct AppIconView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.5, blue: 0.1),
                    Color.orange,
                    Color(red: 0.8, green: 0.4, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Hexagon shape
            HexagonShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange,
                            Color(red: 0.9, green: 0.5, blue: 0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    HexagonShape()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: size * 0.02
                        )
                )
                .padding(size * 0.15)
                .shadow(color: Color.black.opacity(0.3), radius: size * 0.02, x: 0, y: size * 0.02)
            
            // Inner glow effect
            HexagonShape()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
                .padding(size * 0.15)
                .blendMode(.overlay)
            
            // Text "N" for Nutsack
            Text("N")
                .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: size * 0.01, x: 0, y: size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

struct AppIconGenerator: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("App Icon Preview")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 20) {
                // 1024x1024 App Store icon
                VStack {
                    AppIconView(size: 256) // Preview at smaller size
                    Text("1024×1024 (App Store)")
                        .font(.caption)
                }
                
                HStack(spacing: 20) {
                    // 180x180 (60pt @3x for iPhone)
                    VStack {
                        AppIconView(size: 90)
                        Text("180×180")
                            .font(.caption)
                    }
                    
                    // 120x120 (60pt @2x for iPhone)
                    VStack {
                        AppIconView(size: 60)
                        Text("120×120")
                            .font(.caption)
                    }
                    
                    // 152x152 (76pt @2x for iPad)
                    VStack {
                        AppIconView(size: 76)
                        Text("152×152")
                            .font(.caption)
                    }
                    
                    // 167x167 (83.5pt @2x for iPad Pro)
                    VStack {
                        AppIconView(size: 83.5)
                        Text("167×167")
                            .font(.caption)
                    }
                }
            }
            
            Text("Export these at actual pixel sizes for production")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

// Preview for development
struct AppIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        AppIconGenerator()
    }
}

// Helper function to export icon at specific size
@MainActor
func exportAppIcon(size: CGFloat) -> UIImage? {
    let renderer = ImageRenderer(content: AppIconView(size: size))
    renderer.scale = 1.0
    return renderer.uiImage
}