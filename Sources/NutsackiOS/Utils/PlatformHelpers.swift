import SwiftUI

// MARK: - Platform-specific clipboard operations
extension String {
    func copyToPasteboard() {
        #if os(iOS)
        UIPasteboard.general.string = self
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self, forType: .string)
        #endif
    }
}

// MARK: - Platform-specific view modifiers
struct PlatformNavigationBarTitleDisplayMode: ViewModifier {
    let mode: Any?

    init(inline: Bool = true) {
        #if os(iOS)
        self.mode = inline ? NavigationBarItem.TitleDisplayMode.inline : NavigationBarItem.TitleDisplayMode.large
        #else
        self.mode = nil
        #endif
    }

    func body(content: Content) -> some View {
        #if os(iOS)
        if let displayMode = mode as? NavigationBarItem.TitleDisplayMode {
            content.navigationBarTitleDisplayMode(displayMode)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

extension View {
    func platformNavigationBarTitleDisplayMode(inline: Bool = true) -> some View {
        self.modifier(PlatformNavigationBarTitleDisplayMode(inline: inline))
    }
}
