import SwiftUI
import NDKSwift
import SwiftData

struct WalletOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletManager.self) private var walletManager
    @Environment(NostrManager.self) private var nostrManager
    @Environment(\.colorScheme) private var colorScheme
    
    enum AuthMode {
        case none
        case create
        case `import`
    }
    
    let authMode: AuthMode
    
    @State private var currentStep: Int
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -180
    @State private var glowOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 50
    @State private var electricityOffset: CGFloat = -100
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    
    @State private var selectedRelays: Set<String> = []
    @State private var selectedMints: Set<String> = []
    @State private var isSettingUpWallet = false
    @State private var setupError: String?
    @State private var showError = false
    
    // Mint discovery
    @State private var discoveredMints: [DiscoveredMint] = []
    @State private var isDiscoveringMints = true // Start as true since we begin discovery immediately
    @State private var mintDiscoveryTask: Task<Void, Never>?
    
    // Auth form states
    @State private var displayName = ""
    @State private var nsecInput = ""
    @State private var showPassword = false
    @State private var isProcessing = false
    @State private var showScanner = false
    @State private var authError: String?
    @State private var showAuthError = false
    @State private var loginStatus = ""
    
    // Avatar states
    @State private var avatarSeed = UUID().uuidString
    @State private var selectedAvatar = ""
    
    init(authMode: AuthMode = .none) {
        self.authMode = authMode
        // If authMode is .none, skip auth and go to step 1
        self._currentStep = State(initialValue: authMode == .none ? 1 : 0)
    }
    
    private var currentTitle: String {
        switch currentStep {
        case 0: return authMode == .create ? "REGISTER" : authMode == .import ? "LOGIN" : "AUTHENTICATE"
        case 1: return "SETUP"
        case 2: return "RELAYS"
        case 3: return "MINTS"
        default: return ""
        }
    }
    
    // Default relay suggestions
    let suggestedRelays = [
        RelayInfo(url: RelayConstants.primal, name: "Primal", description: "Fast and reliable public relay"),
        RelayInfo(url: RelayConstants.damus, name: "Damus", description: "Popular iOS-friendly relay"),
        RelayInfo(url: RelayConstants.nosLol, name: "nos.lol", description: "High-performance relay"),
        RelayInfo(url: RelayConstants.nostrBand, name: "Nostr Band", description: "Analytics and search relay"),
        RelayInfo(url: RelayConstants.nostrWine, name: "Nostr Wine", description: "Paid relay with spam protection")
    ]
    
    
    var body: some View {
        ZStack {
            // Dark gradient background
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
            
            // Electric field effect
            ForEach(0..<3) { index in
                ElectricArc(
                    startPoint: CGPoint(x: 0.5, y: 0.5),
                    endPoint: CGPoint(
                        x: 0.5 + cos(Double(index) * .pi / 1.5) * 0.3,
                        y: 0.5 + sin(Double(index) * .pi / 1.5) * 0.3
                    )
                )
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange.opacity(0.4),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .center,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 2)
                .opacity(glowOpacity * 0.5)
                .offset(y: electricityOffset)
                .animation(
                    .easeInOut(duration: 3)
                    .delay(Double(index) * 0.2)
                    .repeatForever(autoreverses: true),
                    value: electricityOffset
                )
            }
            
            VStack(spacing: 0) {
                // Compact header with logo and title side by side
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 20) {
                        // Logo section
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.orange.opacity(0.6),
                                            Color.purple.opacity(0.3),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 40
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .blur(radius: 15)
                                .scaleEffect(pulseScale)
                                .opacity(logoOpacity * 0.7)
                            
                            // Logo background
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
                                .frame(width: 60, height: 60)
                                .shadow(color: Color.orange.opacity(0.5), radius: 10, x: 0, y: 2)
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                                .rotationEffect(.degrees(logoRotation))
                            
                            // Nut logo
                            NutLogoView(size: 35, color: .white)
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                                .rotationEffect(.degrees(logoRotation))
                        }
                        
                        // Title with animation
                        Text(currentTitle)
                            .font(.system(size: 40, weight: .black))
                            .tracking(2)
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
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 2)
                            .opacity(titleOpacity)
                            .offset(x: titleOffset)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    
                    // Step indicator under the header
                    HStack(spacing: 12) {
                        ForEach(0..<4) { step in
                            Capsule()
                                .fill(currentStep >= step ? Color.orange : Color.white.opacity(0.2))
                                .frame(width: currentStep == step ? 32 : 16, height: 4)
                                .animation(.easeInOut(duration: 0.3), value: currentStep)
                        }
                    }
                    .opacity(contentOpacity)
                }
                .padding(.top, 30)
                
                // Content
                VStack {
                    switch currentStep {
                    case 0:
                        if authMode == .create {
                            createAccountForm
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else if authMode == .import {
                            importAccountForm
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            // This shouldn't happen as authMode should be set
                            EmptyView()
                        }
                    case 1:
                        WelcomeStepView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 2:
                        RelaySelectionView(
                            selectedRelays: $selectedRelays,
                            suggestedRelays: suggestedRelays
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    case 3:
                        MintSelectionView(
                            selectedMints: $selectedMints,
                            discoveredMints: discoveredMints,
                            isDiscoveringMints: isDiscoveringMints
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .offset(y: contentOffset)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    if currentStep == 0 {
                        // Auth form buttons - handled within forms
                        EmptyView()
                    } else if currentStep == 1 {
                        // Continue button
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = 2
                            }
                        }) {
                            HStack {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
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
                        
                        // Logout button
                        Button(action: {
                            Task {
                                await nostrManager.logout()
                                dismiss()
                            }
                        }) {
                            Text("Logout")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    } else if currentStep == 2 {
                        // Next button for relay selection
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = 3
                            }
                        }) {
                            HStack {
                                Text("Next: Select Mints")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        selectedRelays.isEmpty ? Color.gray : Color.orange,
                                        selectedRelays.isEmpty ? Color.gray.opacity(0.8) : Color(red: 0.9, green: 0.5, blue: 0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: selectedRelays.isEmpty ? Color.clear : Color.orange.opacity(0.3), radius: 10, x: 0, y: 4)
                        }
                        .disabled(selectedRelays.isEmpty)
                        
                        // Back button
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = 1
                            }
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    } else if currentStep == 3 {
                        // Setup wallet button
                        Button(action: setupWallet) {
                            if isSettingUpWallet {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Complete Setup")
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
                        }
                        .disabled(selectedRelays.isEmpty || isSettingUpWallet)
                        
                        // Back button
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentStep = 2
                            }
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .offset(y: contentOffset)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            animateOnboarding()
            // Start mint discovery immediately when view appears
            startMintDiscovery()
        }
        .onDisappear {
            // Cancel mint discovery when view disappears
            mintDiscoveryTask?.cancel()
        }
        .alert("Setup Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(setupError ?? "Failed to setup wallet")
        }
        .alert("Error", isPresented: $showAuthError) {
            Button("OK") { }
        } message: {
            Text(authError ?? "An error occurred")
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scannedValue in
                nsecInput = scannedValue
                showScanner = false
            }
        }
    }
    
    private func animateOnboarding() {
        // Logo animation
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
            logoScale = 1
            logoOpacity = 1
            logoRotation = 0
        }
        
        // Title animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5)) {
            titleOpacity = 1
            titleOffset = 0
        }
        
        // Glow effects
        withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
            glowOpacity = 1
        }
        
        // Electricity animation
        withAnimation(.easeInOut(duration: 2).delay(0.5).repeatForever(autoreverses: true)) {
            electricityOffset = 100
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).delay(0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        // Content animation
        withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
            contentOffset = 0
            contentOpacity = 1
        }
    }
    
    private func startMintDiscovery() {
        // Start mint discovery immediately, even before authentication
        mintDiscoveryTask = Task {
            // Wait for NDK to be available (should be almost immediate)
            while nostrManager.ndk == nil && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
            guard let ndk = nostrManager.ndk, !Task.isCancelled else { return }
            
            // Use MintDiscoveryManager to get mints
            let discoveryManager = MintDiscoveryManager(ndk: ndk)
            
            // Create an async stream to collect discovered mints
            for await mints in discoveryManager.discoverMintsStream() {
                guard !Task.isCancelled else { break }
                
                await MainActor.run {
                    self.discoveredMints = mints
                    // After first batch of mints, we're no longer "discovering"
                    if !mints.isEmpty && self.isDiscoveringMints {
                        self.isDiscoveringMints = false
                    }
                }
            }
        }
    }
    
    private func setupWallet() {
        guard !selectedRelays.isEmpty && !selectedMints.isEmpty else { return }
        
        isSettingUpWallet = true
        setupError = nil
        
        Task {
            do {
                guard let wallet = walletManager.activeWallet else {
                    throw NSError(domain: "WalletOnboarding", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active wallet found"])
                }
                
                // Setup wallet with selected relays and mints
                try await wallet.setup(
                    mints: Array(selectedMints),
                    relays: Array(selectedRelays),
                    publishMintList: true
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    setupError = error.localizedDescription
                    showError = true
                    isSettingUpWallet = false
                }
            }
        }
    }
    
    // MARK: - Auth Forms
    
    @ViewBuilder
    private var createAccountForm: some View {
        VStack(spacing: 20) {
            // Avatar selection
            VStack(spacing: 12) {
                Text("Choose Your Avatar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                
                Button(action: randomizeAvatar) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                            )
                        
                        if !selectedAvatar.isEmpty {
                            AsyncImage(url: URL(string: selectedAvatar)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(Circle())
                            } placeholder: {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            }
                            .frame(width: 110, height: 110)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                        
                        // Refresh icon overlay
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.orange))
                            .offset(x: 40, y: 40)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Tap to generate a new avatar")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            
            // Form fields
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))
                    
                    TextField("", text: $displayName)
                        .textFieldStyle(DarkTextFieldStyle())
                        .textContentType(.name)
                }
                
                
                Text("This information will be public on Nostr")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Create button
            Button(action: createAccount) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        displayName.isEmpty ? Color.gray : Color.orange,
                        displayName.isEmpty ? Color.gray.opacity(0.8) : Color(red: 0.9, green: 0.5, blue: 0.1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: displayName.isEmpty ? Color.clear : Color.orange.opacity(0.3), radius: 10, x: 0, y: 4)
            .disabled(displayName.isEmpty || isProcessing)
            
            // Cancel button
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(.top, 8)
        }
        .onAppear {
            generateInitialAvatar()
        }
    }
    
    @ViewBuilder
    private var importAccountForm: some View {
        VStack(spacing: 20) {
            // Form fields
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Private Key")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.8))
                    
                    HStack(spacing: 12) {
                        HStack {
                            if showPassword {
                                TextField("nsec1...", text: $nsecInput)
                                    .textContentType(.password)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("nsec1...", text: $nsecInput)
                                    .textContentType(.password)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.callout)
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .accentColor(.orange)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: { showScanner = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.4))
                        
                        Text("Your key is stored securely on this device")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Login button
            Button(action: importAccount) {
                if isProcessing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        Text(loginStatus.isEmpty ? "Logging in..." : loginStatus)
                            .fontWeight(.semibold)
                    }
                } else {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        nsecInput.isEmpty ? Color.gray : Color.orange,
                        nsecInput.isEmpty ? Color.gray.opacity(0.8) : Color(red: 0.9, green: 0.5, blue: 0.1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: nsecInput.isEmpty ? Color.clear : Color.orange.opacity(0.3), radius: 10, x: 0, y: 4)
            .disabled(nsecInput.isEmpty || isProcessing)
            
            // Cancel button
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Auth Actions
    
    private func createAccount() {
        guard !displayName.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                _ = try await nostrManager.createNewAccount(
                    displayName: displayName,
                    about: nil,
                    picture: selectedAvatar.isEmpty ? nil : selectedAvatar
                )
                
                await MainActor.run {
                    isProcessing = false
                    // Transition to welcome step
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        currentStep = 1
                    }
                    // Mint discovery is already running, no need to start it again
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    showAuthError = true
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - Avatar Methods
    
    private func generateInitialAvatar() {
        avatarSeed = UUID().uuidString
        selectedAvatar = generateDicebearURL(seed: avatarSeed)
    }
    
    private func randomizeAvatar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            avatarSeed = UUID().uuidString
            selectedAvatar = generateDicebearURL(seed: avatarSeed)
        }
    }
    
    private func generateDicebearURL(seed: String) -> String {
        // Using bottts style for a fun robot-like avatar
        // You can change the style to: adventurer, avataaars, big-ears, big-smile, bottts, croodles, fun-emoji, lorelei, micah, miniavs, open-peeps, personas, pixel-art
        let style = "bottts"
        let size = 200
        return "https://api.dicebear.com/7.x/\(style)/png?seed=\(seed)&size=\(size)"
    }
    
    private func importAccount() {
        isProcessing = true
        loginStatus = "Authenticating..."
        
        Task {
            do {
                // Step 1: Create signer and authenticate
                let signer = try NDKPrivateKeySigner(nsec: nsecInput)
                let pubkey = try await signer.pubkey
                
                await MainActor.run {
                    loginStatus = "Finding your relays..."
                }
                
                // Step 2: Create session (this starts the outbox relay discovery)
                let _ = try await nostrManager.createAccountFromNsec(
                    nsecInput,
                    displayName: "Loading..." // We'll update this later
                )
                
                guard let ndk = nostrManager.ndk else {
                    throw NostrError.ndkNotInitialized
                }
                
                // Step 3: Use outbox to track user and find their relays
                await ndk.outbox.trackUser(pubkey)
                
                // Wait for relay discovery (with timeout)
                var retries = 0
                var userRelays: [String] = []
                while userRelays.isEmpty && retries < 30 {
                    userRelays = await ndk.outbox.getRecommendedRelays(for: pubkey)
                    if userRelays.isEmpty {
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        retries += 1
                    }
                }
                print("Found \(userRelays.count) relays for user")
                
                await MainActor.run {
                    loginStatus = "Importing wallet..."
                }
                
                // Step 4: Check for existing wallet (kind 17375)
                let walletFilter = NDKFilter(
                    authors: [pubkey],
                    kinds: [EventKind.cashuWalletConfig], // NIP-60 wallet configuration
                    limit: 1
                )
                
                var walletFound = false
                let walletDataSource = ndk.observe(
                    filter: walletFilter,
                    maxAge: 0, // Force network fetch
                    cachePolicy: .networkOnly
                )
                
                // Wait for EOSE to ensure we've checked all relays
                for await event in walletDataSource.events {
                    if event.kind == EventKind.cashuWalletConfig {
                        walletFound = true
                        print("Found existing wallet configuration")
                        break
                    }
                }
                
                // Also fetch profile while we're at it
                var displayName = "Nostr User"
                let profileDataSource = ndk.observe(
                    filter: NDKFilter(
                        authors: [pubkey],
                        kinds: [0]
                    ),
                    maxAge: 3600,
                    cachePolicy: .cacheWithNetwork
                )
                
                for await event in profileDataSource.events {
                    if let profileData = event.content.data(using: .utf8),
                       let profile = JSONCoding.safeDecode(NDKUserProfile.self, from: profileData) {
                        displayName = profile.displayName ?? profile.name ?? "Nostr User"
                        break
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    loginStatus = ""
                    
                    if walletFound {
                        // Step 5: Go directly to main screen if wallet exists
                        // Load the wallet before dismissing
                        Task {
                            do {
                                try await walletManager.loadWalletForCurrentUser()
                                await MainActor.run {
                                    dismiss()
                                }
                            } catch {
                                print("Failed to load wallet: \(error)")
                                // Still dismiss but wallet loading failed
                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }
                    } else {
                        // Go to wallet setup if no wallet found
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                            currentStep = 1
                        }
                        // Mint discovery is already running, no need to start it again
                    }
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    showAuthError = true
                    isProcessing = false
                    loginStatus = ""
                }
            }
        }
    }
}

// MARK: - Welcome Step View
struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Let's set up your Cashu wallet to enable instant, private payments")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Feature highlights
            VStack(spacing: 20) {
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Lightning Fast",
                    description: "Instant payments with minimal fees"
                )
                
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Private & Secure",
                    description: "Your transactions stay private"
                )
                
                FeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Decentralized",
                    description: "No single point of failure"
                )
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

