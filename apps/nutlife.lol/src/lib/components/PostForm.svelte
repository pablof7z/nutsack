<script>
    import PostTypeSelector from './PostTypeSelector.svelte';
	import { nostrPool, nostrNotes } from '$lib/store';
    import { onMount } from 'svelte';
	import { validateEvent } from 'nostr-tools';
    import { createEventDispatcher } from 'svelte';

    const dispatch = createEventDispatcher();
    
    let ownPubkey = 'loading';
    let publishEventId;

    onMount(async () => {
        try {
            ownPubkey = await $nostrPool.fetchOwnProfile();
        } catch (e) {
            ownPubkey = null;
        }
    })

    function validate(data) {
        const validTypes = [ 'lodging', 'airport', 'coffee', 'surfing', 'climbing', 'psa' ];

        if (!data.type || !validTypes.includes(data.type)) {
            return false;
        }

        return true;
    }
    
    async function submit(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {};

        ownPubkey = await $nostrPool.fetchOwnProfile();
        if (!ownPubkey) {
            alert('No nostr pubkey?');
            return
        }

        for (let field of formData) {
            const [key, value] = field;
            data[key] = value;
        }

        if (!validate(data)) { return; }

        data.categories = [{ events: ['nostrica'] }]

        let event = {
            content: formData.get('comment'),
            kind: 1,
            created_at: Math.floor(Date.now() / 1000),
            tags: [
                ["t", 'marketplace'],
                ["t", '#nostrica'],
                ["subject", formData.get('title')],
            ],
            pubkey: ownPubkey,
        };
        console.log(event);
        
        let {publishEvent} = await $nostrPool.signAndPublishEvent(event);
        publishEventId = publishEvent.id;
    }

    // hack? what hack?
    $: publishEventId && $nostrNotes[publishEventId] && dispatch('post', publishEventId);
</script>

<div class="my-4 w-full">
    {#if !ownPubkey}
    <div class="bottom-0 p-3 bg-red-600 border-red-800 border-8 text-white w-full text-center">
        <div class="flex justify-center flex-row items-center">
            <img src="https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Ftse1.mm.bing.net%2Fth%3Fid%3DOIP.mR6qbzeucpJw74GqX5k8igHaEo%26pid%3DApi&f=1&ipt=84829f0f55dbaf2de493d3df75995f52abbe4d22b44d094924f54655a133137f&ipo=images" alt="" width="300" class="mr-5">
            <div class="flex-1">
                <h1>NO NOSTR FOR YOU!</h1>
                <p class="mt-5">
                    You can only use
                    ANANOSTR
                    in read-only mode until you install
                    a Nostr extension.
                </p>
                <p class="mt-8">
                    <a href="https://getalby.com" class="bg-red-900 text-white px-4 py-2 text-xs rounded">Install Alby</a>
                    <a href="https://github.com/fiatjaf/nos2x" class="bg-red-900 text-white px-4 py-2 text-xs rounded">Install Nos2x</a>
                </p>
            </div>
        </div>
    </div>
        
    {:else}
        <div class="bg-purple-600 text-white">
            <form method="POST" action="?post" on:submit={submit} id="post-form">
                <div class="px-6 py-4">
                    <h1>Have something to share?</h1>
            
                    <div class="my-3 ">
                        <PostTypeSelector></PostTypeSelector>  
                    </div>
                </div>

                <button type="submit" class="w-full text-center rounded-md border border-transparent bg-purple-900 px-6 py-5 text-base font-medium text-white shadow-sm hover:bg-purple-800 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 flex flex-row items-center justify-center">
                    <img src="https://nostrica.com/images/shaka.png" alt="" class="mr-3 h-full">
                    <div class="flex flex-col items-start">
                        <h1>Post it!</h1>
                        <!-- <h3 class="text-sm text-purple-200 font-light">(0 sats)</h3> -->
                    </div>
                </button>
            </form>
        </div>
    {/if}
</div>