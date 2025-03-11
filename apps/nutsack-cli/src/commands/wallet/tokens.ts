import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';
import chalk from 'chalk';
import { allWallets } from '../../lib/wallet';

export async function listTokens(verbose: boolean = false) {
    for (const wallet of allWallets) {
        if (!(wallet instanceof NDKCashuWallet)) continue;

        // print wallet in chalk white
        console.log(chalk.white(wallet.name));

        const tokens = {};

        for (const proof of wallet.state.proofs.values()) {
            const tokenId = proof.tokenId ?? "no token id";
            let existing = tokens[tokenId] || [];
            existing.push(proof);
            tokens[tokenId] = existing;
        }

        for (const tokenId in tokens) {
            const proofs = tokens[tokenId];
            console.log(chalk.white(`${tokenId}`));
            for (const proof of proofs) {   
                const { state, mint} = proof;
                const { amount, C } = proof.proof;
                console.log(
                    "  " +
                    chalk.green(amount),
                    chalk.gray(`(${mint})`),
                    chalk.gray(`${C.substring(0, 6)}`),
                    state === 'deleted' ? chalk.red(`(${state})`) : chalk.gray(`(${state})`)
                );
            }
        }
    }
}
