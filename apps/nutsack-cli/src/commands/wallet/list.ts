import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { allWallets } from "../../lib/wallet";
import chalk from "chalk";

export async function listWallets(all: boolean = false) {
    for (const wallet of allWallets) {
        if (wallet instanceof NDKCashuWallet) {
            console.log(chalk.white.bold(wallet.name ?? "Unnamed"));
            
            if (all) {
                console.log(`Type: ${chalk.yellow(wallet.type)}`);
                if (wallet.event) console.log(`Wallet ID: ${chalk.cyan(wallet.event?.encode())}`);
                if (wallet.p2pk) console.log(`P2PK: ${chalk.cyan(wallet.p2pk)}`);
                console.log(`Mints:`);
                for (const mint of wallet.mints) {
                    console.log(`  Mint: ${chalk.cyan(mint)}`);
                }
            }

            const balance = await wallet.balance();
            if (balance) {
                console.log(`  Balance: ${chalk.cyan(`${balance.amount} ${balance.unit}`)}`);
            }
            console.log();
        }
    }
}