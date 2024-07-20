import { ndk } from "$stores/ndk";
import { user } from "$stores/user";
import type { NDKSigner } from "@nostr-dev-kit/ndk";
import NDKWallet from "@nostr-dev-kit/ndk-wallet";
import { get } from "svelte/store";

export function setSigner(signer: NDKSigner) {
    const $ndk = get(ndk);
    
    try {
        $ndk.signer = signer;
        $ndk.signer.user().then((u) => {
            user.set(u)
        });
    } catch {}
}