<script lang="ts">
	import { NDKNutzap } from '@nostr-dev-kit/ndk';
	import Avatar from "$components/User/Avatar.svelte";
import { ndk } from "$stores/ndk";
	import { NDKKind, NDKSubscriptionCacheUsage } from "@nostr-dev-kit/ndk";
	
	import { derived } from "svelte/store";
	import Note from "./Note.svelte";
	import Nutzap from "./Nutzap.svelte";

    const nutzaps = $ndk.storeSubscribe([
        { kinds: [NDKKind.Nutzap] }
    ], { groupable: false, groupableDelay: 1000, cacheUsage: NDKSubscriptionCacheUsage.ONLY_RELAY }, NDKNutzap)

    const sortedNutzaps = derived(nutzaps, ($nutzaps) => 
        $nutzaps.slice().sort((a, b) => b.created_at! - a.created_at!)
    );

    const cashuMintList = $ndk.storeSubscribe(
        { kinds: [NDKKind.CashuMintList ]}
    )
    const usersWithLists = derived(cashuMintList, $sub => {
        return $sub.map(s => s.pubkey);
    })

    const notes = $ndk.storeSubscribe({
        kinds: [1], "#t": ["nutzap", "nutzaps", "nutsack"]
    })

    const sortedNotes = derived(notes, ($notes) => 
        $notes.slice().sort((a, b) => b.created_at! - a.created_at!)
    );
</script>

<div class="flex flex-row flex-nowrap w-full gap-2 overflow-x-auto min-h-12">
    {#each $usersWithLists as pubkey (pubkey)}
        <a href="/send?pubkey={pubkey}">
            <Avatar {pubkey} size="medium" />
        </a>
    {/each}
</div>

<div class="flex flex-col w-full items-start gap-2">
    {#each $sortedNutzaps.slice(0, 5) as nutzap (nutzap.id)}
        <Nutzap {nutzap} />
    {/each}
</div>

<div class="flex flex-col w-full items-start gap-2">
    {#each $sortedNotes.slice(0, 10) as note (note.id)}
        <Note {note} />
    {/each}
</div>
