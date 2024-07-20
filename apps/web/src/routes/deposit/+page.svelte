<script lang="ts">
    import { NDKCashuDeposit } from "@nostr-dev-kit/ndk-wallet";
	import { Button } from "$components/ui/button";
    import QRCode from "@bonosoft/sveltekit-qrcode"
	import { goto } from "$app/navigation";
    import { toast } from "svelte-sonner";
	import Input from "$components/ui/input/input.svelte";
    import * as Select from "$lib/components/ui/select/index.js";
	import { Textarea } from "$components/ui/textarea";
	import { wallet } from "$stores/wallet";
	import { CashuMint, type GetInfoResponse } from "@cashu/cashu-ts";
	import { fetchMintUnits, mintUnits } from "$stores/mint";

    let amount: number = 10;
    let pr: string | undefined;
    let paid = false;

    let deposit: NDKCashuDeposit | undefined;

    function copy() {
        navigator.clipboard.writeText(pr);
        toast("Copied to clipboard");
    }

    async function startDeposit() {
        if (selectedUnit === "usd") {
            amount = amount * 100;
        }
        
        deposit = $wallet.deposit(amount, selectedMint?.value, selectedUnit);
        pr = await deposit.start();
        deposit.on("success", () => {
            toast("Deposit successful");
            goto("/");
        });
        deposit.on("error", (e) => {
            toast("Deposit failed: " + e);
        });
    }

    let selectedMint: { value: string, label: string } | undefined;
    let mintInfo: Record<string, GetInfoResponse> = {};

    let selectedUnit: string | undefined;
    let selectedMintUrl: string | undefined;

    $: {
        selectedMintUrl = selectedMint ? selectedMint.value : undefined;
        selectedUnit = undefined;
    }

    // $: if (selectedMintUrl) {
    //     if (!$mintUnits[selectedMintUrl]) {
    //         fetchMintUnits(selectedMintUrl);
    //     }
    // }
</script>

<div class="flex flex-col gap-6 items-center h-full">
    {#if !pr}
        <div class="flex items-center justify-center gap-6 flex-col">
            <h1>Choose amount</h1>

            <div class="text-7xl font-black items-center text-center focus:outline-none">
                <Input bind:value={amount} type="number" class="!py-10 border-none text-5xl font-bold items-center text-center" />
                <!-- {#if selectedMintUrl}
                    <div class="flex flex-row gap-2">
                        {#each $mintUnits[selectedMintUrl]??[] as unit}
                            <Button
                                variant={unit === selectedUnit ? "default" : "ghost"} class="font-light"
                                on:click={() => selectedUnit = unit}
                            >
                                {unit}
                            </Button>
                        {/each}
                    </div>
                {:else} -->
                    <div class="text-3xl text-muted-foreground font-light">{$wallet.unit}</div>
                <!-- {/if} -->
            </div>

            {#if $wallet.mints.length > 1}
                <Select.Root bind:selected={selectedMint} portal={null}>
                    <Select.Trigger>
                        <Select.Value placeholder="Optionally choose a mint" />
                    </Select.Trigger>
                    <Select.Content>
                        <Select.Group>
                            <Select.Label>Mints</Select.Label>
                            {#each $wallet.mints as mint}
                                <Select.Item value={mint} label={mint}
                                    >{mint}</Select.Item>
                            {/each}
                        </Select.Group>
                    </Select.Content>
                    <Select.Input name="favoriteFruit" />
                </Select.Root>
            {/if}
            
        </div>

        <div class="flex flex-row items-center w-full gap-4 max-sm:p-2">
            <Button class="w-1/2" on:click={startDeposit}>
                Deposit
            </Button>
            <Button variant="secondary" class="w-1/2" href="/">
                Cancel
            </Button>
        </div>
    {:else}
        <div class="flex-grow flex items-center justify-center gap-6 flex-col">
            <h1 class="font-bold">Deposit with Lightning</h1>
    
            <QRCode content={`lightning:${pr}`} color="#444444" size="350" />

            <div class="flex flex-col gap-2 w-full">
                <Textarea class="font-mono" readonly value={pr}></Textarea>
                <Button variant="secondary" on:click={copy}>Copy</Button>
            </div>
        </div>
    {/if}
</div>
