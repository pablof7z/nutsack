<script lang="ts">
	import { Button } from "$components/ui/button";
	import { wallet } from "$stores/wallet";
    import { ScanQRCode } from "@kuiper/svelte-scan-qrcode";
    let result: string | undefined;

    async function pay() {
        result = result.replace("lightning:", "");
        const res = await $wallet?.lnPay(result);
    }
</script>

{#if result}
    <h1>Pay?</h1>

    <pre>{result}</pre>

    <Button on:click={pay} class="w-full">
        Pay
    </Button>
{:else}
    <ScanQRCode
        bind:scanResult={result}
        enableQRCodeReaderButton={true}
        options={{
        }}
    />
{/if}