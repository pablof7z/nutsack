import NDK, { NDKUser } from "@nostr-dev-kit/ndk";
import NDKWallet, { type MintUrl, NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { derived, writable } from "svelte/store";
import createDebug from "debug";

const d = createDebug("nutsack:ndk-wallet");

export const walletService = writable(new NDKWallet(new NDK()));
export const wallet = writable<NDKCashuWallet|null>(null);

export const walletsBalance = writable(new Map<string, number>());
export const walletBalance = derived([wallet, walletsBalance], ([$wallet, $walletsBalance]) => {
    if (!$wallet) return 0;
    return $walletsBalance.get($wallet.walletId) || 0;
});
export const walletMintBalance = writable(new Map<string, Record<MintUrl, number>>());

export const wallets = writable<NDKCashuWallet[]>([]);

export function walletInit(
    ndk: NDK,
    user: NDKUser
) {
    const w = new NDKWallet(ndk);
    w.on("wallet", () => { wallets.set(w.wallets); });
    w.on("wallet:default", (w: NDKCashuWallet) => { wallet.set(w); });
    w.on("wallet:balance", (w: NDKCashuWallet) => {
        walletsBalance.update((b) => {
            b.set(w.walletId, w.balance || 0);
            // d("setting balance of wallet %s to %d", w.walletId, w.balance);
            return b;
        });

        walletMintBalance.update((b) => {
            b.set(w.walletId, w.mintBalances);
            // d("setting mint balance of wallet %s to %o", w.walletId, w.mintBalances);
            return b;
        });
    });
    w.start(user);
    
    d("fetching user wallets");
    walletService.set(w);
}