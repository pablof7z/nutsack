import inquirer from "inquirer";
import { walletService } from "../../lib/wallet";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import qrcode from 'qrcode-terminal';

export async function depositToWallet(mintUrl?: string, amount?: string, unit?: string) {
    const wallets = walletService.wallets;
    let wallet: NDKCashuWallet | undefined;

    // if there is more than one wallet, ask which one to deposit to
    if (wallets.length === 1) {
        wallet = wallets[0] as NDKCashuWallet;
    } else if (wallets.length > 1) {
        const { selection } = await inquirer.prompt([
            {
                type: 'list',
                name: 'selection',
                message: 'Select a wallet to deposit to:',
                choices: wallets
                    .filter(w => w instanceof NDKCashuWallet)
                    .map(w => `${w.name ?? "Unnamed"} (${w.event.encode()})`),
                validate: (input: string) => {
                    if (!input) {
                        return 'You must select a wallet.';
                    }
                    return true;
                },
            },
        ]);

        console.log({selection})

        // find the wallet with the given id
        wallet = wallets.find(w => w instanceof NDKCashuWallet && selection.includes(w.event!.encode())) as NDKCashuWallet | undefined;
    }

    if (!wallet) {
        console.log("No wallet selected.");
        return;
    }

    let mint: string;
    if (mintUrl) {
        // Use provided mint URL if available
        mint = mintUrl;
    } else {
        // Prompt for mint selection if not provided
        const { selectedMint } = await inquirer.prompt([
            {
                type: 'list',
                name: 'selectedMint',
                choices: wallet.mints,
                message: 'Select the mint to deposit to:',
            },
        ]);
        mint = selectedMint;
    }

    if (!amount || !unit) {
        // Prompt for amount and unit if not provided
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'amount',
                message: 'Enter the amount to deposit:',
                when: !amount,
            },
            {
                type: 'input',
                name: 'unit',
                message: 'Enter the unit for the amount:',
                default: wallet.unit,
                when: !unit,
            },
        ]);
        amount = amount || answers.amount;
        unit = unit || answers.unit;
    }

    if (unit === "sats") unit = "sat";

    const deposit = await wallet.deposit(amount!, mint, unit!);
    const pr = await deposit.start();

    console.log(`Payment Request from ${mint}:`);
    console.log(`\x1b[1;37m${pr}\x1b[0m`);

    // Generate and display QR code
    qrcode.generate(pr, { small: true }, (qrcode) => {
        console.log(qrcode);
    });

    await new Promise(resolve => {
        deposit.on("success", (token) => {
            console.log(`Deposit successful: ${token.id}`);
            resolve(token);
        });

        deposit.on("error", (error) => {
            console.error(`Deposit failed: ${error}`);
            resolve(error);
        });
    })
}