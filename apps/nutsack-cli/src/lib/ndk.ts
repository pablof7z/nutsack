import NDK, { getRelayListForUser, NDKPrivateKeySigner } from '@nostr-dev-kit/ndk';
import chalk from 'chalk';
export let ndk: NDK;

export async function initNdk(
    relays: string[],
    nsec: string
) {
    const signer = new NDKPrivateKeySigner(nsec);
    const user = await signer.user();
    const relaysProvided = relays.length > 0;

    if (relays.length === 0) {
        relays = ['wss://relay.damus.io', 'wss://relay.primal.net'];
    }
    
    ndk = new NDK({
        explicitRelayUrls: relays,
        signer,
        autoConnectUserRelays: true,
    });

    await ndk.connect(5000);

    if (!relaysProvided) {
        getRelayListForUser(user.pubkey, ndk)
            .then((relayList) => {
                if (!relayList || relayList.relays.length === 0) {
                    console.log(chalk.red('No relays provided and this pubkey doesn\'t have any relays!'));
                }
            })
    }
}
