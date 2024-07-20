import { writable } from 'svelte/store';
import NDKSvelte from '@nostr-dev-kit/ndk-svelte';
import NDKDexie from '@nostr-dev-kit/ndk-cache-dexie';

export const explicitRelayUrls = [
    'wss://nos.lol/',
    // 'wss://relay.noswhere.com/',
    'wss://relay.primal.net/',
    'wss://relay.damus.io/',
    // "wss://relay.highlighter.com/",
    'wss://relay.nostr.band/',
    'wss://purplepag.es/',
];

const _ndk: NDKSvelte = new NDKSvelte({
    explicitRelayUrls,
    enableOutboxModel: true,
    cacheAdapter: new NDKDexie({
        dbName: "nutlife",
    })
}) as NDKSvelte;

_ndk.pool.blacklistRelayUrls.add("wss://relayer.fiatjaf.com/")
_ndk.pool.blacklistRelayUrls.add("wss://relay.nostr.info/")
_ndk.pool.blacklistRelayUrls.add("wss://nostr-01.bolt.observer/")
_ndk.pool.blacklistRelayUrls.add("wss://profile.nos.social/")

export const ndk = writable(_ndk);
_ndk.connect();