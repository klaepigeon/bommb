// Bundle the sequel: esbuild compiles src/main.ts (and everything it imports) into one IIFE,
// which is inlined into src/shell.html → dist/index.html (a single self-contained file).
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const res = await build({
  entryPoints: [join(ROOT, 'src/main.ts')], bundle: true, format: 'iife', target: 'es2020', minify: process.argv.includes('--min'),
  write: false, legalComments: 'none', logLevel: 'warning',
});
const js = res.outputFiles[0].text.replace(/<\/script/g, '<\\/script');
const html = readFileSync(join(ROOT, 'src/shell.html'), 'utf8').replace('<!--APP-->', () => `<script>\n${js}</script>`);
mkdirSync(join(ROOT, 'dist'), { recursive: true });
writeFileSync(join(ROOT, 'dist/index.html'), html);
console.log(`built dist/index.html (${Math.round(html.length / 1024)} KB)`);
