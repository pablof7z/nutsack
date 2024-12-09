import NDKSvelte from "@nostr-dev-kit/ndk-svelte";
import NDKDexieCache from "@nostr-dev-kit/ndk-cache-dexie";
import { writable } from "svelte/store";

const _ndk = new NDKSvelte({
    explicitRelayUrls: [
        "wss://relay.primal.net",
        "wss://relay.damus.io",
    ],
    enableOutboxModel: true,
    cacheAdapter: new NDKDexieCache({ dbName: 'nutsack' }),
    clientName: "nutsack",
});

export const ndk = writable(_ndk);