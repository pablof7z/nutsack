<script lang="ts">
    import Avatar from '$lib/components/Avatar.svelte';
    import { formatSatoshis } from '$lib/utils';
	import { ndk } from '$stores/ndk';
	import type { NDKEvent } from '@nostr-dev-kit/ndk';
	import { Name } from '@nostr-dev-kit/ndk-svelte-components';
    import { createEventDispatcher } from 'svelte';
    import Time from "svelte-time";
    const dispatch = createEventDispatcher();

    export let zap: NDKEvent;
    export let opened = false;

    let amount = parseInt(zap.tagValue("amount")??"0");
    let unit = zap.tagValue("unit") ?? zap.getMatchingTags("amount")[0]?.[2] ?? "msat";
    const recipientPubkey = zap.tagValue("p");
    const recipient = recipientPubkey ? $ndk.getUser({pubkey: recipientPubkey}) : null;
    const sender = zap.author;
    const comment = zap.tagValue("comment");

 
    if (unit.startsWith('msat')) {
        unit = 'sats';
        amount = amount / 1000;
    }
    
    let zappedNote;

    function open() {
        // $nostrPool.reqEvent(zap.zappedNoteId, 0)
        dispatch('open', opened ? null : zap.id);
    }

    function zapContent(content) {
        // if it's an URL that ends with an image format
        if (content.match(/(http(s?):)([/|.|\w|\s|-])*\.(?:jpg|jpeg|gif|png)/g)) {
            return `<img src="${content}" class="max-h-64" />`
            // else if url is youtube
        } else if (content.match(/(http(s?):)([/|.|\w|\s|-])*\.(?:youtube)/g)) {
            return `<iframe width="560" height="315" src="${content}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`
            // else if url is vimeo
        } else if (content.match(/(http(s?):)([/|.|\w|\s|-])*\.(?:vimeo)/g)) {
            return `<iframe src="${content}" width="640" height="360" frameborder="0" allow="autoplay; fullscreen; picture-in-picture" allowfullscreen></iframe>`
            // else if url is mp4
        } else if (content.match(/(http(s?):)([/|.|\w|\s|-])*\.(?:mov)/g)) {
            return `<video controls class="max-h-64">
                <source src="${content}" type="video/mp4">
                Your browser does not support the video tag.`
        } else {
            return content;
        }
    }
</script>

{#if recipientPubkey}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div class="
        flex flex-col py-1  w-full
        hover:bg-purple-50 dark:hover:bg-purple-1000
        {opened ? 'bg-purple-100 dark:bg-purple-900 border border-purple-900' : 'bg-white dark:bg-gray-900'}
        cursor-pointer md:mb-4 md:rounded md:shadow border-b-gray-300 dark:border-b-gray-800 border-b amax-h-24
        items-center
        justify-between
        text-gray-600 dark:text-gray-200
        px-4
    " on:click={open}>
        <div class="flex flex-row gap-1 w-full py-4">
            <div class="w-1/3 flex flex-row items-center gap-2">
                <Avatar klass="flex-none m-2 w-16 h-16 ring-8 ring-purple-1000" pubkey={sender.pubkey} />
                <div class="
                    font-bold text-xl text-clip hidden sm:block truncate text-right
                ">
                    <Name ndk={$ndk} user={sender} />
                </div>
            </div>

            <div class="w-1/3 flex flex-col items-center">
                <div class="text-5xl font-black text-center justify-center flex flex-row items-center">
                    ⚡️
                    <span class="flex flex-col items-center">
                        <span class="text-purple-900 dark:text-purple-500">
                            {#if unit.startsWith("msat")}
                                {formatSatoshis(amount, { tryGrouping: true, justNumber: true })}
                            {:else }
                                {amount}
                            {/if}
                        </span>
                        <span class="text-lg text-gray-600 dark:text-gray-300 font-black uppercase">
                            {unit}
                        </span>
                    </span>
                </div>

                <div class="text-xs text-gray-500 dark:text-gray-300 mt-1">
                    <Time relative={true} live={true} timestamp={zap.created_at*1000} />
                </div>
            </div>

            <div class="w-1/3 flex flex-row gap-2 justify-end items-center">
                <a class="
                    font-bold text-xl text-clip hidden sm:block truncate text-right
                    hover:border-b hover:border-b-white
                " href="#" on:click|stopPropagation={()=>{}}>
                    <Name ndk={$ndk} pubkey={recipientPubkey} />
                </a>
                <Avatar klass="flex-none m-2 w-16 h-16 ring-8 ring-purple-1000" pubkey={recipientPubkey} />
            </div>
        </div>

        {#if comment}
            <div class="
                border border-purple-500 dark:border-purple-900
                bg-purple-100 dark:bg-slate-800
                text-black dark:text-white
                p-3
                w-full
                text-center
                rounded-lg
                items-center
                justify-center
                truncate
                flex flex-row
                m-3
            ">{#if zapContent(comment)}{@html zapContent(comment)}{/if}</div>
        {/if}
    </div>
{/if}