<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import { Input } from "$lib/components/ui/input/index.js";
    import { Label } from "$lib/components/ui/label/index.js";
	import { ndk } from "$stores/ndk";
	import { loginMethod, privateKey, user, userPubkey } from "$stores/user";
	import { NDKEvent, NDKPrivateKeySigner, type NostrEvent } from "@nostr-dev-kit/ndk";
  import { Separator } from "$lib/components/ui/separator";
	import LoginWithNsec from "./LoginWithNsec.svelte";
	import { setSigner } from "$utils/login/setSigner";

    let name = "";
    let nsec = "";

    async function create() {
        const signer = NDKPrivateKeySigner.generate();
        $user = await signer.user();
        $user.ndk = $ndk;
        if (!$user) return;
        setSigner(signer);

        $loginMethod = "pk";
        $privateKey = signer.privateKey;
        $userPubkey = user.pubkey;

        if (name.length === 0) { name = "Alice"; }

        const profile = new NDKEvent($ndk, {
            kind: 0,
            content: JSON.stringify({
                display_name: name,
                name,
                picture: "https://robohash.org/"+encodeURIComponent(name)+".png?set=set3"
            })
        } as NostrEvent)
        profile.publish();

        const relays = new NDKEvent($ndk, {
            kind: 10002,
            tags: [
                [ "r", "wss://relay.primal.net" ],
                [ "r", "wss://relay.damus.io" ],
                [ "r", "wss://relay.f7z.io" ]
            ]
        } as NostrEvent)
        relays.publish();

        await $user.follow($ndk.getUser({npub: "npub1l2vyh47mk2p0qlsku7hg0vn29faehy9hy34ygaclpn66ukqp3afqutajft"}));
    }

    function nip07Restore() {
      localStorage.clear();
      window.location.href = '/'
    }
</script>

<div class="h-full w-full flex flex-col gap-4">
  <div class="h-1/2 flex flex-col items-stretch justify-center w-full p-6">
      <div class="text-xl font-bold">Sign Up</div>
      <div class="grid gap-4">
          <div class="grid grid-cols-1 gap-4">
            <div class="grid gap-2">
              <Label for="name" class="text-lg">Name</Label>
              <Input id="name" placeholder="Max" required bind:value={name} class="w-full text-xl" />
            </div>
          </div>
          <Button type="submit" class="w-full" on:click={create}>Create new key</Button>
        </div>
  </div>

  <Separator class="my-4" />

  <div class="h-1/2 flex flex-col items-stretch justify-center w-full p-6 gap-4">
      <div class="text-xl font-bold">Login</div>
      <LoginWithNsec />

      {#if window.nostr}
        <Button on:click={nip07Restore} class="w-full">Login with nostr extension</Button>
      {/if}
      
  </div>
</div>

