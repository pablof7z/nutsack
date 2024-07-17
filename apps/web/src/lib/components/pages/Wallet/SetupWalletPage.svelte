<script lang="ts">
    import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
    import { Button } from "$lib/components/ui/button/index.js";
    import { Textarea } from "$lib/components/ui/textarea/index.js";
    import { Label } from "$lib/components/ui/label/index.js";
    import { onMount } from "svelte";
    import { ndk } from "$stores/ndk";
    import { NDKCashuMintList, NDKPrivateKeySigner, NDKRelay, type NostrEvent } from "@nostr-dev-kit/ndk";
    import Explore from "$components/Mints/Explore.svelte";
	import { goto } from "$app/navigation";
	import { activeWallet } from "$stores/user";

    let relayUrls: string = "";
    let mintUrls: string[] = [];
    let exploreMints = false;
    let signer: NDKPrivateKeySigner;

    $ndk.pool.on("relay:connect", (r: NDKRelay) => {
        let d = relayUrls;
        console.log("adding relay", {url: r.url, prev: d});
        if (d.length > 0) d = d + "\n";
        d = d + r.url;
        relayUrls = d;
        console.log('result relay', d);
    });

    onMount(() => {
        console.log('pool', $ndk.pool.relays)
        relayUrls = Array.from($ndk.pool.relays.keys()).join("\n")

        if ($activeWallet) {
            mintUrls = $activeWallet.mints;
            if ($activeWallet.relays.length > 10) relayUrls = $activeWallet.relays.join("\n");
            console.log($activeWallet);
            if ($activeWallet.privkey) {
                signer = new NDKPrivateKeySigner($activeWallet.privkey);
            }
        }
    })

    let cashuMintList: NDKCashuMintList;
    let cashuWallet: NDKCashuWallet;

    async function create() {
        signer = NDKPrivateKeySigner.generate();

        if (mintUrls.length < 1) {
            return false;
        }

        cashuMintList = new NDKCashuMintList($ndk);
        cashuMintList.relays = relayUrls.split("\n").filter(r => r)
        cashuMintList.mints = mintUrls;

        // if we don't have access to the private key, we need to
        // signal that p2pk need to go to a specific pubkey we control
        if (!($ndk.signer instanceof NDKPrivateKeySigner) && !signer) {
            signer = NDKPrivateKeySigner.generate();
            const user = await signer.user();
            cashuMintList.p2pkPubkey = user.pubkey;
        }
        
        cashuWallet = $activeWallet ?? new NDKCashuWallet($ndk);
        cashuWallet.name ??= "My wallet";
        cashuWallet.relays = cashuMintList.relays;
        cashuWallet.mints = cashuMintList.mints;

        console.log(cashuWallet.relays)

        if (signer?.privateKey) {
            cashuWallet.privkey = signer.privateKey;
        }
        
        console.log("cashuMintList", cashuMintList.rawEvent());
        console.log("cashuWallet", cashuWallet.rawEvent());
        
        return true;
    }


    async function save() {
        if (await create()) {
            await Promise.all([
                cashuMintList.publishReplaceable(),
                cashuWallet.publishReplaceable(),
            ]);
            goto("/");
        }
    }
</script>

<div class="flex flex-row justify-between items-center">
    <h1>Wallet Setup</h1>
    <Button type="submit" class="" on:click={save}>Next</Button>
</div>


<div class="flex flex-col gap-6">
    <div class="grid grid-cols-1 gap-10">
          <div class="grid gap-2">
            <Label for="relays">Relays</Label>
            <Textarea id="relays" required bind:value={relayUrls} />
            <div class="text-base text-muted-foreground">These are the relays where your balance is going to be stored.</div>
          </div>

          <div class="grid gap-2">
            <Label for="relays">Mints</Label>

            {#each mintUrls as mintUrl}
                <div>{mintUrl}</div>
            {/each}
            
            <div class="text-base text-muted-foreground">These are the mints you are comfortable using.</div>
            
            <Explore bind:mintUrls />
          </div>
        </div>
        

        <!-- <hr>
        
        <h3 class="font-bold">Cashu mint list event</h3>
        <ScrollArea orientation="both">
            <pre class="bg-secondary text-secondary-foreground p-4">{JSON.stringify(cashuMintList?.rawEvent(), null, 4)}</pre>
        </ScrollArea>

        <h3 class="font-bold">Cashu wallet event</h3>
        <ScrollArea orientation="both">
            <pre class="bg-secondary text-secondary-foreground p-4">{JSON.stringify(cashuWallet?.rawEvent(), null, 4)}</pre>
        </ScrollArea> -->
</div>