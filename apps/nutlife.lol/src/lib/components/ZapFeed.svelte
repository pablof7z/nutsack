<script lang="ts">
    import Zap from '$lib/components/Zap.svelte';
	import type { NDKEvent } from '@nostr-dev-kit/ndk';
	import type { NDKEventStore } from '@nostr-dev-kit/ndk-svelte';
	import { derived } from 'svelte/store';

    export let initialDisplayCount = 50;
    export let cutoffTimeDuration = 1; // 1 hour
    export let nutzaps: NDKEventStore<NDKEvent>;

    // this is done to prevent loading a bunch of zaps before we
    // finished loading, so as to initially respect the limit of n
    // zaps, and disregard it as they continue to come in
    // setTimeout(() => { initialLoad = false; }, 1500);

    let processedZapLength = 0;

    const sortedZaps = derived(nutzaps, $nutzaps => {
        return $nutzaps.sort((a, b) => {
            return b.created_at! - a.created_at!;
        });
    });
</script>

{#each $sortedZaps as zap (zap.id)}
    <Zap {zap} />
{/each}