import NDKSvelte from "@nostr-dev-kit/ndk-svelte";
import NDKDexieCache from "@nostr-dev-kit/ndk-cache-dexie";
import { writable } from "svelte/store";

const _ndk = new NDKSvelte({
    explicitRelayUrls: [
        "wss://relay.primal.net",
        "wss://relay.damus.io",
        "wss://relay.f7z.io",
    ],
    cacheAdapter: new NDKDexieCache({ dbName: 'nutsack' })
});
_ndk.connect();

export const ndk = writable(_ndk);