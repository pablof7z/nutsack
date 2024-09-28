import NDKWalletService, { NDKWallet } from "@nostr-dev-kit/ndk-wallet";
import { ndk } from "./ndk";

export let walletService: NDKWalletService;

export async function initWallet() {
    walletService = new NDKWalletService(ndk);

    walletService.on("wallet:default", (wallet: NDKWallet) => {
        console.log("Found a wallet", wallet.type, wallet.name);
    });
    
    return new Promise((resolve, reject) => {
        walletService.on("ready", () => {
            console.log("Wallet service ready");
            resolve(walletService);
        });
        
        walletService.start();
    });
}
