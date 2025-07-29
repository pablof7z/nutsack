import SwiftUI
import NDKSwift

// Simple redirect to the new unified authentication flow
struct SplashView: View {
    var body: some View {
        AuthenticationFlow()
    }
}

// MARK: - Electric Arc Shape (reused by AuthenticationFlow)
struct ElectricArc: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let start = CGPoint(
            x: startPoint.x * rect.width,
            y: startPoint.y * rect.height
        )
        let end = CGPoint(
            x: endPoint.x * rect.width,
            y: endPoint.y * rect.height
        )

        path.move(to: start)

        // Create a jagged lightning effect
        let segments = 8

        for i in 1...segments {
            let progress = CGFloat(i) / CGFloat(segments)
            let baseX = start.x + (end.x - start.x) * progress
            let baseY = start.y + (end.y - start.y) * progress

            // Add random offset for electric effect
            let offsetRange: CGFloat = 20
            let offsetX = CGFloat.random(in: -offsetRange...offsetRange)
            let offsetY = CGFloat.random(in: -offsetRange...offsetRange)

            let point = CGPoint(x: baseX + offsetX, y: baseY + offsetY)

            if i == segments {
                path.addLine(to: end)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

// MARK: - Dark Text Field Style (reused by AuthenticationFlow)
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color.white.opacity(0.08))
            .foregroundColor(.white)
            .accentColor(.orange)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
