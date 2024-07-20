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
	import { wallet } from "$stores/wallet";
	import Separator from "$components/ui/separator/separator.svelte";

    let relayUrls: string = "";
    let mintUrls: string[] = [];
    let exploreMints = false;
    let signer: NDKPrivateKeySigner;

    $ndk.pool.on("relay:connect", (r: NDKRelay) => {
        let d = relayUrls;
        if (d.length > 0) d = d + "\n";
        d = d + r.url;
        relayUrls = d;
    });

    onMount(() => {
        relayUrls = Array.from($ndk.pool.relays.keys()).join("\n")

        if ($wallet) {
            mintUrls = $wallet.mints;
            if ($wallet.relays.length > 10) relayUrls = $wallet.relays.join("\n");
            if ($wallet.privkey) {
                signer = new NDKPrivateKeySigner($wallet.privkey);
                console.log('using existing private key in wallet event', $wallet.privkey);
                signer.user().then(u => {
                    console.log('pubkey of user', u.pubkey);
                });
            }
        }
    })

    let cashuMintList: NDKCashuMintList;
    let cashuWallet: NDKCashuWallet;

    async function create() {
        if (signer) console.log('not creating a new signer')
        signer ??= NDKPrivateKeySigner.generate();

        if (mintUrls.length < 1) {
            return false;
        }

        cashuMintList = new NDKCashuMintList($ndk);
        cashuMintList.relays = relayUrls.split("\n").filter(r => r)
        cashuMintList.mints = mintUrls;

        // if we don't have access to the private key, we need to
        // signal that p2pk need to go to a specific pubkey we control
        const user = await signer.user();
        cashuMintList.p2pkPubkey = user.pubkey;
        
        cashuWallet = $wallet ?? new NDKCashuWallet($ndk);
        cashuWallet.name ??= "My wallet";
        cashuWallet.relays = cashuMintList.relays;
        cashuWallet.mints = cashuMintList.mints;

        console.log(cashuWallet.relays)

        if (signer?.privateKey) {
            cashuWallet.privkey = signer.privateKey;
            console.log('setting private key', cashuWallet.privkey);
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
            <Label for="relays">Mints</Label>
            <div class="text-base text-muted-foreground">These are the mints you are comfortable using.</div>

            {#each mintUrls as mintUrl}
                <div>{mintUrl}</div>
            {/each}
            
            <Explore bind:mintUrls />
          </div>

          <Separator />

          <div class="grid gap-2">
            <Label for="relays">Relays</Label>
            <div class="text-base text-muted-foreground">These are the relays where your ecash will be stored.</div>
            <Textarea id="relays" required bind:value={relayUrls} />
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