<script lang="ts">
	import { Name } from '@nostr-dev-kit/ndk-svelte-components';
	import Avatar from '$components/User/Avatar.svelte';
	import { Button } from "$components/ui/button";
	import Textarea from "$components/ui/textarea/textarea.svelte";
	import { ndk } from "$stores/ndk";
	import { loginMethod, privateKey, user, userPubkey } from "$stores/user";
	import { NDKCashuMintList, NDKKind } from "@nostr-dev-kit/ndk";
    import { nsecEncode } from "nostr-tools/nip19";
	import { toast } from 'svelte-sonner';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

    let nsec = "";

    try {
        if ($privateKey && $loginMethod === "pk") {
            nsec = nsecEncode($ndk.signer._privateKey) as string;
        }
    } catch {}

    function logout() {
        $ndk.signer = undefined;
        user.set(undefined);
        privateKey.set(undefined);
        userPubkey.set(undefined);
        localStorage?.clear();
        loginMethod.set("none");
        window.location.href = "/";
    }

    function copy() {
        navigator.clipboard.writeText(nsec);
        toast("Copied to clipboard");
    }

    let mintListEvents: NDKCashuMintList | undefined;
    let mints: string;

    onMount(() => {
        $ndk.fetchEvent({kinds: [NDKKind.CashuMintList], authors: [$user!.pubkey]})
            .then(e => {
                if (e) {
                    mintListEvents = NDKCashuMintList.from(e);
                    mints = mintListEvents.mints.join("\n");
                }
            })
    })

    async function saveMints() {
        if (!mintListEvents) return;

        console.log("calling save mints", mints);

        mintListEvents.mints = mints.split("\n").filter(m => m);
        await mintListEvents.sign();
        const res = await mintListEvents.publishReplaceable();

        console.log("res", res);
        
        toast("Mints saved");
        goto("/");
    }
</script>

<h1>Logged in as</h1>

<div class="flex flex-row items-center truncate gap-2">
    <Avatar user={$user} size="large" />
    <Name user={$user} class="text-2xl font-bold" ndk={$ndk} />
</div>

{#if mintListEvents}
    <h1>Mints</h1>

    <Textarea class="font-mono" bind:value={mints}></Textarea>

    <Button variant="secondary" on:click={saveMints}>Save</Button>
{/if}

<h1>Keys</h1>

<div class="flex flex-col gap-2">
    <Textarea class="font-mono" readonly value={nsec}></Textarea>
    <Button variant="secondary" on:click={copy}>Copy</Button>
</div>

<h1>Tools</h1>

<Button class="w-full" on:click={logout}>
    Logout
</Button>