import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';
import { ndk } from '../../lib/ndk';
import { getWallet, walletService } from '../../lib/wallet';
import { NDKUser } from '@nostr-dev-kit/ndk';
import chalk from 'chalk';

export async function pay(payload: string, walletId?: string) {
  try {
    // Validate the payload
    if (!isValidPayload(payload)) {
      throw new Error('Invalid payload. Please provide a valid BOLT11 invoice or NIP-05 identifier.');
    }

    // Select the correct wallet (if walletId is provided)
    const selectedWallet = walletId ? getWallet(walletId) : walletService.defaultWallet;
    if (!selectedWallet || !(selectedWallet instanceof NDKCashuWallet)) {
      throw new Error('Wallet not found.');
    }

    if (isBolt11(payload)) {
      await handleBolt11Payment(selectedWallet, payload);
    } else {
      await handleNip05Payment(selectedWallet, payload);
    }
  } catch (error) {
    console.error('Error making payment:', error.message);
  }
}

function isValidPayload(payload: string): boolean {
  // Implement validation logic for BOLT11 and NIP-05
  return isBolt11(payload) || isNip05(payload);
}

function isBolt11(payload: string): boolean {
  // Implement BOLT11 validation logic
  return payload.toLowerCase().startsWith('lnbc');
}

function isNip05(payload: string): boolean {
  // Implement NIP-05 validation logic
  return payload.includes('@');
}

async function handleBolt11Payment(wallet: NDKCashuWallet, bolt11: string) {
    const res = await wallet.lnPay({ pr: bolt11 })
    console.log(res);
}

async function handleNip05Payment(wallet: NDKCashuWallet, nip05: string) {
    const user = await  NDKUser.fromNip05(nip05, ndk);
    if (!user) {
        console.log(
            chalk.red("User not found")
        );
        return;
    }

    const zap = await ndk.zap(user, 1, { comment: "zap from nutsack-cli", unit: "sats"});
    const res = await zap.zap()
    console.log(res);
}

async function promptForAmountAndUnit() {
  // Implement prompt for amount and unit
  // You can use inquirer or any other method to get user input
  return { amount: '0', unit: 'sats' }; // Replace with actual implementation
}