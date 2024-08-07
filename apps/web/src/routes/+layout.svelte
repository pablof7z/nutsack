<script lang="ts">
	import { loginMethod, privateKey } from '$stores/user.js';
	import '../app.css';
	import {ndk} from '$lib/stores/ndk';
	import { user } from '$stores/user';
	import LoginPage from '$components/pages/Login/LoginPage.svelte';
	import { onMount } from 'svelte';
	import { NDKNip07Signer, NDKPrivateKeySigner, NDKRelay, type NDKEvent, type NDKSigner } from '@nostr-dev-kit/ndk';
	import SetupWalletPage from '$components/pages/Wallet/SetupWalletPage.svelte';
	import { Toaster } from "$lib/components/ui/sonner";
	import { Nut, NutIcon } from 'lucide-svelte';
	import Avatar from '$components/User/Avatar.svelte';
	import { setSigner } from '$utils/login/setSigner.js';
	import { pwaInfo } from 'virtual:pwa-info'; 
	import { walletInit, wallet } from '$stores/wallet';
	import { toast } from 'svelte-sonner';

	$: webManifestLink = pwaInfo ? pwaInfo.webManifest.linkTag : '' 

	onMount(async () => {
		$ndk.connect();

		$ndk.walletConfig = {
			onLnPay: async (lnPay) => {
				toast.error("Received a request to pay " + lnPay.amount/1000 + " satoshis");
				throw new Error("Not implemented");
			},
			onNutPay: async (details) => {
				const { mints, p2pkPubkey } = details.info;
				const { amount, unit } = details;

				if (!$wallet) {
					toast.error("Wallet not initialized");
					throw new Error("Wallet not initialized");
				}

				try {
					const res = await $wallet.nutPay(amount, unit, mints, p2pkPubkey);
					if (!res) throw new Error("failed to pay");

					const nutzap = await $wallet.publishNutzap(res.proofs, res.mint, details);
					toast.success("Nutzapped " + amount + " " + unit);
					return nutzap;
				} catch (e) {
					console.error(e);
					toast.error(e.message);
				}

				throw new Error("Failed to pay");
			},
		}
		
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
	
	let walletStarted = false;
	$: if (!walletStarted && $user) {
		walletStarted = true;
		try {
			walletInit($ndk, $user);
		} catch (e) {
			console.error(e);
			toast.error(e.message);
		}
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
			{#if !$wallet}
				<SetupWalletPage />
			{:else if $wallet}
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

