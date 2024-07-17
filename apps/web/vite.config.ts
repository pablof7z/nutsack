import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { nodePolyfills } from 'vite-plugin-node-polyfills';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';

const mobileBuild = !!process.env.VITE_MOBILE;

export default defineConfig({
	plugins: [
		sveltekit(),
		SvelteKitPWA({
			"icons": [
			  {
				"src": "/pwa-64x64.png",
				"sizes": "64x64",
				"type": "image/png"
			  },
			  {
				"src": "/pwa-192x192.png",
				"sizes": "192x192",
				"type": "image/png"
			  },
			  {
				"src": "/pwa-512x512.png",
				"sizes": "512x512",
				"type": "image/png"
			  },
			  {
				"src": "/maskable-icon-512x512.png",
				"sizes": "512x512",
				"type": "image/png",
				"purpose": "maskable"
			  }
			]
		}),
		nodePolyfills(),
	],
	optimizeDeps: {
		exclude: [
            "phosphor-svelte",
        ],
	},
});
