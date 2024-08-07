<script lang="ts">
    import Avatar from "$components/User/Avatar.svelte";
    import { EventContent, Name } from "@nostr-dev-kit/ndk-svelte-components";
    import * as Card from "$components/ui/card";
	import { Button } from "$components/ui/button";
	import { NDKKind, type NDKEvent } from "@nostr-dev-kit/ndk";
	import { ndk } from "$stores/ndk";

    export let note: NDKEvent;

    const events = $ndk.storeSubscribe({
        kinds: [9321, NDKKind.Zap], ...note.filter()
    });

    let zapping = false;
    let error: string | undefined;
    
    async function zap() {
        zapping = true;
        const zapper = await $ndk.zap(note, 1000, "Nutzapped!", { unit: "msat" });
        const ret = await zapper.zap();
        for (const val of Array.from(ret.values())) {
            if (val instanceof Error) {
                error = val.message;
            }
            console.log(val);
        }

        zapping = false;
    }
</script>

<Card.Root class="bg-secondary w-full">
    <Card.Header class="flex flex-row">
        <div class="flex flex-row gap-2">
            <Avatar user={note.author} size="small" />
            <Name user={note.author} size="small" />
        </div>
    </Card.Header>

    <Card.Content>
        <EventContent event={note} ndk={$ndk} class="text-sm" />
    </Card.Content>

    <Card.Footer>
        {#each $events as e (e.id)}
            {e.content}
        {/each}
        
        <Button size="sm" disabled={zapping} class="w-full" on:click={zap}>
            {#if !error}
                🌰⚡️
                Nutzap
            {:else}
                {error}
            {/if}
        </Button>
    </Card.Footer>
</Card.Root>