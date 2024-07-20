<script lang="ts">
	import { Button } from "$components/ui/button";
	import { Input } from "$components/ui/input";
	import { Label } from "$components/ui/label";
	import { ndk } from "$stores/ndk";
	import { loginMethod, privateKey, user, userPubkey } from "$stores/user";
	import { setSigner } from "$utils/login/setSigner";
	import { NDKPrivateKeySigner } from "@nostr-dev-kit/ndk";
	import { toast } from "svelte-sonner";

    export let nsec = "";

    async function login() {
        try {
            const signer = new NDKPrivateKeySigner(nsec);
            const user = await signer.user();
            console.log(user);

            $loginMethod = "pk";
            $privateKey = signer.privateKey;
            $userPubkey = user.pubkey;

            setSigner(signer);
        } catch (e) {
            console.error(e);
            toast.error(e.message);
        }
    }
</script>

<div class="flex flex-col gap-2">
    <Label for="name" class="text-lg">Nsec</Label>
    <Input id="name" placeholder="nsec1..." required bind:value={nsec} class="w-full text-xl font-mono" type="password" />
</div>
<Button type="submit" class="w-full" on:click={login}>Login</Button>