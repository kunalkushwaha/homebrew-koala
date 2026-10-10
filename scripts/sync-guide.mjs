#!/usr/bin/env node
// Copies the user guide in docs/ into src/content/docs/guide/ for Starlight.
//
// docs/ is exported from Koala's source repository on each release and must
// stay readable on GitHub, so it is never edited here. This script adapts a
// copy at build time:
//   - the page's "# Title" becomes Starlight front matter;
//   - the "[User guide](README.md) > Page" breadcrumb line is dropped (the
//     site has its own navigation);
//   - links between guide pages ("vms.md#lifecycle-commands") become site
//     URLs ("../vms/#lifecycle-commands"); README.md is the guide's index.
// It fails if a page has no title or links to a guide page that is missing.
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const source = join(root, 'docs');
const dest = join(root, 'src/content/docs/guide');

const pages = readdirSync(source).filter((name) => name.endsWith('.md'));
const slug = (name) => (name === 'README.md' ? '' : name.replace(/\.md$/, ''));
const problems = [];

rmSync(dest, { recursive: true, force: true });
mkdirSync(dest, { recursive: true });

for (const name of pages) {
	let text = readFileSync(join(source, name), 'utf8');
	const heading = text.match(/^# (.+)\n/);
	if (!heading) {
		problems.push(`${name}: no "# Title" on the first line`);
		continue;
	}
	const title = heading[1].trim();
	text = text.slice(heading[0].length);
	text = text.replace(/^\s*\[User guide\]\(README\.md\) > .*\n/, '');

	// From /guide/PAGE/ a sibling is ../OTHER/; from /guide/ it is OTHER/.
	const up = name === 'README.md' ? '' : '../';
	text = text.replace(/(?<!!)\]\(([a-z0-9-]+|README)\.md(#[^)\s]*)?\)/gi, (match, page, anchor = '') => {
		if (!pages.includes(`${page}.md`)) {
			problems.push(`${name}: link to missing page ${page}.md`);
			return match;
		}
		const target = slug(`${page}.md`);
		return `](${up}${target ? `${target}/` : up ? '' : './'}${anchor})`;
	});
	// Images are resolved relative to the copied file, so images/ is copied
	// next to the pages and those links stay as they are.

	const frontmatter = `---\ntitle: ${JSON.stringify(title)}\n---\n`;
	writeFileSync(join(dest, name === 'README.md' ? 'index.md' : name), frontmatter + text);
}

if (existsSync(join(source, 'images'))) {
	cpSync(join(source, 'images'), join(dest, 'images'), { recursive: true });
}

if (problems.length) {
	console.error(`sync-guide: ${problems.join('; ')}`);
	process.exit(1);
}
console.log(`sync-guide: ${pages.length} pages from docs/ into src/content/docs/guide/`);
