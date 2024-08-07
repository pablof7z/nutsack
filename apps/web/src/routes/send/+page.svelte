<script lang="ts">
	import { page } from "$app/stores";
	import { Button } from "$components/ui/button";
	import { Input } from "$components/ui/input";
	import { Textarea } from "$components/ui/textarea";
	import Avatar from "$components/User/Avatar.svelte";
	import { ndk } from "$stores/ndk";
	import { wallet } from "$stores/wallet";
    import { NDKKind, NDKSubscriptionCacheUsage, NDKNutzap } from "@nostr-dev-kit/ndk";
	import type { NDKEvent, NDKUser, NDKZapMethodInfo, NDKZapSplit } from "@nostr-dev-kit/ndk";
	import { Name } from "@nostr-dev-kit/ndk-svelte-components";
	import { Nut } from "lucide-svelte";
	import { toast } from "svelte-sonner";

    let npub: string;
    let pubkey: string;
    let eventId: string;
    let user: NDKUser;
    let amount: number = 1;

    let event: NDKEvent;

    $: {
        eventId = $page.url.searchParams.get("eventId");

        if (eventId) {
            $ndk.fetchEvent(eventId).then(e => {
                if (e) {
                    event = e;
                    user = e.author;
                }
            })
        }
    }
        
    $: {
        npub = $page.url.searchParams.get("npub");
        pubkey = $page.url.searchParams.get("pubkey");
        if (pubkey) user = $ndk.getUser({pubkey})
        else if (npub) user = $ndk.getUser({npub});
        pubkey = user?.pubkey;

        user?.getZapInfo(false)
            .then(info => zapInfo = info)
    }

    let zapInfo: NDKZapMethodInfo[];

    let zapping = false;

    let comment = "Nutzapped";

    async function zap() {
        // refresh
        const r = await $ndk.fetchEvent({kinds: [NDKKind.CashuMintList], authors: [user.pubkey]}, {cacheUsage: NDKSubscriptionCacheUsage.ONLY_RELAY});
        console.log('updated', r?.rawEvent());
        
        let target = event ?? user;
        target.ndk = $ndk;
        zapping = true;
        const zapper = await $ndk.zap(target, amount*1000, { comment });
        zapper.on("complete", (results: Map<NDKZapSplit, NDKPaymentConfirmation | Error | undefined>) => {
            results.forEach((res, split) => {
                if (res instanceof Error) {
                    toast.error(res.message);
                    console.error(res);
                    return;
                }
                
                if (res instanceof NDKNutzap) {
                    toast.info("Nutzapped", {
                        action: {
                            label: "View",
                            onClick: () => {
                                window.open("https://njump.me/" + res.encode(), "_blank");
                            }
                        }
                    })
                } else if (typeof res === "string") {
                    toast.success(res);
                }
                console.log('zap result', res);
            });
            zapping = false;
        });

        zapper.zap();
        
        // const res = await $wallet.zap(target, amount*1000, "msats", comment);
        // if (res) {
        //     toast("👍🌰");
        // }
        // console.log('zap result', res);
        // zapping = false;

        // const pr = await user.zap(amount*1000, "zapping from my nutsack wallet", extraTags);
        // await $wallet.lnPay(pr);
    }
</script>

<div class="flex flex-col">
    {#if event}
        <div class="text-sm overflow-y-auto max-h-[30vh] bg-secondary text-secondary-foreground p-4 rounded-xl mb-4">
            {event.content}
        </div>
    {/if}

    {#if user}
        <div class="flex flex-col grow items-center gpa-10">
            <Avatar {user} size="large" />
            <h1 class="text-2xl font-black">
                Nut zap
                <Name ndk={$ndk} {user} class=""/>
            </h1>

            <div class="flex-grow flex items-center justify-center gap-6 flex-col">
                <div class="px-6 flex flex-col items-center">
                    <Input bind:value={amount} type="number" class="!p-6 !pt-10 border-none m-2 text-5xl font-bold items-center text-center w-full" />
                    <div class="text-3xl text-muted-foreground font-light">{$wallet.unit}</div>
                </div>
            </div>

            <Textarea bind:value={comment} />
            
            <div class="flex flex-row justify-center items-center w-full gap-4 max-sm:fixed bottom-0 left-0 max-sm:p-2">
                <Button class="w-2/3 py-3 text-2xl h-auto" size="lg" on:click={zap} disabled={zapping}>
                    <Nut class="h-6 w-6 mr-2" />
                    Nutzap
                    
                </Button>
            </div>
        </div>
    {/if}
</div> 