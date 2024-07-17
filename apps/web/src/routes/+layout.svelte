<script lang="ts">
	import { loginMethod, privateKey } from '$stores/user.js';
	import '../app.css';
	import {ndk} from '$lib/stores/ndk';
	import { activeWallet, user, wallet } from '$stores/user';
	import LoginPage from '$components/pages/Login/LoginPage.svelte';
	import { onMount } from 'svelte';
	import type { NDKEventStore } from '@nostr-dev-kit/ndk-svelte';
	import { NDKNip07Signer, NDKPrivateKeySigner, NDKRelay, type NDKEvent, type NDKSigner } from '@nostr-dev-kit/ndk';
	import { derived, type Readable } from 'svelte/store';
	import SetupWalletPage from '$components/pages/Wallet/SetupWalletPage.svelte';
	import { Toaster } from "$lib/components/ui/sonner";
	import { Nut, NutIcon } from 'lucide-svelte';
	import Avatar from '$components/User/Avatar.svelte';
	import { setSigner } from '$utils/login/setSigner.js';
	import { pwaInfo } from 'virtual:pwa-info'; 

	$: webManifestLink = pwaInfo ? pwaInfo.webManifest.linkTag : '' 

	onMount(async () => {
		switch ($loginMethod) {
			case "pk": {
				if ($privateKey) {
					try {
						const signer = new NDKPrivateKeySigner($privateKey);
						setSigner(signer);
					} catch {}
				}
				break;
			}
			case "none": break;
			default:
				if (window.nostr) {
					const signer = new NDKNip07Signer();
					setSigner(signer);
				}
			}
	});

	function loadWallets() {
		if ($wallet && !walletStarted && $ndk.pool.connectedRelays().length >= 3) {
			walletStarted = true;
			console.log('starting wallet with', $ndk.pool.connectedRelays().length + 1, 'relays');
			$wallet.fetchUserWallets().then((w) => {
				const wallets = w;
				console.log('wallets', wallets);
				const firstWallet = wallets[0];
				if (!firstWallet) return;
				firstWallet.start();
				activeWallet.set(firstWallet);
			});
		}
	}

	$: if ($wallet && !walletStarted) {
		console.log('here')
		loadWallets();
	}

	let walletStarted = false;
	$ndk.pool.on("relay:connect", (r: NDKRelay) => {
		console.log("relay connected", r.url, $ndk.pool.connectedRelays().length, {walletStarted, wallet: !!$wallet});
		loadWallets();
	});

	let cashuRelaySub: NDKEventStore<NDKEvent>;
	let cashuRelayEvent: Readable<NDKEvent | undefined>;

	$: if ($user && !cashuRelaySub) {
		cashuRelaySub = $ndk.storeSubscribe(
			{ kinds: [10019], authors: [$user.pubkey]}
		)

		cashuRelayEvent = derived(cashuRelaySub, $sub => {
			return $sub[0];
		});
	}
</script>

<svelte:head>
	<title>Nutsack</title>
	{@html webManifestLink} 
</svelte:head>

<div class="flex flex-col h-screen w-screen items-center justify-center">
	<div class="h-screen lg:border border-border w-screen lg:max-w-[30rem]">
	{#if $user}
		<header class="sticky top-0 flex h-16 items-center gap-4 border-b bg-background px-4 md:px-6">
			<nav
				class="flex flex-row gap-6 text-lg font-medium md:flex md:flex-row md:items-center md:gap-5 md:text-sm lg:gap-6 w-full"
			>
				<a href="##" class="flex items-center gap-2 text-lg font-semibold md:text-base">
					<Nut class="h-6 w-6" />
					<span>Nutsack</span>
				</a>
				<div class="grow"></div>
				
				<a href="/" class="text-foreground transition-colors hover:text-foreground">
					Wallet
				</a>
				<a href="/zap" class="text-muted-foreground transition-colors hover:text-foreground">
					Nutzap
				</a>

				<a href="/keys">
					<Avatar user={$user} size="small" />
				</a>
			</nav>
		</header>


		<div class="flex flex-col gap-6 p-4 h-full">
			{#if !$cashuRelayEvent}
				<SetupWalletPage />
			{:else if $activeWallet}
				<slot />
			{:else}
				<!-- full screen spiner -->
				<div class="fixed top-1/3  w-full left-0">
					<h1 class="text-center w-full mb-20">
						Grabbing your nuts
					</h1>
					<marquee>
						<NutIcon size={72} class="animate-spin" />
					</marquee>
				</div>
			{/if}
		</div>
	{:else}
		<LoginPage />
	{/if}
	</div>	
</div>

<Toaster position="top-center" />

