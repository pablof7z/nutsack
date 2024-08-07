<script lang="ts">
	import type { NDKNutzap } from "@nostr-dev-kit/ndk-wallet";
    import * as Card from "$components/ui/card";
	import Avatar from "$components/User/Avatar.svelte";
	import { ndk } from "$stores/ndk";

    export let nutzap: NDKNutzap;

    let amount = nutzap.amount;
    let unit = nutzap.unit;

    if (unit === "msat") {
        amount = amount / 1000;
        unit = "sats"
    }


</script>

<Card.Root class="bg-secondary w-full">
    <Card.Content class="py-1">
        <div class="flex flex-row w-full items-center justify-evenly">
            <div class="w-1/3">
                <Avatar ndk={$ndk} user={nutzap.author} size="medium" />
            </div>

            <div class="w-1/3 flex flex-col items-center">
                <h1>
                    {amount}
                </h1>
                <div class="text-muted-foreground">{unit}</div>
            </div>
            <div class="w-1/3 flex justify-end">
                <Avatar ndk={$ndk} user={nutzap.recipient} size="medium" />
            </div>
        </div>

        {#if nutzap.comment.length > 0}
            <div class="text-sm text-muted-foreground bg-background border border-border p-2 text-center">
                {nutzap.comment}
            </div>
        {/if}
    </Card.Content>
</Card.Root>