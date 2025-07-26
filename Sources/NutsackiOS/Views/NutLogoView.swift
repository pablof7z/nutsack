import SwiftUI

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle: CGFloat = 60 * .pi / 180
        
        // Start from the top point
        var currentAngle: CGFloat = -90 * .pi / 180
        
        // Move to first vertex
        path.move(to: CGPoint(
            x: center.x + radius * cos(currentAngle),
            y: center.y + radius * sin(currentAngle)
        ))
        
        // Draw lines to create hexagon
        for _ in 0..<6 {
            currentAngle += angle
            path.addLine(to: CGPoint(
                x: center.x + radius * cos(currentAngle),
                y: center.y + radius * sin(currentAngle)
            ))
        }
        
        path.closeSubpath()
        return path
    }
}

struct NutLogoView: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 100, color: Color = .white) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        // Create a hexagon with a circular hole in the center
        HexagonShape()
            .fill(color)
            .frame(width: size, height: size)
            .mask(
                ZStack {
                    // Full hexagon
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: size * 2, height: size * 2)
                    
                    // Cut out the center circle
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.4, height: size * 0.4)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            )
    }
}

struct NutLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NutLogoView(size: 100, color: .orange)
            NutLogoView(size: 50, color: .white)
                .background(Color.black)
            NutLogoView(size: 200, color: .purple)
        }
    }
}