import chalk from "chalk";
import { ndk } from "../lib/ndk";
import { NDKEvent, NDKRelaySet } from "@nostr-dev-kit/ndk";
import { walletService } from "../lib/wallet";
import { CashuMint, CashuWallet, Token } from "@cashu/cashu-ts";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import readline from 'readline';

async function announceMyself(relays: string[], fee: number) {
    const event = new NDKEvent(ndk);
    event.kind = 26969;
    event.tags = relays.map(r => ['relay', r]);

    if (fee) {
        event.tags.push(['fee', fee.toString(), "sat"]);
    }
    
    const r= await event.publish();

    console.log(chalk.white('Announced in', r.size, 'relays that I route events in', relays.join(', ')));

    setTimeout(() => {
        announceMyself(relays, fee);
    }, 250000);
}

export async function routeMessages({ onionRelay, fee }: { onionRelay: string[], fee: number }) {
    const relays = onionRelay;
    console.log(chalk.green('Starting condom daemon... Press Enter to stop.'));

    let relaySet: NDKRelaySet | undefined;

    if (relays.length > 0) {
        relaySet = new NDKRelaySet(new Set(), ndk);
        for (const relay of relays) {
            const r = ndk.pool.getRelay(relay);
            relaySet.addRelay(r);
        }
    }

    const myPubkey = ndk.activeUser?.pubkey;
    if (!myPubkey) {
        console.log(chalk.red('No active user found'));
        return;
    }

    const sub = ndk.subscribe({
        kinds: [20690], '#p': [myPubkey], limit: 0
    }, undefined, relaySet);

    sub.on('event', processEvent);

    announceMyself(relays, fee);

    console.log(chalk.green('Listening for messages on', relays.join(', '), 'for', myPubkey));

    // Return a promise that resolves on keypress
    return new Promise<void>((resolve) => {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        rl.on('line', () => {
            console.log(chalk.yellow('Stopping the daemon...'));

            sub.stop();
            
            rl.close();
            resolve();
        });
    });
}

async function processEvent(event: NDKEvent) {
    await event.decrypt(undefined, undefined, 'nip44');

    // console.log(chalk.white("Received an event: ", event.pubkey));
    // console.log(chalk.white("Event content: ", event.content));

    const content = JSON.parse(event.content);
    const relays = content.relays;
    const proof = content.proof;
    const mint = content.mint;
    const unit = content.unit;
    const payload = content.payload;
    console.log({relays})

    console.log(chalk.bgBlue("Received an event: ", event.id, 'will publish to', relays.join(', ')));

    const relaySet = NDKRelaySet.fromRelayUrls(relays, ndk);

    const publishEvent = new NDKEvent(ndk, JSON.parse(payload));

    if (proof) {
        console.log(chalk.green('🥜 We found a nice little nut, worth', proof.amount, 'sat'));

        const wallet = walletService.defaultWallet as NDKCashuWallet;
        if (!wallet) {
            console.log(chalk.red('No wallet found'));
            return;
        }

        const cashuWallet = new CashuWallet(new CashuMint(mint));
        try {
            const proofs = await cashuWallet.receiveTokenEntry({
                proofs: [proof], mint
            });
            await wallet.saveProofs(proofs, mint);
        } catch (e) {
            console.log(chalk.red('Error receiving proofs:', e));
        }
    }

    const r = await publishEvent.publish(relaySet);

    const pTag = publishEvent.tagValue('p');
    
    console.log(chalk.bgMagenta('Published', publishEvent.id,' to ', Array.from(r).map(r => r.url).join(', ')), 'for', pTag);
}
