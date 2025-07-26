# NutsackiOS Maestro Tests

This directory contains Maestro tests for the NutsackiOS app authentication flows.

## Prerequisites

1. Install Maestro CLI: https://maestro.mobile.dev/getting-started/installing-maestro
2. Have an iOS Simulator running with the NutsackiOS app installed

## Running Tests

To run all tests:
```bash
maestro test maestro/
```

To run a specific test:
```bash
maestro test maestro/test_account_creation.yaml
```

## Test Descriptions

### test_account_creation.yaml
Tests the complete account creation flow:
- Opens the app
- Creates a new account with display name and about text
- Verifies the backup key screen appears
- Confirms navigation to the main wallet interface

### test_login_flow.yaml
Tests logging in with an existing nsec:
- Opens the app
- Navigates to import account screen
- Enters an nsec private key
- Verifies successful login to the main interface

### test_auth_persistence.yaml
Tests that authentication persists after login (addresses the issue where users were being returned to the login screen):
- Creates a new account
- Verifies the user stays in the main app
- Tests navigation between tabs
- Ensures the authentication screen doesn't reappear

## Debugging Failed Tests

If tests fail, you can run them with debug output:
```bash
maestro test --debug maestro/test_auth_persistence.yaml
```

You can also use Maestro Studio for interactive debugging:
```bash
maestro studio
```

## Test Private Keys

The test uses a dummy nsec for testing login:
- `nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5`

**Warning**: This is a test key only. Never use real private keys in tests.