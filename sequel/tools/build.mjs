// Builds the sequel: game 1's engine modules (every system, unchanged) followed by the
// sequel layer (src/engine, bundled by esbuild), in a page derived from game 1's shell.
//   dist/index.html        — standalone page
//   dist/rhapsody-xx8x.html — body-only variant for publishing as an artifact
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ROOT as GAME1, engineModules, embedFonts, scriptTag, fullPage } from '../../tools/bundle.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const { files, js: engine } = engineModules(join(GAME1, 'src'));
const res = await build({ entryPoints: [join(ROOT, 'src/engine/index.ts')], bundle: true, format: 'iife', target: 'es2020', write: false, legalComments: 'none', logLevel: 'warning' });
const sequel = res.outputFiles[0].text;
const shell = embedFonts(readFileSync(join(GAME1, 'src', 'shell.html'), 'utf8'))
  .replace('<title>Rhapsody</title>', '<title>Rhapsody XX8X</title>')
  .replace('BUILDING THE COAST…', 'PLOTTING THE STARS…');
const body = `${shell}\n${scriptTag(engine + '\n// ---- the sequel layer\n' + sequel)}`;
mkdirSync(join(ROOT, 'dist'), { recursive: true });
writeFileSync(join(ROOT, 'dist', 'rhapsody-xx8x.html'), body);
writeFileSync(join(ROOT, 'dist', 'index.html'), fullPage(body));
console.log(`built ${files.length} game 1 modules + the sequel layer (${Math.round(sequel.length / 1024)} KB), ${Math.round(body.length / 1024)} KB`);
