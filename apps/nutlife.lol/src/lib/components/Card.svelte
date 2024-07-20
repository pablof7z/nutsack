<script>
    export let title, value;
</script>

<div class="bg-white rounded-lg shadow-lg p-4 py-2">
    <div class="flex flex-row items-center">
        <div class="flex flex-col overflow-hidden">
            <div class="font-bold text-xl">{title}</div>
            <div class="text-gray-600 text-sm text-ellipsis truncate">{value||""}<slot /></div>
        </div>
    </div>
</div>