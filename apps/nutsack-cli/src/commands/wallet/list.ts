import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { walletService } from "../../lib/wallet";

export async function listWallets(all: boolean = false) {
    const wallets = walletService.wallets;

    for (const wallet of wallets) {
        if (wallet instanceof NDKCashuWallet) {
            // Bright cyan color for the wallet name
            console.log(`Wallet: \x1b[96m${wallet.name ?? "Unnamed"}\x1b[0m`);
            
            if (all) {
                console.log(`Type: \x1b[93m${wallet.type}\x1b[0m`);
                console.log(`Wallet ID: \x1b[96m${wallet.event.encode()}\x1b[0m`);
                // mints
                console.log(`Mints:`);
                for (const mint of wallet.mints) {
                    console.log(`  Mint: \x1b[96m${mint}\x1b[0m`);
                }
            }

            const balance = await wallet.balance();
            if (balance) {
                for (const b of balance) {
                    console.log(`  Balance: \x1b[96m${b.amount} ${b.unit}\x1b[0m`);
                }
            }
            console.log(); // Add an empty line between wallet entries
        }
    }
}