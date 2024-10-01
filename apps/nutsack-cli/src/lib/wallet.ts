import NDKWalletService, { NDKCashuWallet, NDKWallet } from "@nostr-dev-kit/ndk-wallet";
import { ndk } from "./ndk";

export let walletService: NDKWalletService;

export async function initWallet() {
    walletService = new NDKWalletService(ndk);

    walletService.on("wallet:default", (wallet: NDKWallet) => {
    });
    
    return new Promise((resolve, reject) => {
        walletService.on("ready", () => {
            resolve(walletService);
        });
        
        walletService.start();
    });
}

export function getWallet(walletId: string): NDKCashuWallet | null {
    for (const wallet of walletService.wallets) {
        if (!(wallet instanceof NDKCashuWallet)) continue;;
        
        if (wallet.event.encode() === walletId) {
            return wallet;
        }
    }
    
    return null;
}