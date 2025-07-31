import SwiftUI
import NDKSwift
import NDKSwiftUI

// Lightweight wrappers around NDKSwiftUI components to maintain API compatibility
// while leveraging NDKSwiftUI's proven implementation

struct UserDisplayName: View {
    let pubkey: String
    @EnvironmentObject private var nostrManager: NostrManager

    init(user: NDKUser) {
        self.pubkey = user.pubkey
    }

    init(pubkey: String) {
        self.pubkey = pubkey
    }

    var body: some View {
        NDKUIDisplayName(ndk: nostrManager.ndk, pubkey: pubkey)
    }
}

struct UserProfilePicture: View {
    let pubkey: String
    let size: CGFloat
    @EnvironmentObject private var nostrManager: NostrManager

    init(user: NDKUser, size: CGFloat = 40) {
        self.pubkey = user.pubkey
        self.size = size
    }

    init(pubkey: String, size: CGFloat = 40) {
        self.pubkey = pubkey
        self.size = size
    }

    var body: some View {
        NDKUIProfilePicture(ndk: nostrManager.ndk, pubkey: pubkey, size: size)
    }
}

struct UserNIP05: View {
    let pubkey: String
    @EnvironmentObject private var nostrManager: NostrManager

    init(user: NDKUser) {
        self.pubkey = user.pubkey
    }

    init(pubkey: String) {
        self.pubkey = pubkey
    }

    var body: some View {
        NDKUIUsername(ndk: nostrManager.ndk, pubkey: pubkey)
    }
}
