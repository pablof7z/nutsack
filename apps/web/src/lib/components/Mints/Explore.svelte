<script lang="ts">
	import Button from "$components/ui/button/button.svelte";
    import * as Sheet from "$lib/components/ui/sheet";
import ScrollArea from "$components/ui/scroll-area/scroll-area.svelte";
    import { ndk } from "$stores/ndk";
	import { CashuMint } from "@cashu/cashu-ts";
	import { type Hexpubkey, NDKEvent } from "@nostr-dev-kit/ndk";
	import { createEventDispatcher } from "svelte";
	import { derived } from "svelte/store";
    import CashuMintListItem from "./List/Item.svelte";
    import * as Dialog from "$lib/components/ui/dialog";

    export let mintUrls: string[] = [];

    const dispatch = createEventDispatcher();

    const mintRecommendations = $ndk.storeSubscribe({
        kinds: [18173, 37375]//, authors: Array.from($userFollows)
    }, { closeOnEose: true})

    const mints = $ndk.storeSubscribe({
        kinds: [38172]
    })

    const recommendationsPerMint = derived(mintRecommendations, ($mintRecommendations) => {
        const mintRecCount = new Map<string, Set<Hexpubkey>>();

        for (const rec of $mintRecommendations) {
            let mint = rec.tagValue("u");
            mint ??= rec.tagValue("m");
            if (!mint) continue;

            const mintSet = mintRecCount.get(mint) || new Set<Hexpubkey>();
            mintSet.add(rec.pubkey);
            mintRecCount.set(mint, mintSet);
        }

        return mintRecCount;
    })

    const sortedMints = derived([mints, mintRecommendations], ([$mints, $mintRecommendations]) => {
        const mintRecCount = new Map<string, number>();

        for (const rec of $mintRecommendations) {
            const mint = rec.tagValue("u");
            if (!mint) continue;
            mintRecCount.set(mint, (mintRecCount.get(mint) || 0) + 1);
        }

        return $mints.sort((a, b) => {
            const aUrl = a.tagValue("u");
            const bUrl = b.tagValue("u");
            if (!aUrl || !bUrl) return 0;
            const aCount = mintRecCount.get(aUrl) || 0;
            const bCount = mintRecCount.get(bUrl) || 0;
            return bCount - aCount;
        });
    })

    function click(mint: NDKEvent) {
        const url = mint.tagValue("u");
        if (!url) return;
        dispatch("click", { url, mint })
    }

    function submit() {
        mintUrls = Object.keys(selectedMints).filter(k => selectedMints[k]);
        open = false;
    }

    const mint = new CashuMint("https://mint.agorist.space")
    mint.getInfo().then(console.log)

    let selectedMints: Record<string, boolean> = {};
    let open = false;
    let showRecommendations = false;
</script>

<Dialog.Root bind:open>
    <Dialog.Trigger>
        <Button variant="secondary" class="w-full">Explore mints</Button>        
    </Dialog.Trigger>
    <Dialog.Content class="!flex flex-col items-stretch justify-stretch">
        <Dialog.Header>
        <Dialog.Title>Mints</Dialog.Title>
            <div class="h-[50vh] w-full flex border flex-col overflow-y-auto overflow-x-clip">
                <div class="h-max divide-y divide-border w-full flex flex-col items-stretch justify-stretch">
                    {#each $sortedMints as mint (mint.id)}
                        {#if mint.tagValue("u")}
                            <CashuMintListItem {showRecommendations} url={mint.tagValue("u")} bind:checked={selectedMints[mint.tagValue("u")]}/>
                        {/if}
                    {/each}
                </div>
            </div>
        </Dialog.Header>
        <Dialog.Footer>
            <div class="flex flex-row gap-2">
                <Button variant="secondary" on:click={() => showRecommendations = true} class="w-full">List Recommendations</Button>
                <Button type="submit" on:click={submit} class="w-full">Select</Button>
            </div>
        </Dialog.Footer>
    </Dialog.Content>
</Dialog.Root>
