<script>
	import { ndk } from "$stores/ndk";
    import {Avatar} from "@nostr-dev-kit/ndk-svelte-components";
    import { onMount } from 'svelte';

    export let pubkey;
    export let klass;
</script>

<Avatar ndk={$ndk} {pubkey} class="{klass} ring-4 ring-white rounded-full" />