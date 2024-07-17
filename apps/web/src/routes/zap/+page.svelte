<script lang="ts">
	import Avatar from "$components/User/Avatar.svelte";
import { ndk } from "$stores/ndk";
	import { NDKKind } from "@nostr-dev-kit/ndk";
	import { derived } from "svelte/store";

    const cashuMintList = $ndk.storeSubscribe(
        { kinds: [NDKKind.CashuMintList ]}
    )
    const usersWithLists = derived(cashuMintList, $sub => {
        return $sub.map(s => s.pubkey);
    })
</script>

<div class="flex flex-col w-full items-start gap-2">
    {#each $usersWithLists as pubkey (pubkey)}
        <a href="/send?pubkey={pubkey}">
            <Avatar {pubkey} size="medium" />
        </a>
    {/each}
</div>
