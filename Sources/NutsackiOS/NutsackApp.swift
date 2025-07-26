import SwiftUI
import SwiftData
import NDKSwift

@main
struct NutsackApp: App {
    @StateObject private var appState = AppState()
    @State private var nostrManager: NostrManager
    @State private var walletManager: WalletManager
    
    // Create a simple in-memory container
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // Initialize logging settings from UserDefaults
        Self.initializeLoggingSettings()
        
        let nm = NostrManager(from: "App")
        let appStateInstance = AppState()
        let wm = WalletManager(
            nostrManager: nm,
            modelContext: modelContainer.mainContext,
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
        .modelContainer(modelContainer)
    }
}

// MARK: - Database Manager
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private(set) var container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([
                Transaction.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema, 
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("Created in-memory ModelContainer")
        } catch {
            print("Could not create ModelContainer: \(error)")
            container = nil
        }
    }
    
    func newContext() -> ModelContext {
        guard let container = container else {
            fatalError("ModelContainer not available")
        }
        return ModelContext(container)
    }
}