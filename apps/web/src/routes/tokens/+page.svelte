<script lang="ts">
	import { activeWallet } from "$stores/user";

    const mintTokens = $activeWallet.mintTokens;
    console.log(mintTokens)
</script>

{#if mintTokens}
    {#each Object.entries(mintTokens) as [mint, tokens]}
        <h1>{mint}</h1>
        {#each tokens as token}
            {token.amount}
            {$activeWallet.unit}
            in {token.proofs.length} unspent proofs
        {/each}
    {/each}
{/if}