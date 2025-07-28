import SwiftUI
import NDKSwift

// MARK: - Debug Logging Settings
struct DebugLoggingView: View {
    @AppStorage("ndkLogLevel") private var logLevel: Int = NDKLogLevel.debug.rawValue
    @AppStorage("ndkLogNetworkTraffic") private var logNetworkTraffic = true
    @AppStorage("ndkPrettyPrintNetworkMessages") private var prettyPrintNetworkMessages = true
    @AppStorage("ndkEnabledCategories") private var enabledCategoriesData: Data = Data()
    
    @State private var enabledCategories: Set<NDKLogCategory> = Set(NDKLogCategory.allCases)
    @State private var hasChanges = false
    
    var body: some View {
        List {
            // Log Level Section
            Section {
                Picker("Log Level", selection: $logLevel) {
                    Text("Off").tag(NDKLogLevel.off.rawValue)
                    Text("Error").tag(NDKLogLevel.error.rawValue)
                    Text("Warning").tag(NDKLogLevel.warning.rawValue)
                    Text("Info").tag(NDKLogLevel.info.rawValue)
                    Text("Debug").tag(NDKLogLevel.debug.rawValue)
                    Text("Trace").tag(NDKLogLevel.trace.rawValue)
                }
                .onChange(of: logLevel) {
                    applyLogLevel()
                    hasChanges = true
                }
            } header: {
                Text("Log Level")
            } footer: {
                Text("Higher levels include all lower levels. Debug and Trace provide the most detail.")
            }
            
            // Network Logging Section
            Section {
                Toggle("Log Network Traffic", isOn: $logNetworkTraffic)
                    .onChange(of: logNetworkTraffic) {
                        Task { @MainActor in
                            NDKLogger.logNetworkTraffic = logNetworkTraffic
                            hasChanges = true
                        }
                    }
                
                Toggle("Pretty Print Messages", isOn: $prettyPrintNetworkMessages)
                    .disabled(!logNetworkTraffic)
                    .onChange(of: prettyPrintNetworkMessages) {
                        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
                        hasChanges = true
                    }
            } header: {
                Text("Network Logging")
            } footer: {
                Text("Network logging shows raw Nostr messages sent and received from relays.")
            }
            
            // Categories Section
            Section {
                ForEach(sortedCategories, id: \.self) { category in
                    Toggle(isOn: Binding(
                        get: { enabledCategories.contains(category) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledCategories.insert(category)
                            } else {
                                enabledCategories.remove(category)
                            }
                            applyCategories()
                            hasChanges = true
                        }
                    )) {
                        HStack {
                            Text(emojiForCategory(category))
                            Text(displayName(for: category))
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Log Categories")
                    Spacer()
                    Button(action: toggleAllCategories) {
                        Text(enabledCategories.count == NDKLogCategory.allCases.count ? "None" : "All")
                            .font(.caption)
                    }
                }
            } footer: {
                Text("Enable or disable logging for specific parts of the system.")
            }
            
            // Quick Presets Section
            Section {
                Button(action: applyProductionPreset) {
                    Label("Production Settings", systemImage: "shippingbox")
                }
                
                Button(action: applyDebugPreset) {
                    Label("Debug Settings", systemImage: "ladybug")
                }
                
                Button(action: applyNetworkDebugPreset) {
                    Label("Network Debug", systemImage: "network")
                }
                
                Button(action: applyWalletDebugPreset) {
                    Label("Wallet Debug", systemImage: "creditcard")
                }
            } header: {
                Text("Quick Presets")
            } footer: {
                Text("Quickly apply common logging configurations.")
            }
            
            // Current Status
            if hasChanges {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings applied and saved")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } footer: {
                    Text("Your logging preferences will persist across app restarts.")
                }
            }
        }
        .navigationTitle("Debug Logging")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private var sortedCategories: [NDKLogCategory] {
        NDKLogCategory.allCases.sorted { displayName(for: $0) < displayName(for: $1) }
    }
    
    private func displayName(for category: NDKLogCategory) -> String {
        switch category {
        case .network: return "Network"
        case .relay: return "Relay"
        case .subscription: return "Subscription"
        case .event: return "Event"
        case .cache: return "Cache"
        case .auth: return "Authentication"
        case .wallet: return "Wallet"
        case .general: return "General"
        case .connection: return "Connection"
        case .outbox: return "Outbox"
        case .signer: return "Signer"
        case .sync: return "Sync"
        case .performance: return "Performance"
        case .security: return "Security"
        case .database: return "Database"
        case .signature: return "Signature"
        }
    }
    
    private func emojiForCategory(_ category: NDKLogCategory) -> String {
        switch category {
        case .network: return "📡"
        case .relay: return "🔗"
        case .subscription: return "🔍"
        case .event: return "📝"
        case .cache: return "💾"
        case .auth: return "🔐"
        case .wallet: return "💰"
        case .general: return "ℹ️"
        case .connection: return "🔌"
        case .outbox: return "🎯"
        case .signer: return "✍️"
        case .sync: return "🔄"
        case .performance: return "⚡"
        case .security: return "🛡️"
        case .database: return "🗄️"
        case .signature: return "✅"
        }
    }
    
    private func loadSettings() {
        // Load log level
        NDKLogger.logLevel = NDKLogLevel(rawValue: logLevel) ?? .debug
        
        // Load network settings
        NDKLogger.logNetworkTraffic = logNetworkTraffic
        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
        
        // Load enabled categories
        if let categories = JSONCoding.safeDecode(Set<String>.self, from: enabledCategoriesData) {
            enabledCategories = Set(categories.compactMap { rawValue in
                NDKLogCategory(rawValue: rawValue)
            })
        } else {
            enabledCategories = Set(NDKLogCategory.allCases)
        }
        
        NDKLogger.enabledCategories = enabledCategories
    }
    
    private func applyLogLevel() {
        NDKLogger.logLevel = NDKLogLevel(rawValue: logLevel) ?? .debug
    }
    
    private func applyCategories() {
        NDKLogger.enabledCategories = enabledCategories
        
        // Save to UserDefaults
        let categoryStrings = enabledCategories.map { $0.rawValue }
        if let data = try? JSONCoding.encode(categoryStrings) {
            enabledCategoriesData = data
        }
    }
    
    private func toggleAllCategories() {
        if enabledCategories.count == NDKLogCategory.allCases.count {
            // Disable all
            enabledCategories.removeAll()
        } else {
            // Enable all
            enabledCategories = Set(NDKLogCategory.allCases)
        }
        applyCategories()
        hasChanges = true
    }
    
    // MARK: - Presets
    
    private func applyProductionPreset() {
        logLevel = NDKLogLevel.warning.rawValue
        logNetworkTraffic = false
        prettyPrintNetworkMessages = false
        enabledCategories = [.general, .security]
        
        applyLogLevel()
        applyCategories()
        NDKLogger.logNetworkTraffic = logNetworkTraffic
        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
        hasChanges = true
    }
    
    private func applyDebugPreset() {
        logLevel = NDKLogLevel.debug.rawValue
        logNetworkTraffic = true
        prettyPrintNetworkMessages = true
        enabledCategories = Set(NDKLogCategory.allCases)
        
        applyLogLevel()
        applyCategories()
        NDKLogger.logNetworkTraffic = logNetworkTraffic
        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
        hasChanges = true
    }
    
    private func applyNetworkDebugPreset() {
        logLevel = NDKLogLevel.trace.rawValue
        logNetworkTraffic = true
        prettyPrintNetworkMessages = true
        enabledCategories = [.network, .relay, .connection, .performance]
        
        applyLogLevel()
        applyCategories()
        NDKLogger.logNetworkTraffic = logNetworkTraffic
        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
        hasChanges = true
    }
    
    private func applyWalletDebugPreset() {
        logLevel = NDKLogLevel.trace.rawValue
        logNetworkTraffic = false
        prettyPrintNetworkMessages = false
        enabledCategories = [.wallet, .event, .cache, .sync]
        
        applyLogLevel()
        applyCategories()
        NDKLogger.logNetworkTraffic = logNetworkTraffic
        NDKLogger.prettyPrintNetworkMessages = prettyPrintNetworkMessages
        hasChanges = true
    }
}

#if DEBUG
struct DebugLoggingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DebugLoggingView()
        }
    }
}
#endif