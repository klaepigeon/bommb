// Builds the game into one self-contained HTML file: dist/index.html.
//   node build.mjs          build once
//   node build.mjs --watch  rebuild on every change under src/
import * as esbuild from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync, watch } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));

async function build() {
  const out = await esbuild.build({
    entryPoints: [join(root, 'src/main.js')],
    bundle: true, minify: !process.argv.includes('--dev'), format: 'iife', write: false, target: 'es2020', legalComments: 'none',
  });
  const js = out.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
  const html = readFileSync(join(root, 'src/index.html'), 'utf8')
    .replace('/*STYLE*/', () => readFileSync(join(root, 'src/style.css'), 'utf8'))
    .replace('/*SCRIPT*/', () => js);
  mkdirSync(join(root, 'dist'), { recursive: true });
  writeFileSync(join(root, 'dist/index.html'), html);
  console.log(`dist/index.html  ${(html.length / 1024).toFixed(0)} KB`);
}

await build();
if (process.argv.includes('--watch')) {
  let t;
  watch(join(root, 'src'), { recursive: true }, () => { clearTimeout(t); t = setTimeout(() => build().catch((e) => console.error(e.message)), 120); });
}
