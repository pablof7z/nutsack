<script lang="ts">
    import NavBar from '$lib/components/NavBar.svelte';

    import RadioButton from '$lib/components/RadioButton.svelte';

    import Hero from '$lib/components/Hero.svelte';
    import ZapFeed from '$lib/components/ZapFeed.svelte';
	import { getContext } from 'svelte';
	import type { NDKEvent } from '@nostr-dev-kit/ndk';
	import type { NDKEventStore } from '@nostr-dev-kit/ndk-svelte';

    let mode = 'zap-feed';
    let sortMode = 'amount';

    const mainSub = getContext('mainSub') as NDKEventStore<NDKEvent>;

    function changeMode(newMode) {
        mode = newMode;
    }

    function changeSortMode(newSortMode) {
        sortMode = newSortMode;
    }
</script>

<svelte:head>
    <title>NUTLIFE.LOL</title>
</svelte:head>

<NavBar />

<Hero />

<!-- <div class="overflow-auto w-full flex flex-row justify-start sm:justify-center px-2">
    <div class="flex flex-row items-center justify-center text-regular sm:text-lg font-bold mb-5 whitespace-nowrap w-fit">
        <RadioButton pos="left" bind:activeValue={mode} value="zap-feed" text="zaps" />
    </div>
</div> -->


<div class="my-4 w-full rounded">
    <ZapFeed nutzaps={mainSub} />
</div>