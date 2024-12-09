<script lang="ts">
	import Button from '$components/ui/button/button.svelte';
	import { ndk } from '$stores/ndk';
	import { user } from '$stores/user';
	import { NDKEvent, NDKKind, NDKPublishError, NDKRelaySet } from '@nostr-dev-kit/ndk';
    import Badge from '$components/ui/badge/badge.svelte';
	import { onDestroy } from 'svelte';
	import { Dot, DotSquare, TicketSlash, Nut, Edit } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';
	import { derived } from 'svelte/store';
	import Avatar from '$components/User/Avatar.svelte';
	import { Name } from '@nostr-dev-kit/ndk-svelte-components';
	import { wallet, walletMintBalance, walletsBalance, walletService } from '$stores/wallet';

    let updatedAt = 0;
    
    $wallet?.on("nutzap:redeemed", (event: NDKEvent) => {
        toast("redeemed a nutzap from "+ event.pubkey)
    })

    $wallet?.on("nutzap:seen", (event: NDKEvent) => {
        toast("seen a nutzap from "+ event.pubkey)
    })

    const walletActivity = $ndk.storeSubscribe([
        {kinds: [NDKKind.CashuToken, NDKKind.EventDeletion], authors: [$user!.pubkey]},
        {kinds: [NDKKind.Nutzap], "#p": [ $user!.pubkey ]},
    ])

    const nutzaps = derived(walletActivity, ($walletActivity) => {
        const zaps = $walletActivity.filter(e => e.kind === NDKKind.Nutzap)
        return zaps;
    });

    let selectedBalance: string | undefined;
    function selectBalance(mint: string, balance: number) {
        if (balance < 3) return;
        if (selectedBalance === mint)
            selectedBalance = undefined;
        else
            selectedBalance = mint;
    }

    function transferBalance(targetMint: string) {
        $walletService.transfer($wallet, selectedBalance, targetMint);
    }

    async function republish(url: string) {
        if (!$wallet) return;
        const set = NDKRelaySet.fromRelayUrls([url], $ndk);
        try {
            const ret = await $wallet.publish(set);
            console.log("published to", url, ret);
            toast.success("Published to " + url);
        } catch (e: NDKPublishError) {
            console.error(e);
            toast.error(e.relayErrors);
        }

    }
</script>

{#if $wallet}
    <div class="flex flex-col gap-6 w-full">
        <div class="flex-grow flex items-center justify-center gap-6 flex-col min-h-[30vh]">
            <div class="text-7xl font-black items-center text-center focus:outline-none w-full">
                {$walletsBalance.get($wallet.walletId)??"0"}
                <div class="text-3xl text-muted-foreground font-light">{$wallet.unit}</div>
            </div>
        </div>

        <div class="flex flex-col w-full">
            {#each Object.entries($walletMintBalance.get($wallet.walletId)||{}) as [mint, balance]}
                <div class="flex flex-row items-center justify-between gap-6 w-full">

                    {#if selectedBalance && selectedBalance !== mint}
                        <button on:click={() => transferBalance(mint)} class="grow w-full text-muted-foreground font-light bg-secondary text-left">{mint}</button>
                    {:else}
                        <div class="grow w-full text-muted-foreground font-light">{mint}</div>
                    {/if}
                    
                    <div class="">
                        <button on:click={() => selectBalance(mint, balance)}>
                            <Badge class="flex flex-row items-center gap-1 flex-nowrap whitespace-nowrap">
                                {balance}
                                {$wallet.unit}
                            </Badge>
                        </button>
                    </div>
                </div>
            {/each}
        </div>
    </div>
{/if}

<div class="flex flex-col items-center justify-center gap-2">
    <div class="flex flex-row items-center w-full gap-4 max-sm:p-2">
        <Button class="grow" href="/deposit">
            Deposit
        </Button>
        <Button class="grow" href="/withdraw">
            Withdraw
        </Button>
        <Button variant="secondary" href="/tokens" class="shrink">
            <TicketSlash class="h-6 w-6 opacity-80" strokeWidth={1} />
        </Button>
        <Button variant="secondary" href="/wallet" class="shrink">
            <Edit class="h-6 w-6 opacity-80" strokeWidth={1} />
        </Button>
    </div>

    {#if $wallet}
        <div class="flex flex-row items-center w-full flex-wrap gap-4 max-sm:p-2">
            {#each $wallet?.relays as url}
                <Button size="sm" variant="secondary" class="flex flex-row items-center gap-1 flex-nowrap whitespace-nowrap"
                    on:click={() => republish(url)}
                >
                    <span
                        class="
                            w-2 h-2 rounded-full
                            {
                                $wallet.event.onRelays.map(r => r.url).includes(url) ?
                                "bg-green-500" : "bg-red-500"
                            }
                        "
                    ></span>
                    {url}
                </Button>
            {/each}
        </div>
    {/if}
</div>

<div class="flex flex-col items-start divide-y divide-border border-y">
    {#each $nutzaps as nutzap (nutzap.id)}
        <div class="flex flex-row items-center gap-2 w-full">
            <a href="/send?pubkey={nutzap.pubkey}">
                <Avatar pubkey={nutzap.pubkey} size="small" />
            </a>

            <div class="flex flex-col items-start grow">
                <Name pubkey={nutzap.pubkey} class="text-sm font-bold" ndk={$ndk} />
                <div class="flex-grow text-muted-foreground font-light">
                    {nutzap.tagValue("comment")}
                </div>
            </div>

            <div class="bold">
                <Nut class="h-6 w-6 inline mr-2" />
                {parseInt(nutzap.tagValue("amount"))/1000}
                <span class="text-muted-foreground text-sm font-light">
                    {$wallet.unit}
                </span>
            </div>
        </div>
    {/each}
</div>