import inquirer from "inquirer";
import { ndk } from "../../lib/ndk";
import { NDKEvent, NDKPrivateKeySigner } from "@nostr-dev-kit/ndk";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { allWallets, setActiveWallet } from "../../lib/wallet";

async function fetchMintList() {
    const list = await ndk.fetchEvents({
        kinds: [38172]
    });

    return Array.from(list);
}

export async function createWallet(name?: string, mints?: string[], unit?: string) {
    let walletName = name;
    let selectedMints = mints;
    let walletUnit = unit;

    if (!walletName) {
        // ask user for wallet name
        const { inputWalletName } = await inquirer.prompt([
            {
                type: 'input',
                name: 'inputWalletName',
                message: 'Enter a name for your wallet:',
            },
        ]);
        walletName = inputWalletName;
    }

    if (!selectedMints || selectedMints.length === 0) {
        // Fetch mint list
        const mintList = await fetchMintList();

        // Extract mint URLs from the events
        const mintUrls = mintList
            .map(event => event.tagValue("u"))
            .filter((url): url is string => url !== undefined);
        
        mintUrls.unshift("https://testnut.cashu.space/")
        
        console.log("Available Mint URLs:", mintUrls);

        // Ask user to select multiple mint URLs
        const { userSelectedMints } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'userSelectedMints',
                message: 'Select one or more mint URLs:',
                choices: mintUrls,
                validate: (answer: string[]) => {
                    if (answer.length < 1) {
                        return 'You must choose at least one mint URL.';
                    }
                    return true;
                },
            },
        ]);
        selectedMints = userSelectedMints;
    }

    if (!walletUnit) {
        // ask for unit
        const { inputUnit } = await inquirer.prompt([
            {
                type: 'input',
                name: 'inputUnit',
                message: 'Enter the unit for your wallet:',
                default: "sat",
            },
        ]);
        walletUnit = inputUnit;
    }

    const key = NDKPrivateKeySigner.generate();

    const wallet = new NDKCashuWallet(ndk);
    wallet.name = walletName;
    wallet.mints = selectedMints;
    wallet.relays = ndk.pool.connectedRelays().map(relay => relay.url);
    wallet.unit = walletUnit;
    wallet.privkey = key.privateKey;
    await wallet.getP2pk()
    await wallet.publish();

    setActiveWallet(wallet);
    allWallets.push(wallet);

    console.log("Wallet created:", wallet.event!.encode());

    return wallet;
}
