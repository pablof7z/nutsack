# Mint Discovery Improvement Summary

## Problem
The mint discovery in NutsackiOS was blocking and only started after authentication, causing poor UX where users had to wait with a "Discovering mints..." message.

## Solution
Following the NDKSwift philosophy of "never wait, always stream", the implementation was refactored to:

### 1. Start Discovery Immediately
- Mint discovery now begins as soon as the WalletOnboardingView appears
- No longer waits for authentication to complete
- Discovery runs in the background while users complete authentication

### 2. Reactive UI Updates
- Removed blocking "Discovering mints..." view
- Always show the mint list, even when empty
- Mints appear progressively as they're discovered
- Loading indicator is subtle and non-blocking

### 3. Better Empty States
- When no mints are discovered yet, show helpful message
- Users can immediately add custom mints without waiting
- Clear visual feedback about the discovery status

## Key Changes

1. **WalletOnboardingView.swift**:
   - Added `mintDiscoveryTask` to track the background task
   - Changed `startMintDiscovery()` to begin immediately on view appear
   - Made UI always show mint list instead of blocking loading view
   - Added progressive loading indicators within the list

2. **Discovery Flow**:
   ```swift
   // Old: Wait for auth, then discover
   auth → setupMintDiscovery() → block UI → show mints
   
   // New: Discover in parallel with auth
   onAppear → startMintDiscovery() → stream mints progressively
   ```

3. **User Experience**:
   - Users see the mint selection UI immediately
   - Can add custom mints right away
   - Recommended mints appear as they're discovered
   - No blocking states or waiting screens

## Benefits
- Faster perceived performance
- Better follows NDKSwift's reactive principles
- Users can proceed with custom mints without waiting
- More responsive and native-feeling app behavior