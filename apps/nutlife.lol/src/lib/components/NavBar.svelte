<script >
    import { loggedUser } from '$lib/store';
    import { onMount } from 'svelte';

    let loggedIn;

    $: loggedIn = !!$loggedUser;

    onMount(async () => {
        const pubkey = localStorage.getItem('loggedUserPubkey');

        if (pubkey) {
            loggedUser.set(pubkey);
        }
    });

    export async function login() {
        const publicKey = await window.nostr.getPublicKey();
        loggedUser.set(publicKey);

        localStorage.setItem('loggedUserPubkey', publicKey);
    }

    export function logout() {
        loggedUser.set(null);
        localStorage.removeItem('loggedUserPubkey');
    }
</script>

<div class="flex flex-row justify-between items-center w-full px-3">
    <a href="/" class="flex flex-row items-center text-xl text-purple-700 dark:text-purple-500 mt-3 flex-1" style="font-family: 'Press Start 2P';">
        🕶️
        NUTLIFE.LOL
    </a>

    <a href="nostr:npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft" class="text-gray-700 dark:text-gray-400 font-mono">
        by
        @pablof7z
    </a>

    <!-- <div class="flex flex-col items-end justify-end h-full">
        {#if loggedIn}
            <a href="/logout" class="text-gray-700 dark:text-gray-400 font-mono" on:click|preventDefault={logout}>
                logout
            </a>
        {:else}
            <a href="#" class="text-gray-700 dark:text-gray-400 font-mono" on:click|preventDefault={login}>
                login
            </a>
        {/if}
    </div> -->
</div>
