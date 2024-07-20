<script>
    import { selectedDuration, totalsPerRecipient, totalsPerSender, totalsPerZapper } from '$lib/store';
    import UserRankingCard from '$lib/components/UserRankingCard.svelte';
    import { getSinceTime } from '$lib/nostr/utils';

    export let sortMode;
    
    let sortedRecipientIds = {};
    let sortedSenderIds = {};
    let sortedZapperIds = {};
    let zapsSince;
    let nostrichesLoadCount = 100;


    $: {
        const since = getSinceTime($selectedDuration)
        if ($totalsPerRecipient !== undefined || $totalsPerSender !== undefined) {
            zapsSince = since === 'all' ? 0 : since;

            if (sortMode === 'count') {
                sortedRecipientIds = Object.keys($totalsPerRecipient).sort((a, b) => {
                    return $totalsPerRecipient[b].count - $totalsPerRecipient[a].count;
                });

                sortedSenderIds = Object.keys($totalsPerSender).sort((a, b) => {
                    return $totalsPerSender[b].count - $totalsPerSender[a].count;
                });
            } else if (sortMode === 'amount') {
                sortedZapperIds = Object.keys($totalsPerZapper).sort((a, b) => {
                    return $totalsPerZapper[b].amount - $totalsPerZapper[a].amount;
                });

                sortedRecipientIds = Object.keys($totalsPerRecipient).sort((a, b) => {
                    return $totalsPerRecipient[b].amount - $totalsPerRecipient[a].amount;
                });

                sortedSenderIds = Object.keys($totalsPerSender).sort((a, b) => {
                    return $totalsPerSender[b].amount - $totalsPerSender[a].amount;
                });
            }
        } else {
            sortedRecipientIds = [];
            sortedSenderIds = [];
        }
    }

    // setInterval(() => {
    //     console.table('sender', sortedSenderIds.slice(0, 50))
    //     console.table('zapper', sortedZapperIds.slice(0, 50))
    // }, 10000);
</script>

<!-- {sortedSenderIds.length} people zapped
{sortedRecipientIds.length} people got zapped -->

<div class="flex flex-col gap-2">
    <div class="grid grid-cols-1 sm:grid-cols-2 w-full gap-8">
        <div>
            <div class="
                text-2xl font-bold
                text-gray-700 dark:text-gray-400
                mb-2
            ">Top Zapped</div>
            <div class="text-lg text-gray-700 dark:text-gray-500 mb-2">
                Users who have received the most zaps
            </div>
        </div>

        <div>
            <div class="
                text-2xl font-bold
                text-gray-700 dark:text-gray-400
                mb-2
            ">Top Zappers</div>
            <div class="text-lg text-gray-700 dark:text-gray-500 mb-2">
                Users who have sent the most zaps
            </div>
        </div>

        {#each sortedRecipientIds.slice(0, nostrichesLoadCount) as userId, i}
            {#if sortedSenderIds[i] && $totalsPerSender[sortedSenderIds[i]]}
                <div>
                    {#if sortedRecipientIds[i]}
                        <UserRankingCard {zapsSince} userId={sortedRecipientIds[i]} totals={$totalsPerRecipient[sortedRecipientIds[i]]} />
                    {/if}
                </div>

                <div>
                    <UserRankingCard {zapsSince} userId={sortedSenderIds[i]} totals={$totalsPerSender[sortedSenderIds[i]]} />
                </div>
            {/if}
        {/each}

    </div>

    <div class="flex flex-row justify-center mt-5">
        <button class="
            bg-purple-700 font-mono text-white p-4
            rounded-sm
            w-1/3
        " on:click={()=>{nostrichesLoadCount += 10}}>
            Load more
        </button>
    </div>
</div>