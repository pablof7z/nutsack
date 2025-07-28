import SwiftUI
import NDKSwift

// Helper views for accessing async user profile properties

struct UserDisplayName: View {
    let pubkey: String
    @Environment(NostrManager.self) private var nostrManager
    @State private var profile: NDKUserProfile?
    @State private var observationTask: Task<Void, Never>?
    
    init(user: NDKUser) {
        self.pubkey = user.pubkey
    }
    
    init(pubkey: String) {
        self.pubkey = pubkey
    }
    
    var body: some View {
        Text(displayName)
            .task(id: pubkey) {
                await loadProfile()
            }
            .onAppear {
                startObservingContactsMetadata()
            }
            .onDisappear {
                observationTask?.cancel()
            }
    }
    
    private var displayName: String {
        // First check if profile is in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey) {
            return cachedProfile.displayName ?? cachedProfile.name ?? fallbackName
        }
        
        // Otherwise use loaded profile
        return profile?.displayName ?? profile?.name ?? fallbackName
    }
    
    private var fallbackName: String {
        // Show shortened npub as fallback instead of generic "Nostr User"
        let npub = NDKUser(pubkey: pubkey).npub
        return String(npub.prefix(16)) + "..."
    }
    
    private func loadProfile() async {
        guard let ndk = nostrManager.ndk else { return }
        
        // Check if already in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey) {
            await MainActor.run {
                self.profile = cachedProfile
            }
            return
        }
        
        // Load individual profile using NDK's profile manager
        for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: TimeConstants.hour) {
            await MainActor.run {
                self.profile = profile
            }
            break // Only need first value
        }
    }
    
    private func startObservingContactsMetadata() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            guard let contactsMetadata = nostrManager.contactsMetadataDataSource else { return }
            
            for await profiles in contactsMetadata.$profiles.values {
                if let updatedProfile = profiles[pubkey] {
                    self.profile = updatedProfile
                }
            }
        }
    }
}

struct UserProfilePicture: View {
    let pubkey: String
    let size: CGFloat
    @Environment(NostrManager.self) private var nostrManager
    @State private var profile: NDKUserProfile?
    @State private var observationTask: Task<Void, Never>?
    
    init(user: NDKUser, size: CGFloat = 40) {
        self.pubkey = user.pubkey
        self.size = size
    }
    
    init(pubkey: String, size: CGFloat = 40) {
        self.pubkey = pubkey
        self.size = size
    }
    
    var body: some View {
        Group {
            if let pictureURL = pictureURL,
               let url = URL(string: pictureURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderCircle
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                placeholderCircle
            }
        }
        .task(id: pubkey) {
            await loadProfile()
        }
        .onAppear {
            startObservingContactsMetadata()
        }
        .onDisappear {
            observationTask?.cancel()
        }
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: size, height: size)
    }
    
    private var pictureURL: String? {
        // First check if profile is in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey) {
            return cachedProfile.picture
        }
        
        // Otherwise use loaded profile
        return profile?.picture
    }
    
    private func loadProfile() async {
        guard let ndk = nostrManager.ndk else { return }
        
        // Check if already in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey) {
            await MainActor.run {
                self.profile = cachedProfile
            }
            return
        }
        
        // Load individual profile using NDK's profile manager
        for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: TimeConstants.hour) {
            await MainActor.run {
                self.profile = profile
            }
            break // Only need first value
        }
    }
    
    private func startObservingContactsMetadata() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            guard let contactsMetadata = nostrManager.contactsMetadataDataSource else { return }
            
            for await profiles in contactsMetadata.$profiles.values {
                if let updatedProfile = profiles[pubkey] {
                    self.profile = updatedProfile
                }
            }
        }
    }
}

struct UserNIP05: View {
    let pubkey: String
    let npub: String?
    @Environment(NostrManager.self) private var nostrManager
    @State private var profile: NDKUserProfile?
    @State private var observationTask: Task<Void, Never>?
    
    init(user: NDKUser) {
        self.pubkey = user.pubkey
        self.npub = user.npub
    }
    
    init(pubkey: String) {
        self.pubkey = pubkey
        self.npub = NDKUser(pubkey: pubkey).npub
    }
    
    var body: some View {
        Text(displayText)
            .task(id: pubkey) {
                await loadProfile()
            }
            .onAppear {
                startObservingContactsMetadata()
            }
            .onDisappear {
                observationTask?.cancel()
            }
    }
    
    private var displayText: String {
        // First check if profile is in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey),
           let nip05 = cachedProfile.nip05 {
            return nip05
        }
        
        // Otherwise use loaded profile
        if let nip05 = profile?.nip05 {
            return nip05
        }
        
        // Fallback to npub or pubkey
        return (npub ?? pubkey).prefix(16) + "..."
    }
    
    private func loadProfile() async {
        guard let ndk = nostrManager.ndk else { return }
        
        // Check if already in contacts metadata
        if let profileDataSource = nostrManager.contactsMetadataDataSource,
           let cachedProfile = profileDataSource.profile(for: pubkey) {
            await MainActor.run {
                self.profile = cachedProfile
            }
            return
        }
        
        // Load individual profile using NDK's profile manager
        for await profile in await ndk.profileManager.observe(for: pubkey, maxAge: TimeConstants.hour) {
            await MainActor.run {
                self.profile = profile
            }
            break // Only need first value
        }
    }
    
    private func startObservingContactsMetadata() {
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            guard let contactsMetadata = nostrManager.contactsMetadataDataSource else { return }
            
            for await profiles in contactsMetadata.$profiles.values {
                if let updatedProfile = profiles[pubkey] {
                    self.profile = updatedProfile
                }
            }
        }
    }
}