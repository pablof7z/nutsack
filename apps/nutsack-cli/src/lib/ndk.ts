import NDK, { NDKPrivateKeySigner } from '@nostr-dev-kit/ndk';

export let ndk: NDK;

export async function initNdk(
    relays: string[],
    nsec: string
) {
    const signer = new NDKPrivateKeySigner(nsec);
    ndk = new NDK({
        explicitRelayUrls: relays,
        signer,
    });
    await ndk.connect(5000);
}