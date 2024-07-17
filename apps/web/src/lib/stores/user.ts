import { NDKPrivateKeySigner, NDKUser } from "@nostr-dev-kit/ndk";
import NDKWallet, { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { writable } from "svelte/store";
import { variableStore } from 'svelte-capacitor-store';

export const _user: NDKUser | undefined | null = null;

export const user = writable<NDKUser | null>(_user);

export const wallet = writable<NDKWallet | undefined>(undefined);
export const activeWallet = writable<NDKCashuWallet | undefined>(undefined);

export const loginMethod = variableStore<string | null>({
    storeName: 'nutsuck.login-method',
    initialValue: null,
    persist: true,
    browserStorage: 'localStorage'
});

export const userPubkey = variableStore<string | null>({
    storeName: 'nutsuck.pubkey',
    initialValue: null,
    persist: true,
    browserStorage: 'localStorage',
    validationStatement: (value) => {
        if (!value) return true;
        try {
            const user = new NDKUser({pubkey: value});
            return !!user.npub;
        } catch {
            return false;
        }
    }
});

export const privateKey = variableStore<string | undefined>({
    storeName: 'nutsuck.pk',
    initialValue: undefined,
    persist: true,
    browserStorage: 'localStorage',
    validationStatement: (value) => {
        if (!value) return true;
        try {
            const pk = new NDKPrivateKeySigner(value);
            return true;
        } catch {
            return false;
        }
    }
});
