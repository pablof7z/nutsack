import { CashuMint } from "@cashu/cashu-ts";
import type { MintUrl } from "@nostr-dev-kit/ndk-wallet";
import { writable } from "svelte/store";

export const mintUnits = writable<Record<MintUrl, string[]>>({});

export async function fetchMintUnits(mintUrl: MintUrl) {
    const mint = new CashuMint(mintUrl);
    const info = await mint.getInfo();
    console.log("info", info);
    const units: string[] = [];

    info.nuts[4].methods.forEach((m) => {
        if (m.unit) units.push(m.unit);
        else if (Array.isArray(m)) units.push(m[1]);
    });

    console.log("units", units);

    mintUnits.update((u) => {
        u[mintUrl] = units;
        return u;
    });
}