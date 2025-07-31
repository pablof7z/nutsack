import SwiftUI
import NDKSwift

struct AuthenticationFlow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var nostrManager: NostrManager
    @Environment(WalletManager.self) private var walletManager
    @Environment(\.dismiss) private var dismiss

    // Shared animation values for smooth transitions
    @State private var logoSize: CGFloat = 140
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -180
    @State private var logoPosition = CGPoint(x: 0, y: 0)

    @State private var titleText = "NUTSACK"
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 0
    @State private var titleSize: CGFloat = 52

    @State private var sloganOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    // Background effects
    @State private var glowOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var electricityOffset: CGFloat = -100

    // Wallet onboarding sheet
    @State private var walletOnboardingAuthMode: WalletOnboardingView.AuthMode? = nil
    @State private var checkingExistingUser = true

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            electricEffects

            // Main content - centered vertically
            VStack(spacing: 40) {
                Spacer()

                // Animated header
                AnimatedHeader(
                    logoSize: logoSize,
                    logoOpacity: logoOpacity,
                    logoScale: logoScale,
                    logoRotation: logoRotation,
                    logoPosition: logoPosition,
                    titleText: titleText,
                    titleOpacity: titleOpacity,
                    titleOffset: titleOffset,
                    titleSize: titleSize,
                    sloganOpacity: sloganOpacity,
                    showSlogan: true,
                    glowOpacity: glowOpacity,
                    pulseScale: pulseScale
                )

                // Auth buttons
                authButtons
                    .opacity(contentOpacity)
                    .animation(.easeInOut(duration: 0.4), value: contentOpacity)

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            startSplashAnimation()
            checkForExistingUser()
        }
        .fullScreenCover(item: $walletOnboardingAuthMode) { authMode in
            WalletOnboardingView(authMode: authMode)
                .environmentObject(nostrManager)
                .environment(walletManager)
                .onDisappear {
                    // If wallet onboarding completes, dismiss the whole auth flow
                    Task {
                        if walletManager.isWalletConfigured {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var authButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                print("🔍 [AuthFlow] New Account clicked")
                print("🔍 [AuthFlow] NostrManager.isAuthenticated: \(nostrManager.isAuthenticated)")
                print("🔍 [AuthFlow] NostrManager has signer: \(nostrManager.ndk.signer != nil)")
                print("🔍 [AuthFlow] Setting authMode to: .create")
                walletOnboardingAuthMode = .create
            }) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20))
                    Text("New Account")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange,
                            Color(red: 0.9, green: 0.5, blue: 0.1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 4)
            }

            Button(action: {
                print("🔍 [AuthFlow] Login clicked")
                print("🔍 [AuthFlow] NostrManager.isAuthenticated: \(nostrManager.isAuthenticated)")
                print("🔍 [AuthFlow] NostrManager has signer: \(nostrManager.ndk.signer != nil)")
                print("🔍 [AuthFlow] Setting authMode to: .import")
                walletOnboardingAuthMode = .import
            }) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                    Text("Login")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text("Your keys, your nuts")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .padding(.top, 8)

            // Show logout option if authenticated
            if nostrManager.isAuthenticated {
                Button(action: {
                    Task {
                        await nostrManager.logout()
                    }
                }) {
                    Text("Logout from current account")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 32)
        .opacity(buttonsOpacity)
    }

    // MARK: - Background Views

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.02, blue: 0.08),
                Color(red: 0.02, green: 0.01, blue: 0.03),
                Color.black
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var electricEffects: some View {
        ForEach(0..<5) { index in
            ElectricArc(
                startPoint: CGPoint(x: 0.5, y: 0.5),
                endPoint: CGPoint(
                    x: 0.5 + cos(Double(index) * .pi / 2.5) * 0.4,
                    y: 0.5 + sin(Double(index) * .pi / 2.5) * 0.4
                )
            )
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.6),
                        Color.purple.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .center,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
            .blur(radius: 3)
            .opacity(glowOpacity * 0.3)
            .offset(y: electricityOffset)
            .animation(
                .easeInOut(duration: 2)
                .delay(Double(index) * 0.1)
                .repeatForever(autoreverses: true),
                value: electricityOffset
            )
        }
    }

    private var primaryButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.orange,
                Color(red: 0.9, green: 0.5, blue: 0.1)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Animation Methods

    private func startSplashAnimation() {
        // Logo animation
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
            logoScale = 1
            logoOpacity = 1
            logoRotation = 0
        }

        // Glow effects
        withAnimation(.easeInOut(duration: 1.5).delay(0.2)) {
            glowOpacity = 0.8
        }

        // Start electricity animation
        withAnimation(.easeInOut(duration: 2).delay(0.5).repeatForever(autoreverses: true)) {
            electricityOffset = 100
        }

        // Title animation - no offset change to prevent bouncing
        withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
            titleOpacity = 1
        }
        // Set titleOffset to 0 immediately without animation
        titleOffset = 0

        // Slogan animation
        withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
            sloganOpacity = 1
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).delay(1).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }

        // Button animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(2.0)) {
            buttonsOpacity = 1
            contentOpacity = 1
        }
    }

    private func checkForExistingUser() {
        // Don't do anything here - this entire view shouldn't be shown if authenticated
        checkingExistingUser = false
    }
}

// MARK: - Animated Header Component
struct AnimatedHeader: View {
    let logoSize: CGFloat
    let logoOpacity: Double
    let logoScale: CGFloat
    let logoRotation: Double
    let logoPosition: CGPoint
    let titleText: String
    let titleOpacity: Double
    let titleOffset: CGFloat
    let titleSize: CGFloat
    let sloganOpacity: Double
    let showSlogan: Bool
    let glowOpacity: Double
    let pulseScale: CGFloat

    var body: some View {
        VStack(spacing: 20) {
            // Logo
            ZStack {
                // Outer pulsing glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.8),
                                Color.purple.opacity(0.4),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 10,
                            endRadius: logoSize * 0.8
                        )
                    )
                    .frame(width: logoSize * 2, height: logoSize * 2)
                    .blur(radius: 30)
                    .scaleEffect(pulseScale)
                    .opacity(logoOpacity * 0.7)

                // Logo background circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange,
                                Color.orange.opacity(0.9),
                                Color(red: 0.8, green: 0.4, blue: 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: logoSize, height: logoSize)
                    .shadow(color: Color.orange.opacity(0.5), radius: 20, x: 0, y: 5)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotationEffect(.degrees(logoRotation))

                // Nut logo
                NutLogoView(size: logoSize * 0.57, color: .white)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotationEffect(.degrees(logoRotation))
            }
            .offset(x: logoPosition.x, y: logoPosition.y)

            // Title and slogan
            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: titleSize, weight: .black, design: .default))
                    .tracking(titleSize > 40 ? 4 : 3)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color.white.opacity(0.9)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 2)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                if showSlogan {
                    Text("A WALLET FOR THE RELAYS")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.7))
                        .opacity(sloganOpacity)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
