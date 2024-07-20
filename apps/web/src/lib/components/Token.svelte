<script lang="ts">
	import type { NDKCashuToken } from "@nostr-dev-kit/ndk-wallet";
	import Button from "./ui/button/button.svelte";
	import { wallet } from "$stores/wallet";
	import Badge from "./ui/badge/badge.svelte";
	import { toast } from "svelte-sonner";

    export let token: NDKCashuToken;

    let expanded = false;

    async function republish() {
        const res = await token.publish($wallet!.relaySet)
        toast("Published to " + res.size + " relays")
    }
</script>

<div class="flex flex-col border-b border-border py-4 gap-2">
    <span>
        {token.amount}
            {$wallet.unit}
            in {token.proofs.length} unspent proofs
    </span>

    <div class="flex flex-row items-center gap-4">
        <Badge variant="primary" class="w-fit">
            {token.onRelays.length} relays
        </Badge>

        <Badge variant="primary" class="w-fit">
            {token.id.slice(0, 8)}
        </Badge>

        <Button variant="secondary" on:click={republish} size="sm">
            Republish
        </Button>
        <Button variant="secondary" on:click={() => expanded = !expanded} size="sm">
            {expanded ? "Hide" : "Show"} proofs
        </Button>
    </div>


    {#if expanded}
        <pre>{JSON.stringify(token.proofs, null, 4)}</pre>
    {/if}
</div>