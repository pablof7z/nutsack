<script>
    let expandZapraiser = false;
</script>

<div class="text-2xl dark:text-gray-400 text-justify max-w-xl">
    {#if expandZapraiser}
    <p class="mt-2">
        To do a fundraiser with zaps, tag your note with <span class="text-purple-500 font-mono">#zapraiser [amount]</span>.
    </p>

    <p class="mt-2">
        <span class="text-purple-500 font-mono">#zapraiser 1000</span><br>
        <span class="text-purple-500 font-mono">#zapraiser 10k</span><br>
        <span class="text-purple-500 font-mono">#zapraiser 1M</span><br>
        <span class="text-purple-500 font-mono">#zapraiser 1btc</span><br>
    </p>
    {/if}

    <a href="#" class="text-sm" on:click|preventDefault={() => { expandZapraiser = !expandZapraiser }}>What's this?</a>
</div>
