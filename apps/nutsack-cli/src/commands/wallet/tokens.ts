import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';
import chalk from 'chalk';
import { allWallets } from '../../lib/wallet';

export async function listTokens(verbose: boolean = false) {
    for (const wallet of allWallets) {
        if (!(wallet instanceof NDKCashuWallet)) continue;

        // print wallet in chalk white
        console.log(chalk.white(wallet.name));
        for (const token of wallet.tokens) {
            const { amount, mint, proofs } = token;
            console.log(
                "  " +
                chalk.green(amount),
                chalk.gray(`(${mint})`) +
                chalk.yellow(` (${proofs.length} proofs)`)
            );

            if (verbose) {
                for (const proof of proofs) {
                    console.log(
                        chalk.gray(`    ${proof.secret}`),
                        chalk.white(`    (${proof.amount})`)
                    )
                }
            }
        }
    }
}