// MARK: - Relay Selection View
struct RelaySelectionView: View {
    @Binding var selectedRelays: Set<String>
    let suggestedRelays: [RelayInfo]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select relays to sync your wallet data")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            // Relay list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(suggestedRelays, id: \.url) { relay in
                        OnboardingRelayRowView(
                            relay: relay,
                            isSelected: selectedRelays.contains(relay.url),
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedRelays.contains(relay.url) {
                                        selectedRelays.remove(relay.url)
                                    } else {
                                        selectedRelays.insert(relay.url)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
            
            // Selection hint
            Text("\(selectedRelays.count) relay\(selectedRelays.count == 1 ? "" : "s") selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }
}

// MARK: - Relay Row View
struct OnboardingRelayRowView: View {
    let relay: RelayInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Relay icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange.opacity(0.2),
                                    Color.orange.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 22))
                        .foregroundColor(.orange)
                }
                
                // Relay info
                VStack(alignment: .leading, spacing: 4) {
                    Text(relay.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(relay.description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Relay Info
struct RelayInfo {
    let url: String
    let name: String
    let description: String
}


// MARK: - Mint Selection View
struct MintSelectionView: View {
    @Binding var selectedMints: Set<String>
    let discoveredMints: [DiscoveredMint]
    let isDiscoveringMints: Bool
    
    @State private var manualMintURL = ""
    @State private var showManualInput = false
    @State private var isAddingMint = false
    @State private var addMintError: String?
    @Environment(WalletManager.self) private var walletManager
    
    var sortedMints: [DiscoveredMint] {
        discoveredMints.sorted { first, second in
            // Sort by presence of icon first (mints with icons come first)
            if (first.mintInfo?.iconURL != nil) != (second.mintInfo?.iconURL != nil) {
                return first.mintInfo?.iconURL != nil
            }
            // Then by recommendation count
            if first.recommendedBy.count != second.recommendedBy.count {
                return first.recommendedBy.count > second.recommendedBy.count
            }
            // Then by announcement date
            let firstDate = first.announcementCreatedAt ?? 0
            let secondDate = second.announcementCreatedAt ?? 0
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            infoCard
            mintListContent
            selectedCountView
        }
    }
    
    @ViewBuilder
    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green.opacity(0.8))
            
            Text("Mints are custodial services that issue ecash tokens. Select multiple mints to spread risk.")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(infoCardBackground)
    }
    
    @ViewBuilder
    private var infoCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.green.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var mintListContent: some View {
        // Always show the scroll view, even if empty
        // This follows the "never wait, always stream" philosophy
        mintScrollView
    }
    
    @ViewBuilder
    private var discoveringView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
            
            Text("Discovering mints...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .frame(maxHeight: 300)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("No mints discovered")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
            
            Text("Check your internet connection and try again")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: 300)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var mintScrollView: some View {
        ScrollView {
            VStack(spacing: 12) {
                customMintSection
                
                // Show discovery status if still loading and no mints yet
                if isDiscoveringMints && discoveredMints.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                        
                        Text("Finding recommended mints...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.6))
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(sectionBackground)
                }
                
                discoveredMintsSection
                manuallyAddedMintsSection
                
                // Show a hint if no mints discovered yet
                if discoveredMints.isEmpty && !isDiscoveringMints {
                    VStack(spacing: 12) {
                        Text("No recommended mints found yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                        
                        Text("You can add custom mints above or wait for recommendations")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var customMintSection: some View {
        VStack(spacing: 12) {
            customMintHeader
            
            if showManualInput {
                customMintInputSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(sectionBackground)
    }
    
    @ViewBuilder
    private var customMintHeader: some View {
        HStack {
            Text("Add Custom Mint")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.9))
            
            Spacer()
            
            Button(action: toggleManualInput) {
                Image(systemName: showManualInput ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
    private var customMintInputSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                mintURLTextField
                addMintButton
            }
            
            if let error = addMintError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private var mintURLTextField: some View {
        TextField("https://mint.example.com", text: $manualMintURL)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(.white)
            .padding(12)
            .background(textFieldBackground)
            .autocapitalization(.none)
            .disableAutocorrection(true)
    }
    
    @ViewBuilder
    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var addMintButton: some View {
        Button(action: addManualMint) {
            if isAddingMint {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 44, height: 44)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(manualMintURL.isEmpty ? Color.gray : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .disabled(manualMintURL.isEmpty || isAddingMint)
    }
    
    @ViewBuilder
    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var discoveredMintsSection: some View {
        ForEach(sortedMints, id: \.url) { mint in
            MintRowView(
                mint: mint,
                isSelected: selectedMints.contains(mint.url),
                onTap: { toggleMintSelection(mint.url) }
            )
        }
    }
    
    @ViewBuilder
    private var manuallyAddedMintsSection: some View {
        let customMints = selectedMints.subtracting(Set(discoveredMints.map { $0.url }))
        ForEach(Array(customMints), id: \.self) { mintURL in
            CustomMintRowView(
                mintURL: mintURL,
                isSelected: true,
                onTap: { removeMint(mintURL) }
            )
        }
    }
    
    @ViewBuilder
    private var selectedCountView: some View {
        if !selectedMints.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Text("\(selectedMints.count) mint\(selectedMints.count == 1 ? "" : "s") selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                
                Spacer()
            }
        }
    }
    
    private func toggleManualInput() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showManualInput.toggle()
            manualMintURL = ""
            addMintError = nil
        }
    }
    
    private func toggleMintSelection(_ url: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedMints.contains(url) {
                selectedMints.remove(url)
            } else {
                selectedMints.insert(url)
            }
        }
    }
    
    private func removeMint(_ url: String) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            selectedMints.remove(url)
        }
    }
    
    private func addManualMint() {
        let trimmedURL = manualMintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate URL
        guard !trimmedURL.isEmpty,
              let url = URL(string: trimmedURL),
              url.scheme == "https" || url.scheme == "http" else {
            addMintError = "Please enter a valid mint URL (e.g., https://mint.example.com)"
            return
        }
        
        // Check if already added
        if selectedMints.contains(trimmedURL) || discoveredMints.contains(where: { $0.url == trimmedURL }) {
            addMintError = "This mint has already been added"
            return
        }
        
        // Add to selected mints
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMints.insert(trimmedURL)
            manualMintURL = ""
            showManualInput = false
            addMintError = nil
        }
    }
}

// MARK: - Custom Mint Row View
struct CustomMintRowView: View {
    let mintURL: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(WalletManager.self) private var walletManager
    @State private var mintInfo: NDKMintInfo?
    
    var displayName: String {
        if let name = mintInfo?.name, !name.isEmpty {
            return name
        } else if let url = URL(string: mintURL), let host = url.host {
            return host
        } else {
            return "Custom Mint"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Mint icon
                MintIconView(
                    mint: DiscoveredMint(url: mintURL, name: displayName),
                    mintInfo: mintInfo
                )
                
                // Mint info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let description = mintInfo?.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(2)
                    } else {
                        Text("Custom mint")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    
                    Text(mintURL)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadMintInfo()
        }
    }
    
    private func loadMintInfo() async {
        guard mintInfo == nil,
              let wallet = walletManager.activeWallet,
              let url = URL(string: mintURL) else { return }
        
        do {
            let info = try await wallet.mints.getMintInfo(url: url)
            await MainActor.run {
                self.mintInfo = info
            }
        } catch {
            // Silently fail - we'll just use the default icon
        }
    }
}

// MARK: - Mint Row View
struct MintRowView: View {
    let mint: DiscoveredMint
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(WalletManager.self) private var walletManager
    @State private var mintInfo: NDKMintInfo?
    @State private var isLoadingIcon = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Mint icon
                MintIconView(mint: mint, mintInfo: mintInfo)
                
                // Mint info
                VStack(alignment: .leading, spacing: 4) {
                    Text(mint.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let description = mint.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(2)
                    } else if let mintDescription = mintInfo?.description, !mintDescription.isEmpty {
                        Text(mintDescription)
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    
                    Text(mint.url)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadMintInfo()
        }
    }
    
    private func loadMintInfo() async {
        guard mintInfo == nil,
              let wallet = walletManager.activeWallet,
              let url = URL(string: mint.url) else { return }
        
        do {
            let info = try await wallet.mints.getMintInfo(url: url)
            await MainActor.run {
                self.mintInfo = info
            }
        } catch {
            // Silently fail - we'll just use the default icon
        }
    }
}

// MARK: - Mint Icon View
struct MintIconView: View {
    let mint: DiscoveredMint
    let mintInfo: NDKMintInfo?
    @State private var hasError = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.2),
                            Color.green.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
            
            if let iconURL = mintInfo?.iconURL,
               !iconURL.isEmpty,
               let url = URL(string: iconURL),
               !hasError {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 48, height: 48)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure(_):
                        Image(systemName: "building.columns")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                            .onAppear {
                                hasError = true
                            }
                    @unknown default:
                        Image(systemName: "building.columns")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }
                }
            } else {
                Image(systemName: "building.columns")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Preview
struct WalletOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        WalletOnboardingView()
            .environment(WalletManager(
                nostrManager: NostrManager(from: "Preview"),
                modelContext: try! ModelContainer(for: Transaction.self).mainContext,
                appState: AppState()
            ))
            .environment(NostrManager(from: "Preview"))
    }
}