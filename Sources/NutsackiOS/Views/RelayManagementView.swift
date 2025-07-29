import SwiftUI
import NDKSwift
import NDKSwiftUI

struct RelayManagementView: View {
    @EnvironmentObject var nostrManager: NostrManager

    var body: some View {
        NDKUIRelayManagementWrapper()
            .environment(\.ndk, nostrManager.ndk)
    }
}
