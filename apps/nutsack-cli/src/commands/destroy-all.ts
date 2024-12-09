import { NDKEvent, NDKKind, NostrEvent } from "@nostr-dev-kit/ndk";
import { activeWallet } from "../lib/wallet";
import { ndk } from "../lib/ndk";

export async function destroyAllProofs() {
    if (!activeWallet) {
        console.error("No active wallet");
        return;
    }
    
    const deleteEvent = new NDKEvent(ndk, {
        kind: 5,
        tags: [["k", NDKKind.CashuToken.toString()]]
    } as NostrEvent);

    activeWallet.tokens.forEach(async (token) => {
        deleteEvent.tags.push(["e", token.id]);
    });

    await deleteEvent.publish(activeWallet?.relaySet);
}