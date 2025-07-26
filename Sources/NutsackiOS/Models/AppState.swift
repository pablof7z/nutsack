import Foundation
import SwiftUI
import NDKSwift

enum ThemeMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
class AppState: ObservableObject {
    private static let conversionUnitKey = "PreferredCurrencyConversionUnit"
    private static let themeKey = "PreferredTheme"
    private static let lastRNackHashKey = "LastReleaseNotesAcknoledgedHash"
    private static let firstLaunchFlag = "HasLaunchedBefore"
    private static let blacklistedMintsKey = "BlacklistedMints"
    
    struct ExchangeRateResponse: Decodable {
        let bitcoin: ExchangeRate
    }
    
    struct ExchangeRate: Decodable, Equatable {
        let usd: Int
        let eur: Int
    }
    
    @Published var preferredConversionUnit: CurrencyUnit {
        didSet {
            UserDefaults.standard.setValue(preferredConversionUnit.rawValue, forKey: AppState.conversionUnitKey)
        }
    }
    
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.setValue(themeMode.rawValue, forKey: AppState.themeKey)
        }
    }
    
    @Published var blacklistedMints: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(blacklistedMints), forKey: AppState.blacklistedMintsKey)
        }
    }
    
    @Published var exchangeRates: ExchangeRate?
    
    static var showOnboarding: Bool {
        get {
            return !UserDefaults.standard.bool(forKey: firstLaunchFlag)
        } set {
            UserDefaults.standard.set(!newValue, forKey: firstLaunchFlag)
        }
    }
    
    init() {
        if let unit = CurrencyUnit(rawValue: UserDefaults.standard.string(forKey: AppState.conversionUnitKey) ?? "") {
            preferredConversionUnit = unit
        } else {
            preferredConversionUnit = .usd
        }
        
        if let theme = ThemeMode(rawValue: UserDefaults.standard.string(forKey: AppState.themeKey) ?? "") {
            themeMode = theme
        } else {
            themeMode = .system
        }
        
        if let savedMints = UserDefaults.standard.array(forKey: AppState.blacklistedMintsKey) as? [String] {
            blacklistedMints = Set(savedMints)
        } else {
            blacklistedMints = []
        }
        
        loadExchangeRates()
    }
    
    func loadExchangeRates() {
        print("Loading exchange rates...")
        
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd,eur") else {
            print("Could not fetch exchange rates from API due to an invalid URL.")
            return
        }
        
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                print("Unable to load conversion data.")
                return
            }
            
            guard let prices = try? JSONCoding.decoder.decode(ExchangeRateResponse.self, from: data).bitcoin else {
                print("Unable to decode exchange rate data from request response.")
                return
            }
            
            await MainActor.run {
                self.exchangeRates = prices
            }
        }
    }
    
    // MARK: - Blacklist Management
    
    func blacklistMint(_ mintURL: String) {
        blacklistedMints.insert(mintURL)
    }
    
    func unblacklistMint(_ mintURL: String) {
        blacklistedMints.remove(mintURL)
    }
    
    func isMintBlacklisted(_ mintURL: String) -> Bool {
        blacklistedMints.contains(mintURL)
    }
}

enum CurrencyUnit: String, CaseIterable {
    case sat
    case usd
    case eur
    case btc
    
    var symbol: String {
        switch self {
        case .sat: return "sats"
        case .usd: return "$"
        case .eur: return "€"
        case .btc: return "₿"
        }
    }
}