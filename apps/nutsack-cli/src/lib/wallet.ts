import { NDKCashuWallet, NDKNutzapMonitor, NDKWallet } from "@nostr-dev-kit/ndk-wallet";
import { ndk } from "./ndk";
import { NDKCashuMintList, NDKEvent, NDKKind, NDKNutzap } from "@nostr-dev-kit/ndk";
import inquirer from "inquirer";

export let activeWallet: NDKCashuWallet | null | undefined = null;
export let allWallets: NDKCashuWallet[] = [];

export const setActiveWallet = (wallet: NDKCashuWallet) => activeWallet = wallet;

export let monitor: NDKNutzapMonitor;

async function askForWallet(mintList: NDKCashuMintList | undefined, walletEvents: NDKCashuWallet[]): Promise<NDKCashuWallet | undefined> {
    const wallets = Array.from(walletEvents.values());
    
    const wallet = await inquirer.prompt([
        {
            type: "list",
            name: "wallet",
            message: "Which wallet do you want to use?",
            choices: allWallets.map(w => `${w.event!.encode()} (${w.name})`)
        }
    ]);

    return wallets.find(w => w.event!.encode() === wallet.wallet);
}

export async function initWallet() {
    const events = await ndk.fetchEvents([
        { kinds: [NDKKind.CashuMintList, NDKKind.CashuWallet], authors: [ndk.activeUser!.pubkey] }
    ]);
    const eventsArray = Array.from(events);

    const list = eventsArray.find(e => e.kind === NDKKind.CashuMintList)
    const mintList = list ? NDKCashuMintList.from(list) : undefined;
    const walletEvents = eventsArray.filter(e => e.kind === NDKKind.CashuWallet);

    allWallets = (await Promise.all(walletEvents.map(NDKCashuWallet.from)))
        .filter(w => !!w) as NDKCashuWallet[];
    allWallets.forEach(w => w.start());

    // ask the user which wallet to use if there's more than one, otherwise set the active wallet as default
    if (walletEvents.length > 1) {
        activeWallet = await askForWallet(mintList, allWallets);
    } else if (walletEvents.length === 1) {
        activeWallet = allWallets[0];
    } else {
        console.error("No wallets found");
    }

    // if (mintList?.p2pk && activeWallet?.p2pk !== mintList.p2pk) {
    //     console.error("Mismatch between mint list and active wallet, we won't be able to redeem nutzaps for this wallet");
    // }

    monitor = new NDKNutzapMonitor(ndk, ndk.activeUser!);

    allWallets.forEach(w => monitor.addWallet(w));
    
    monitor.start();
}

export function getWallet(walletId: string): NDKCashuWallet | null {
    for (const wallet of allWallets) {
        if (!(wallet instanceof NDKCashuWallet)) continue;;
        
        if (wallet.event?.encode() === walletId) {
            return wallet;
        }
    }
    
    return null;
}