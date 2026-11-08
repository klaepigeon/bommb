// Screenshots of the hands and Socko: idle, talking, torch, holding something, and the
// Flat 48 view where things used to show through the walls.
import { createRequire } from 'node:module';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const out = join(root, 'shots'); mkdirSync(out, { recursive: true });
const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await b.newPage({ viewport: { width: 960, height: 540 } });
const errors = []; p.on('pageerror', (e) => errors.push(e.stack));
await p.goto(pathToFileURL(join(root, 'dist/index.html')).href + '?shots&q=low');
await p.waitForFunction(() => window.__ready, null, { timeout: 300000 });
await p.evaluate(() => { document.getElementById('start').classList.add('hidden'); window.__G.flags.socko = true; });
const shot = async (name, f, sec = 1) => { await p.evaluate(([src, s]) => { new Function(src)(); window.__advance(s); }, [`(${f})()`, sec]); await p.screenshot({ path: join(out, name + '.png') }); console.log(name); };
await shot('h_idle', () => { window.__view(7.0, 4.5, Math.PI / 2, -0.05); });
await shot('h_talk', () => { window.__G.voice = 1; const v = window.__VOICE; v.talking = 4; }, 1.2);
await shot('h_torch', () => { window.__VOICE.talking = 0; window.__G.torch.set(true); window.__view(8.0, 2.0, 0.3, -0.1); }, 1.2);
await shot('h_hold', () => { window.__G.torch.set(false); window.__goto(8.9, 1.2); window.__reach(8.45, 0.47, 0.7); window.__use(); }, 1.2);
await shot('h_48', () => { window.__use(); window.__view(19.5, 4.0, -Math.PI * 0.75, -0.05); }, 1.2);
await shot('h_47kitchen', () => { window.__view(8.6, 4.6, 0.1, 0); }, 1);
console.log(errors.length ? 'ERRORS\n' + errors.join('\n') : 'no errors');
await b.close();
