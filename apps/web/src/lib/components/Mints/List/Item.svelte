<script lang="ts">
	import { Button } from "$components/ui/button";
	import Checkbox from "$components/ui/checkbox/checkbox.svelte";
	import ScrollArea from "$components/ui/scroll-area/scroll-area.svelte";
	import Avatar from "$components/User/Avatar.svelte";
	import { ndk } from "$stores/ndk";
    import { CashuMint } from "@cashu/cashu-ts";
	import { NDKUser } from "@nostr-dev-kit/ndk";
	import { EventCard } from "@nostr-dev-kit/ndk-svelte-components";
	import { derived } from "svelte/store";

    export let url: string;
    export let checked: boolean = false;

    const recom = $ndk.storeSubscribe([
        { kinds: [38000], "#u": [url] }
    ])

    const recomPubkeys = derived(recom, ($recom) => {
        return Array.from(new Set($recom.map(r => r.pubkey)));
    })

    const recomsWithContent = derived(recom, ($recom) => {
        return $recom.filter(r => r.content.length > 6);
    })

    export let showRecommendations = false;
    
    let info: any;
    let user: NDKUser;
    try {
        const mint = new CashuMint(url)
    mint.getInfo().then((res) => {
        if (!res) return;
        info = res;
        const nostr = info.contact?.find((c: any) => c[0] === 'nostr');
        if (nostr) {
            try {
                const u = $ndk.getUser({npub: nostr[1]});
                u.pubkey
                user = u;
            } catch { }
        }
    }).catch(() => {});
} catch {}
</script>

{#if info}
<button on:click={() => checked = !checked} class="flex flex-row items-center justify-between w-full p-2 pr-4">
    <div class="flex flex-col gap-2 text-left truncate">
        {#if info}
            {#if user}
                <Avatar {user}>
                    <span class="text-xs">{url}</span>
                </Avatar>
            {:else}
                <h3 class="font-bold text-foreground">{info.name}</h3>
            {/if}
            <div class="text-xs text-muted-foreground truncate w-full">
                {info.description}
            </div>
        {:else}
            {url}
        {/if}

        {#if $recomPubkeys.length > 0}
            <div class="flex flex-row items-center gap-2">
                <div class="flex flex-row -space-x-2">
                    {#each $recomPubkeys.slice(0, 4) as pubkey}
                        <Avatar {pubkey} size="tiny" />
                    {/each}
                    {#if $recomPubkeys.length > 4}
                        <div class="bg-secondary rounded-full flex items-center justify-center w-6 h-6 text-xs text-foreground">
                            +{$recomPubkeys.length - 4}
                        </div>
                    {/if}
                </div>
                <span class="text-xs text-muted-foreground">
                    recommendations
                </span>
            </div>
        {/if}
    </div>

    <Checkbox bind:checked />
</button>


    {#if $recomsWithContent.length > 0 && showRecommendations}
        <ScrollArea orientation="horizontal" class="w-full">
            <div class="w-max flex flex-row gap-4 text-left">
                {#each $recomsWithContent as r}
                    <div class="bg-secondary m-2 w-md overflow-x-clip text-sm rounded-md max-w-[260px]">
                        <EventCard ndk={$ndk} event={r} />
                    </div>
                {/each}
            </div>
        </ScrollArea>
    {/if}
{/if}