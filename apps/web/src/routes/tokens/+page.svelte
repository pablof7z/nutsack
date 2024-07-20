<script lang="ts">
	import Token from "$components/Token.svelte";
import { wallet } from "$stores/wallet";

    const mintTokens = $wallet.mintTokens;
</script>

{#if mintTokens}
    {#each Object.entries(mintTokens) as [mint, tokens]}
        <h1>{mint}</h1>
        {#each tokens as token}
            <Token {token} />
        {/each}
    {/each}
{/if}