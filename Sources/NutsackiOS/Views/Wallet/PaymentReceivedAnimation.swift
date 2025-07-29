import SwiftUI
import UIKit

struct PaymentReceivedAnimation: View {
    let amount: Int64
    let onComplete: () -> Void

    @State private var showAmount = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var amountOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var successTextOpacity: Double = 0

    var body: some View {
        ZStack {
            // Subtle dark backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onComplete()
                }

            // Soft radial gradient
            RadialGradient(
                colors: [
                    Color.orange.opacity(glowOpacity * 0.15),
                    Color.orange.opacity(glowOpacity * 0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Elegant expanding ring with checkmark
                ZStack {
                    // Single elegant ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Elegant checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.orange.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(checkmarkScale)
                }

                // Amount display
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(amount)")
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("sats")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .opacity(amountOpacity)

                    Text("Payment Received")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .opacity(successTextOpacity)
                }
            }
        }
        .onAppear {
            startElegantAnimation()
        }
    }

    private func startElegantAnimation() {
        // Subtle haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()

        // Fade in backdrop glow
        withAnimation(.easeIn(duration: 0.4)) {
            glowOpacity = 1
        }

        // Ring animation
        withAnimation(.easeOut(duration: 0.6)) {
            ringOpacity = 1
            ringScale = 1
        }

        // Checkmark appears with spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                checkmarkScale = 1
            }
            impactFeedback.impactOccurred()
        }

        // Amount fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                amountOpacity = 1
            }
        }

        // Success text appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.3)) {
                successTextOpacity = 1
            }

            // Light success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }

        // Auto dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                amountOpacity = 0
                successTextOpacity = 0
                checkmarkScale = 0.8
                ringOpacity = 0
                glowOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onComplete()
            }
        }
    }
}
