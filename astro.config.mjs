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
			description: 'Run Linux workloads on your Mac, each in its own lightweight virtual machine.',
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
				{ label: 'Start here', items: [
					{ label: 'Overview', slug: 'guide' },
					{ label: 'Getting started', slug: 'guide/getting-started' },
					{ label: 'How it works', slug: 'how-it-works' },
				] },
				{ label: 'Using Koala', items: [
					{ label: 'Jobs and VMs', slug: 'guide/vms' },
					{ label: 'Working inside a VM', slug: 'guide/working-in-vms' },
					{ label: 'Images and registries', slug: 'guide/images' },
					{ label: 'Profiles: lean and full', slug: 'guide/profiles' },
				] },
				{ label: 'Access and isolation', items: [
					{ label: 'Networking', slug: 'guide/networking' },
					{ label: 'Shares, volumes and disks', slug: 'guide/storage' },
					{ label: 'Secrets', slug: 'guide/secrets' },
				] },
				{ label: 'Reference', items: [
					{ label: 'Limits and behaviour', slug: 'guide/limits' },
					{ label: 'Troubleshooting', slug: 'guide/troubleshooting' },
					{ label: 'Releases', link: 'https://github.com/kunalkushwaha/homebrew-koala/releases', attrs: { target: '_blank' } },
				] },
				{ label: 'Examples', items: [
					{ label: 'Run the Hermes agent', slug: 'guide/example-hermes' },
				] },
			],
		}),
	],
});
