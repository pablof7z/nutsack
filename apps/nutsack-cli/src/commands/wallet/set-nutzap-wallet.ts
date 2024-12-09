import { NDKCashuMintList } from "@nostr-dev-kit/ndk";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { ndk } from "../../lib/ndk";
import { monitor } from "../../lib/wallet";

export async function setNutzapWallet(walletId: string) {
    const walletEvent = await ndk.fetchEvent(walletId);
    if (!walletEvent) {
        console.error("Wallet not found");
        return;
    }
    const wallet = await NDKCashuWallet.from(walletEvent);
    if (!wallet) {
        console.error("Wallet invalid", walletEvent.rawEvent());
        return;
    }
    
    const mintList = new NDKCashuMintList(ndk);
    mintList.mints = wallet.mints;
    mintList.relays = wallet.relays;
    if (wallet.p2pk) mintList.p2pk = wallet.p2pk;
    await mintList.publishReplaceable();

    // start the monitor
    monitor.start(mintList);

    console.log("Nutzap wallet set: https://njump.me/" + mintList.encode());
}