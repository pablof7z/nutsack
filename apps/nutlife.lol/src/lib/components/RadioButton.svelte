<script>
    import { createEventDispatcher } from 'svelte';
    const dispatch = createEventDispatcher();
    export let activeValue;
    export let value;
    export let text;
    export let pos;
</script>

<button class="
    {activeValue === value ? 'bg-purple-900 text-white' : 'bg-gray-300 hover:bg-gray-100 text-gray-500'}
    {pos === 'left' ? 'sm:rounded-l-lg' : ''}
    {pos === 'right' ? 'sm:rounded-r-lg' : 'border-r border-r-gray-200'}
    
    px-3 sm:px-5 py-3 font-mono
  " on:click|preventDefault={() => { activeValue = value; dispatch('click', value); }}>
    {text}
  </button>