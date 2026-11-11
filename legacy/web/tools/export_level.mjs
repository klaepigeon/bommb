// Exports Flat 47 from the JS build into the Godot project:
//   hysteria/assets/flat47/flat47.glb   geometry and textures (textures capped for the PS1 look)
//   hysteria/assets/flat47/level.json   collision boxes, floors, lights, spawn
//   node build.mjs && node tools/export_level.mjs [--tex 256]
import { createRequire } from 'node:module';
import * as esbuild from 'esbuild';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { mkdirSync, writeFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const tex = +(process.argv[process.argv.indexOf('--tex') + 1] || 256) || 256;
const out = join(root, 'hysteria/assets/flat47'); mkdirSync(out, { recursive: true });
const bundle = await esbuild.build({ entryPoints: [join(root, 'tools/export/entry.js')], bundle: true, write: false, format: 'iife' });
const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await b.newPage();
p.on('pageerror', (e) => console.log('PAGEERROR', e.message));
await p.goto(pathToFileURL(join(root, 'dist/index.html')).href + '?q=low&skip'); // no ?shots: the render loop stays idle while we export
await p.waitForFunction(() => window.__ready, null, { timeout: 300000 });
await p.addScriptTag({ content: bundle.outputFiles[0].text });
const r = await p.evaluate((t) => window.__exportFlat47(t), tex);
const glb = Buffer.from(r.glb, 'base64'); writeFileSync(join(out, 'flat47.glb'), glb);
writeFileSync(join(out, 'level.json'), JSON.stringify(r.level, null, 1));
console.log(`flat47.glb ${(glb.length / 1e6).toFixed(1)} MB, ${r.level.colliders.length} colliders, ${r.level.lights.length} lights`);
await b.close();
