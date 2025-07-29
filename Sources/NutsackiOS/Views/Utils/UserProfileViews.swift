import SwiftUI
import NDKSwift
import NDKSwiftUI

// Lightweight wrappers around NDKSwiftUI components to maintain API compatibility
// while leveraging NDKSwiftUI's proven implementation

struct UserDisplayName: View {
    let pubkey: String
    @Environment(NostrManager.self) private var nostrManager

    init(user: NDKUser) {
        self.pubkey = user.pubkey
    }

    init(pubkey: String) {
        self.pubkey = pubkey
    }

    var body: some View {
        NDKUIDisplayName(pubkey: pubkey)
            .environment(\.ndk, nostrManager.ndk)
    }
}

struct UserProfilePicture: View {
    let pubkey: String
    let size: CGFloat
    @Environment(NostrManager.self) private var nostrManager

    init(user: NDKUser, size: CGFloat = 40) {
        self.pubkey = user.pubkey
        self.size = size
    }

    init(pubkey: String, size: CGFloat = 40) {
        self.pubkey = pubkey
        self.size = size
    }

    var body: some View {
        NDKUIProfilePicture(pubkey: pubkey)
            .frame(width: size, height: size)
            .environment(\.ndk, nostrManager.ndk)
    }
}

struct UserNIP05: View {
    let pubkey: String
    @Environment(NostrManager.self) private var nostrManager

    init(user: NDKUser) {
        self.pubkey = user.pubkey
    }

    init(pubkey: String) {
        self.pubkey = pubkey
    }

    var body: some View {
        NDKUIUsername(pubkey: pubkey)
            .environment(\.ndk, nostrManager.ndk)
    }
}
