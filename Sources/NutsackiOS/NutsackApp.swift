import SwiftUI
import NDKSwift

@main
struct NutsackApp: App {
    @StateObject private var appState = AppState()
    @State private var nostrManager: NostrManager
    @State private var walletManager: WalletManager

    init() {
        // Initialize logging settings from UserDefaults
        Self.initializeLoggingSettings()

        let nm = NostrManager(from: "App")
        let appStateInstance = AppState()
        let wm = WalletManager(
            nostrManager: nm,
            appState: appStateInstance
        )

        _nostrManager = State(initialValue: nm)
        _walletManager = State(initialValue: wm)
        _appState = StateObject(wrappedValue: appStateInstance)
    }

    private static func initializeLoggingSettings() {
        let defaults = UserDefaults.standard

        // Load log level
        let savedLogLevel = defaults.integer(forKey: "ndkLogLevel")
        if savedLogLevel > 0 {
            NDKLogger.logLevel = NDKLogLevel(rawValue: savedLogLevel) ?? .debug
        }

        // Load network logging settings
        if defaults.object(forKey: "ndkLogNetworkTraffic") != nil {
            NDKLogger.logNetworkTraffic = defaults.bool(forKey: "ndkLogNetworkTraffic")
        }

        if defaults.object(forKey: "ndkPrettyPrintNetworkMessages") != nil {
            NDKLogger.prettyPrintNetworkMessages = defaults.bool(forKey: "ndkPrettyPrintNetworkMessages")
        }

        // Load enabled categories
        if let categoriesData = defaults.data(forKey: "ndkEnabledCategories"),
           let categoryStrings = JSONCoding.safeDecode(Set<String>.self, from: categoriesData) {
            let categories = Set(categoryStrings.compactMap { NDKLogCategory(rawValue: $0) })
            NDKLogger.enabledCategories = categories
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(nostrManager)
                .environment(walletManager)
                .preferredColorScheme(appState.themeMode.colorScheme)
        }
    }
}
