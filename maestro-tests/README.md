# Nutsack Wallet Maestro Test Suite

This directory contains comprehensive Maestro UI tests for the Nutsack wallet app, covering all major wallet operations and features.

## Prerequisites

1. Install Maestro: `brew install maestro`
2. Have iOS Simulator running with Nutsack app installed
3. Configure Maestro for iOS testing if needed

## Test Files

### Core Wallet Operations

1. **01-onboarding.yaml** - New user account creation and wallet setup
2. **02-minting.yaml** - Adding funds via Lightning (minting ecash)
3. **03-melting.yaml** - Withdrawing funds via Lightning (melting ecash)
4. **04-cashu-send.yaml** - Creating and sending Cashu tokens
5. **05-cashu-receive.yaml** - Receiving and redeeming Cashu tokens

### Advanced Features

6. **06-nutzap.yaml** - Zapping on Nostr using Cashu tokens
7. **07-mint-management.yaml** - Adding and managing multiple mints
8. **08-backup-restore.yaml** - Wallet backup and recovery flows
9. **09-transactions-history.yaml** - Viewing and filtering transaction history
10. **10-proof-management.yaml** - DLEQ verification and proof optimization

### Utility Tests

- **basic-wallet-operations.yaml** - Quick smoke test of basic features
- **create-account.yaml** - Simple account creation test

## Running Tests

### Run Individual Test
```bash
maestro test 01-onboarding.yaml
```

### Run All Tests
```bash
maestro test .
```

### Run with Reporting
```bash
maestro test --format junit --output results.xml .
```

### Interactive Mode
```bash
maestro studio
```

## Test Coverage

The test suite covers:

- ✅ Account creation and import
- ✅ Lightning integration (mint/melt)
- ✅ Cashu token operations
- ✅ Nostr integration (Nutzaps)
- ✅ Multi-mint support
- ✅ Backup and restore (including NIP-60)
- ✅ Transaction history
- ✅ Proof management and DLEQ verification
- ✅ QR code scanning and generation
- ✅ Error handling and edge cases

## Notes

- Tests assume a clean app state. Use `clearState` command if needed
- Some tests require external services (Lightning nodes, mints) to be available
- Timeouts may need adjustment based on network conditions
- Screenshots are captured at key points for documentation

## Troubleshooting

If Maestro has issues connecting to the iOS Simulator:

1. Ensure Xcode command line tools are installed
2. Try `maestro doctor` to diagnose issues
3. Make sure the app bundle ID matches: `com.nutsack.wallet`
4. Check that the simulator is booted and unlocked

## Contributing

When adding new tests:
1. Follow the naming convention: `XX-feature-name.yaml`
2. Include clear comments explaining the test flow
3. Use optional selectors where UI might vary
4. Add appropriate wait times for animations
5. Capture screenshots for important states