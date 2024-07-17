<script lang="ts">
	import Button from '$components/ui/button/button.svelte';
	import { ndk } from '$stores/ndk';
	import { activeWallet, user, wallet } from '$stores/user';
	import { NDKKind } from '@nostr-dev-kit/ndk';
    import Badge from '$components/ui/badge/badge.svelte';
	import { onDestroy } from 'svelte';
	import { Dot, DotSquare, TicketSlash, Nut, Edit } from 'lucide-svelte';
	import { toast } from 'svelte-sonner';
	import { derived } from 'svelte/store';
	import Avatar from '$components/User/Avatar.svelte';
	import { Name } from '@nostr-dev-kit/ndk-svelte-components';

    let updatedAt = 0;
    
    const sub = $activeWallet!.start();
    $activeWallet.on("update", () => {
        updatedAt = new Date();
    })

    $activeWallet?.on("nutzap:redeemed", (event: NDKEvent) => {
        toast("redeemed a nutzap from "+ event.pubkey)
    })

    $activeWallet?.on("nutzap:seen", (event: NDKEvent) => {
        toast("seen a nutzap from "+ event.pubkey)
    })

    const walletActivity = $ndk.storeSubscribe([
        {kinds: [NDKKind.CashuToken, NDKKind.EventDeletion], authors: [$user!.pubkey]},
        {kinds: [NDKKind.Nutzap], "#p": [ $user!.pubkey ]},
    ])

    const tokens = derived(walletActivity, ($walletActivity) => {
        const deletedEvents = new Set();
        $walletActivity.filter(e => e.kind === NDKKind.EventDeletion)
            .forEach(e => {
                for (const deletedId of e.getMatchingTags("e")) {
                    deletedEvents.add(deletedId);
                }
            });
        
        return $walletActivity.filter(e => e.kind === NDKKind.CashuToken)
            .filter(e => !deletedEvents.has(e.id))
    })

    const nutzaps = derived(walletActivity, ($walletActivity) => {
        const zaps = $walletActivity.filter(e => e.kind === NDKKind.Nutzap)
        return zaps;
    });

    onDestroy(() => {
        sub.stop();
    })
</script>

{#key updatedAt}
    <div class="flex flex-col gap-6 w-full">
        <div class="flex-grow flex items-center justify-center gap-6 flex-col min-h-[30vh]">
            <div class="text-7xl font-black items-center text-center focus:outline-none w-full">
                {$activeWallet?.balance}
                <div class="text-3xl text-muted-foreground font-light">{$activeWallet.unit}</div>
            </div>
        </div>

        <div class="flex flex-col w-full">
            {#each Object.entries($activeWallet.mintBalances) as [mint, balance]}
                <div class="flex flex-row items-center justify-between gap-6 w-full">
                    <div class="grow w-full text-muted-foreground font-light">{mint}</div>
                    <div class="">
                        <Badge class="flex flex-row items-center gap-1 flex-nowrap whitespace-nowrap">
                            {balance}
                            {$activeWallet.unit}
                        </Badge>
                    </div>
                </div>
            {/each}
        </div>
    </div>
{/key}

<div class="flex flex-col items-center justify-center gap-2">
    <div class="flex flex-row items-center w-full gap-4 max-sm:p-2">
        <Button class="grow" href="/deposit">
            Deposit
        </Button>
        <Button class="grow">
            Withdraw
        </Button>
        <Button variant="secondary" href="/tokens" class="shrink">
            <TicketSlash class="h-6 w-6 opacity-80" strokeWidth={1} />
        </Button>
        <Button variant="secondary" href="/wallet" class="shrink">
            <Edit class="h-6 w-6 opacity-80" strokeWidth={1} />
        </Button>
    </div>
</div>

<div class="flex flex-col items-start divide-y divide-border border-y">
    {#each $nutzaps as nutzap (nutzap.id)}
        <div class="flex flex-row items-center gap-2 w-full">
            <Avatar pubkey={nutzap.pubkey} size="small" />

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
                    {$activeWallet.unit}
                </span>
            </div>
        </div>
    {/each}
</div>