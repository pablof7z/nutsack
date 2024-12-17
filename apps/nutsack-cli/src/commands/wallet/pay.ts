import { ndk } from '../../lib/ndk';
import { NDKEvent, NDKUser, NDKZapper } from '@nostr-dev-kit/ndk';
import chalk from 'chalk';
import { activeWallet } from '../../lib/wallet';

export async function pay(payload: string, amount?: number) {
  try {
    // Validate the payload
    if (!isValidPayload(payload)) {
      throw new Error('Invalid payload. Please provide a valid BOLT11 invoice or NIP-05 identifier.');
    }

    console.log("Payload", payload);

    if (isBolt11(payload)) {
      await handleBolt11Payment(payload);
    } else if (isNip05(payload)) {
      await handleNip05Payment(payload, amount);
    } else if (isNpub(payload)) {
      await handleNpubPayment(payload, amount);
    } else if (isNevent(payload)) {
      console.log("Nevent", payload);
      await handleNeventPayment(payload, amount);
    }
  } catch (error) {
    console.error('Error making payment:', error.message);
  }
}

function isNevent(payload: string): boolean {
  return payload.startsWith('nevent');
}

function isValidPayload(payload: string): boolean {
  // Implement validation logic for BOLT11 and NIP-05
  return isBolt11(payload) || isNip05(payload) || isNpub(payload) || isNevent(payload)
}

function isBolt11(payload: string): boolean {
  // Implement BOLT11 validation logic
  return payload.toLowerCase().startsWith('lnbc');
}

function isNip05(payload: string): boolean {
  // Implement NIP-05 validation logic
  return payload.includes('@');
}

function isNpub(payload: string): boolean {
  return payload.startsWith('npub1');
}

async function handleBolt11Payment(bolt11: string) {
    if (!activeWallet) {
      console.log(chalk.red("No active wallet found"));
      return;
    }
    const res = await activeWallet.lnPay({ pr: bolt11 })
    console.log(res);
}

async function handleNip05Payment(nip05: string, amount: number) {
    const user = await  NDKUser.fromNip05(nip05, ndk);
    if (!user) {
        console.log(
            chalk.red("User not found")
        );
        return;
    }

    return payUser(user, amount);
}

async function handleNpubPayment(npub: string, amount: number) {
  const user = ndk.getUser({npub});
  return payUser(user, amount);
}

async function handleNeventPayment(nevent: string, amount: number) {
  if (!activeWallet) {
    console.log(chalk.red("No active wallet found"));
    return;
  }
  
  const event = await ndk.fetchEvent(nevent);

  if (!event) {
    console.log(chalk.red("Event not found"));
    return;
  }
  
  console.log(event.content)
  
  const zapper = new NDKZapper(event, amount * 1000, 'msat', {
    comment: "zap from nutsack-cli",
    lnPay: activeWallet.lnPay.bind(activeWallet),
    cashuPay: activeWallet.cashuPay.bind(activeWallet),
  });
  zapper.on("complete", (results) => {
    console.log("Zap complete", results);
  });
  zapper.on("error", (error) => {
    console.log("Zap error", error);
  });
  const res = await zapper.zap()
  console.log("Zap results", res);
}

async function payUser(user: NDKUser, amount: number) {
  if (!activeWallet) {
    console.log(chalk.red("No active wallet found"));
    return;
  }
  const zapper = new NDKZapper(user, amount * 1000, 'msat', {
    comment: "zap from nutsack-cli",
    lnPay: activeWallet.lnPay.bind(activeWallet),
    cashuPay: activeWallet.cashuPay.bind(activeWallet),
  });
  const res = await zapper.zap()
  res.forEach(r => {
    if (r instanceof NDKEvent) {
      console.log(r.encode());
    } else {
      console.log(r);
    }
  });
  
  return res;
}
