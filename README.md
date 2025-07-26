# Nutsack - Modern Cashu Wallet for iOS

<div align="center">
  <img src="Resources/nutsack-icon.png" alt="Nutsack Logo" width="200"/>
  
  [![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
  [![NDKSwift](https://img.shields.io/badge/NDKSwift-0.2.0-blue)](https://github.com/pablof7z/NDKSwift)
  [![CashuSwift](https://img.shields.io/badge/CashuSwift-latest-green)](https://github.com/zeugmaster/CashuSwift)
  [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
</div>

## Overview

Nutsack is a modern [Cashu](https://cashu.space) ecash wallet for iOS that integrates seamlessly with [Nostr](https://nostr.com), implementing [NIP-60](https://github.com/nostr-protocol/nips/blob/master/60.md) (wallet data) and [NIP-61](https://github.com/nostr-protocol/nips/blob/master/61.md) (nutzaps). It provides a beautiful, native iOS experience for managing ecash with full backup and social payment capabilities.

## Features

### 🏦 Core Wallet Features
- **Multi-Mint Support**: Connect to multiple Cashu mints for improved reliability
- **Lightning Integration**: Mint ecash from Lightning invoices and melt back to Lightning
- **Send & Receive**: Share ecash tokens via QR codes, text, or Nostr
- **Real-time Balance**: Live balance updates with fiat conversion (USD, EUR, BTC)
- **Transaction History**: Comprehensive tracking of all ecash movements
- **Proof Management**: View, select, and manage individual ecash proofs
- **DLEQ Verification**: Automatic verification of mint signatures for enhanced security

### ⚡ Nostr Integration
- **Nostr Authentication**: Login with nsec or create new Nostr account
- **NIP-60 Backup**: Automatic wallet backup to Nostr relays
- **NIP-61 Nutzaps**: Zap other Nostr users with ecash
- **Contact Integration**: See your Nostr follows and zap them easily
- **Multi-Relay Support**: Connect to multiple Nostr relays with health monitoring
- **Mint Discovery**: Find new mints through NIP-38000 announcements

### 🎨 UI/UX Features
- **Beautiful Dark Theme**: Elegant design with glassmorphic effects
- **Native iOS Feel**: Built with SwiftUI for smooth, native performance
- **QR Code Scanner**: Scan ecash tokens, Lightning invoices, and mint URLs
- **Intuitive Navigation**: Tab-based interface with clear actions
- **Real-time Updates**: Live balance updates and transaction notifications
- **Pie Chart Visualization**: Visual breakdown of balance across mints
- **Smooth Animations**: Delightful animations for payments and interactions

### 🔒 Security Features
- **Biometric Lock**: Protect your wallet with Face ID/Touch ID
- **Encrypted Storage**: Local key storage with encryption
- **Mint Blacklisting**: Block untrusted mints
- **Token Validation**: Automatic validation of received tokens
- **Relay Health Monitoring**: Track relay connection status

## Architecture

The app is built using modern iOS technologies:

- **SwiftUI** for the declarative UI layer
- **SwiftData** for local persistence
- **NDKSwift** for Nostr protocol integration
- **CashuSwift** for Cashu protocol operations
- **Combine** for reactive programming

### Key Components

1. **WalletManager**: Core wallet operations and state management
2. **NostrManager**: Handles all Nostr operations including authentication and event publishing
3. **MintDiscoveryManager**: Discovers and manages Cashu mints
4. **WalletDataSources**: Reactive data sources for UI updates
5. **AppState**: Global app state and user preferences

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/pablof7z/Nutsack.git
cd Nutsack
```

2. Install XcodeGen if you haven't already:
```bash
brew install xcodegen
```

3. Generate the Xcode project:
```bash
./refresh-project.sh
```

4. Open the project in Xcode:
```bash
open NutsackiOS.xcodeproj
```

5. Build and run the project on your device or simulator

### TestFlight

Coming soon! We'll be releasing Nutsack on TestFlight for beta testing.

## Development

### Building

```bash
# Refresh project after file changes
./refresh-project.sh

# Build with clean output
./build.sh

# Build for specific device
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro" ./build.sh
```

### Testing

The project includes comprehensive Maestro UI tests:

```bash
# Run all tests
maestro test maestro-tests/

# Run specific test
maestro test maestro-tests/01-onboarding.yaml
```

### Deploying to TestFlight

```bash
./deploy.sh
```

## Configuration

### Default Mints

The app comes pre-configured with trusted mints. Users can add their own mints via:
- Scanning mint QR codes
- Entering mint URLs manually
- Discovering mints through Nostr

### Relay Configuration

Default relays are configured for optimal performance. Users can customize relays in Settings.

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

The app includes comprehensive test coverage:

- Unit tests for wallet operations
- UI tests using Maestro
- Integration tests for Nostr functionality

Run tests with:
```bash
swift test
```

## Security

- Private keys are encrypted and stored locally
- All Nostr communications use standard encryption
- Ecash tokens are validated before acceptance
- Mint trust is explicit and user-controlled
- Regular security audits are performed

## Roadmap

- [ ] Multi-language support
- [ ] Backup/restore from seed phrase
- [ ] Push notifications for received payments
- [ ] Widget support for balance display
- [ ] WalletConnect integration
- [ ] Hardware wallet support
- [ ] Tor support for enhanced privacy

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [NDKSwift](https://github.com/pablof7z/NDKSwift)
- Uses [CashuSwift](https://github.com/zeugmaster/CashuSwift) for Cashu operations
- Implements [Nostr Protocol](https://nostr.com) NIPs
- UI inspired by macademia wallet

## Contact

- Nostr: `npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft`
- GitHub: [@pablof7z](https://github.com/pablof7z)

---

<div align="center">
  Made with 🥜 for the ecash future
</div>