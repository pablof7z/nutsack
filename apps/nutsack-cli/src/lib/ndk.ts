import NDK, { getRelayListForUser, NDKEvent, NDKNip46Signer, NDKPrivateKeySigner, NDKRelay, NDKSigner } from '@nostr-dev-kit/ndk';
import chalk from 'chalk';
import createDebug from 'debug';
export let ndk: NDK;

export async function initNdk(
    relays: string[],
    payload: string
) {
    let signer: NDKSigner | undefined;
    
    if (payload.startsWith('nsec')) {
        signer = new NDKPrivateKeySigner(payload);
    }

    const relaysProvided = relays.length > 0;

    if (relays.length === 0) {
        relays = ['wss://relay.primal.net', 'wss://relay.damus.io'];
    }
    const netDebug = createDebug("net");

    ndk = new NDK({
        explicitRelayUrls: relays,
        signer: signer,
        autoConnectUserRelays: true,
        netDebug: (msg: string, relay: NDKRelay, direction?: "send" | "recv") => {
            const hostname = chalk.white(new URL(relay.url).hostname);
            if (direction === "send") {
                netDebug(hostname, chalk.green(msg));
            } else if (direction === "recv") {
                netDebug(hostname, chalk.red(msg));
            } else {
                netDebug(hostname, chalk.grey(msg));
            }
        }
    });

    await ndk.connect(5000);

    if (!relaysProvided) {
        getRelayListForUser(ndk.activeUser!.pubkey, ndk)
            .then((relayList) => {
                if (!relayList || relayList.relays.length === 0) {
                    console.log(chalk.red('No relays provided and this pubkey doesn\'t have any relays!'));
                }
            })
    }
}
