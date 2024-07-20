<script lang="ts">
    import { fade } from 'svelte/transition';
    import { formatSatoshis } from '$lib/utils';
	import { getContext, onMount } from 'svelte';
	import { derived } from 'svelte/store';
	import type { NDKEventStore } from '@nostr-dev-kit/ndk-svelte';
	import type { NDKEvent } from '@nostr-dev-kit/ndk';

    let durationInHours;
    let durationInHoursFormatted;
    let showTimeframes = false;
    let since;
    let hasSeenEvents;
    let showAllTimeWarning = false;

    export let extraFilters = {};

    const mainSub = getContext('mainSub') as NDKEventStore<NDKEvent>;

    const totalSats = derived(mainSub, $mainSub => {
        return $mainSub.reduce((acc, zap) => {
            const amountString = zap.tagValue("amount");
            if (amountString) {
                return acc + parseInt(amountString) / 1000;
            } else {
                return acc;
            }
        }, 0)
    })

    function toggleTimeframes() {
        showTimeframes = !showTimeframes;
    }

    async function onTimeframeChange() {
        if (durationInHours === 'all') {
            showAllTimeWarning = true;
            setTimeout(() => {
                showAllTimeWarning = false;
            }, 5000);
        }

        // $selectedDuration = durationInHours;

        // $nostrPool.unsubscribeAll();
        // await $nostrPool.reset();

        setDuration();
        toggleTimeframes();

        // setTimeout(() => {
        //     console.log('subscribing to main filter', durationInHours, extraFilters);
        //     subscribeMainFilter($nostrPool, durationInHours, extraFilters);
        // }, 100);
    }

    function setDuration() {
        if (durationInHours !== 'all') {
            since = Math.floor(Date.now() / 1000) - durationInHours * 60 * 60;
            durationInHoursFormatted = timeAgo.format(new Date(since * 1000));
            durationInHoursFormatted = durationInHoursFormatted.replace(/ ago/, '')
        } else {
            since = null;
        }
    }

    $: hasSeenEvents = $mainSub.length > 0
</script>

{#if hasSeenEvents}
    <div class="flex flex-col items-stretch justify-center my-10" style="min-height: 35vh;">
        <span class="
            text-7xl
            text-purple-600
            font-black
            text-center
            my-10
        ">
            <span class="hidden lg:inline-block">⚡️</span>
            {formatSatoshis(parseInt($totalSats))}
        </span>
        <span class="
            text-3xl
            text-gray-700 dark:text-gray-300
            font-black
            text-center
            mb-3
        ">nutzapped</span>
    </div>
{:else}
    <div class="flex flex-col items-stretch justify-center my-10" style="min-height: 35vh;">
        <span class="
            text-7xl
            text-purple-700
            font-black
            text-center
            my-10
        ">
            👋 HOWDY!
        </span>
        <span class="
            text-3xl
            text-gray-700 dark:text-gray-300
            font-black
            text-center
            mb-3
        ">connecting you to relays, one sec</span>
    </div>
{/if}
<!-- 
{#if showTimeframes}
    <div class="mb-32 text-lg" style="">
        <div class="flex flex-col lg:flex-row">
            <TimeframesSelector
                hour={durationInHours}
                bind:hours={durationInHours}
                click={onTimeframeChange}
            />
        </div>
    </div>
{/if} -->