<script lang="ts">
    import { ndk } from "$stores/ndk";
	import { onMount, setContext } from "svelte";

    import "../app.css";
	import { NDKKind } from "@nostr-dev-kit/ndk";

    const mainSub = $ndk.storeSubscribe([
        { kinds: [ NDKKind.Nutzap ] }
    ], { autoStart: true })
    setContext('mainSub', mainSub);
</script>


<div class="flex flex-col min-h-screen items-center bottom-0 w-screen">
    <div class="flex flex-col items-center max-w-3xl w-full flex-grow">
        <slot />
    </div>
    <footer class="py-3 bg-purple-1000 font-mono text-white text-center mt-12 px-10 rounded-t-lg">
        <div class="flex justify-center flex-row">
            <div class="text-sm">
                ZAPLIFE.LOL
                by
                <a class="text-purple-50 hover:text-purple-400" href="https://pablof7z.com">
                    @pablof7z
                </a>
            </div>
        </div>
    </footer>
</div>