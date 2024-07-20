<script>
    import RadioButton from '$lib/components/RadioButton.svelte';

    export let hours;
    export let click;
</script>

<RadioButton on:click={click} pos="left" bind:activeValue={hours} value={0} text="Now" />
<RadioButton on:click={click} bind:activeValue={hours} value={1} text="1 hour" />
<RadioButton on:click={click} bind:activeValue={hours} value={4} text="4 hours" />
<RadioButton on:click={click} bind:activeValue={hours} value={24} text="24 hours" />
<!-- <RadioButton on:click={click} bind:activeValue={hours} value={720} text="1 month" /> -->
<RadioButton on:click={click} pos="right" bind:activeValue={hours} value={168} text="7 days" />
<!-- <RadioButton on:click={click} pos="right" bind:activeValue={hours} value={'all'} text="all time" /> -->