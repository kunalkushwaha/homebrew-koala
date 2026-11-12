// Koala documentation website. `npm run dev` to preview, `npm run build` to
// build into dist/. The user guide comes from docs/ through scripts/sync-guide.mjs.
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
	site: 'https://kunalkushwaha.github.io',
	base: '/homebrew-koala',
	trailingSlash: 'always',
	integrations: [
		starlight({
			title: 'Koala',
			description: 'Run AI agents and other Linux workloads, each in its own lightweight virtual machine, on your Mac or on a Linux machine.',
			logo: { src: './src/assets/koala.svg' },
			favicon: '/favicon.svg',
			social: [
				{ icon: 'github', label: 'Koala on GitHub', href: 'https://github.com/kunalkushwaha/homebrew-koala' },
			],
			head: [
				{ tag: 'link', attrs: { rel: 'preconnect', href: 'https://fonts.googleapis.com' } },
				{ tag: 'link', attrs: { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' } },
				{
					tag: 'link',
					attrs: {
						rel: 'stylesheet',
						href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap',
					},
				},
			],
			customCss: ['./src/styles/koala.css'],
			expressiveCode: {
				themes: ['github-dark-default', 'github-light-default'],
				styleOverrides: {
					borderRadius: '10px',
					codeFontFamily: "'JetBrains Mono', ui-monospace, monospace",
					uiFontFamily: "'Inter', system-ui, sans-serif",
					codeFontSize: '0.85rem',
					frames: { shadowColor: 'transparent' },
				},
			},
			components: {
				Hero: './src/components/Hero.astro',
			},
			sidebar: [
				{ label: 'Get started', items: [
					{ label: 'Overview', slug: 'guide' },
					{ label: 'Install, upgrade and remove', slug: 'guide/getting-started' },
					{ label: 'How it works', slug: 'how-it-works' },
					{ label: 'Use with your AI assistant', slug: 'ai-assistants' },
				] },
				{ label: 'Tutorials', items: [
					{ label: '1. Your first VM', slug: 'guide/tutorial-first-vm' },
					{ label: '2. Run an AI agent safely', slug: 'guide/tutorial-agent' },
					{ label: '3. Your data, not your Mac', slug: 'guide/tutorial-data' },
					{ label: '4. Decide what an agent can reach', slug: 'guide/tutorial-policy' },
					{ label: '5. Secrets and keys', slug: 'guide/tutorial-secrets' },
					{ label: '6. Services and ports', slug: 'guide/tutorial-services' },
					{ label: '7. Look after your VMs', slug: 'guide/tutorial-look-after' },
					{ label: '8. Images, registries and Docker', slug: 'guide/tutorial-images' },
				] },
				{ label: 'Guides', items: [
					{ label: 'Jobs and VMs', slug: 'guide/vms' },
					{ label: 'Working inside a VM', slug: 'guide/working-in-vms' },
					{ label: 'Images and registries', slug: 'guide/images' },
					{ label: 'Shares, volumes and disks', slug: 'guide/storage' },
					{ label: 'Networking', slug: 'guide/networking' },
					{ label: 'Secrets', slug: 'guide/secrets' },
					{ label: 'Keys on your Mac (the broker)', slug: 'guide/broker' },
					{ label: 'VM templates for agents', slug: 'guide/templates' },
					{ label: 'Profiles: lean and full', slug: 'guide/profiles' },
				] },
				{ label: 'Examples', items: [
					{ label: 'Run the Hermes agent', slug: 'guide/example-hermes' },
					{ label: 'Run OpenClaw', slug: 'guide/example-openclaw' },
					{ label: 'An X agent', slug: 'guide/example-x-agent' },
				] },
				{ label: 'Reference', items: [
					{ label: 'The broker policy file', slug: 'guide/policy-file' },
					{ label: 'Troubleshooting', slug: 'guide/troubleshooting' },
					{ label: 'Limits and behaviour', slug: 'guide/limits' },
					{ label: 'Koala on Linux', slug: 'guide/linux' },
					{ label: 'Releases', link: 'https://github.com/kunalkushwaha/homebrew-koala/releases', attrs: { target: '_blank' } },
				] },
			],
		}),
	],
});
