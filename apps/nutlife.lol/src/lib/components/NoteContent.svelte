<script>
    import { massageString } from "$lib/utils";

    export let content;
    export let tags;
    let renderContent;

    $: renderContent = massageString(content);
</script>

<div class="note-content">
    {renderContent}
</div>