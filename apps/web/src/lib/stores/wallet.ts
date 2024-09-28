import NDK, { NDKUser } from "@nostr-dev-kit/ndk";
import NDKWalletService, { type MintUrl, NDKCashuWallet, type NDKWallet } from "@nostr-dev-kit/ndk-wallet";
import { derived, get, writable } from "svelte/store";
import createDebug from "debug";

const d = createDebug("nutsack:ndk-wallet");

export const walletService = writable<NDKWalletService>(undefined);
export const wallet = writable<NDKWallet|null>(null);

export const walletsBalance = writable(new Map<string, number>());
export const walletBalance = derived([wallet, walletsBalance], ([$wallet, $walletsBalance]) => {
    if (!$wallet) return 0;
    return $walletsBalance.get($wallet.walletId) || 0;
});
export const walletMintBalance = writable(new Map<string, Record<MintUrl, number>>());

export const wallets = writable<NDKWallet[]>([]);

export function walletInit(
    ndk: NDK,
    user: NDKUser
) {
    const w = new NDKWalletService(ndk);
    walletService.set(w);
    const $walletService = get(walletService);
    ndk.walletConfig = {
        onCashuPay: $walletService.onCashuPay.bind($walletService),
        onLnPay: $walletService.onLnPay.bind($walletService),
    };
    $walletService.on("wallet", () => { wallets.set($walletService.wallets); });
    $walletService.on("wallet:default", (w: NDKWallet) => {
        wallet.set(w);
    });
    // w.on("wallet:balance", (w: NDKCashuWallet) => {
    //     walletsBalance.update((b) => {
    //         b.set(w.walletId, w.balance || 0);
    //         d("setting balance of wallet %s to %d", w.walletId, w.balance);
    //         return b;
    //     });

    //     walletMintBalance.update((b) => {
    //         b.set(w.walletId, w.mintBalances);
    //         d("setting mint balance of wallet %s to %o", w.walletId, w.mintBalances);
    //         return b;
    //     });
    // });
    d("fetching user wallets");
    $walletService.start(user);
}