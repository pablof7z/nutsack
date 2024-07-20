<script>
    import { formatSatoshis } from '$lib/utils';
    import Avatar from '$lib/components/Avatar.svelte';
    import { nostrPool, profiles } from '$lib/store';
    import { nip19 } from 'nostr-tools';

    export let userId;
    export let totals;
    export let zapsSince;

    let npub;

    try {
      npub = nip19.npubEncode(userId)
    } catch (e) {
      npub = userId
    }


    // onMount(() => {
      $nostrPool.delayedSubscribe([
        {kinds: [9735], '#p': [userId], since: zapsSince},
      ], 'user-zaps', 250)
      // });
</script>

<div class="flex flex-col
  bg-white dark:bg-gray-900
    items-center
    text-black dark:text-gray-200
    justify-center
    rounded-lg shadow
    px-4 py-6
    overflow-hidden
    h-full
">
          <div class="flex items-center justify-center mb-3">
            <Avatar pubkey={userId} klass="h-24 w-24" />
          </div>

          <div class="flex flex-col ml-4 w-full items-center text-ellipsis overflow-clip">
            <a class="text-lg font-bold" href={`nostr:${npub}`}>
              {$profiles[userId]?.display_name || $profiles[userId]?.name || $profiles[userId]?.displayName || `[${userId.slice(0, 6)}]`}
            </a>
            <div class="text-sm opacity-80">
              {$profiles[userId]?.nip05 ? $profiles[userId].nip05.replace(/^_@/, '') : ""}
            </div>
          </div>

          <div class="grid grid-cols-2 justify-between w-full mt-5 gap-4">
            <div class="flex flex-col items-center bg-slate-50 dark:bg-slate-600 py-2 rounded-lg text-gray-500 dark:text-gray-100">
              <div class="text-2xl font-black text-black dark:text-white">
                {totals.count}
              </div>
              <div class="text-sm opacity-80">
                zaps
              </div>
            </div>

            <div class="flex flex-col items-center bg-slate-50 dark:bg-slate-600 py-2 rounded-lg text-gray-500 dark:text-gray-100">
              <div class="text-2xl font-black text-black dark:text-white">
                {formatSatoshis(totals.amount, {tryGrouping: true, justNumber: true})}
              </div>
              <div class="text-sm opacity-80">
                {formatSatoshis(totals.amount, {tryGrouping: true, justUnit: true})}
              </div>
            </div>
          </div>
</div>