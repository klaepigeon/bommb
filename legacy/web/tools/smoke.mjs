// Headless check: boot the flat, walk to a list of viewpoints, save screenshots, fail on
// console errors.   node tools/smoke.mjs [--shots dir] [--only name,name]
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright')); }
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const out = arg('--shots', join(root, 'shots'));
const only = arg('--only', '');
const W = +arg('--w', 960), H = +arg('--h', 540);
mkdirSync(out, { recursive: true });

// name: [x, z, yaw, pitch, crouch, torch]
export const VIEWS = {
  spawn: [9.35, 4.55, Math.PI / 2 + 0.25, -0.05],
  hall_west: [9.6, 4.5, Math.PI / 2, -0.05],
  entry: [8.6, 4.55, -Math.PI / 2, 0.0],
  living_from_door: [4.15, 4.7, Math.PI / 2 - 0.35, -0.08],
  living_window: [3.0, 3.6, 0.15, 0.05],
  living_wall_unit: [1.6, 2.4, -Math.PI / 2, -0.05],
  living_barricade: [2.6, 3.4, Math.PI - 0.3, -0.15],
  living_collapse: [3.4, 2.5, 2.6, 0.55],
  bedroom: [7.0, 3.3, Math.PI * 0.25, -0.1],
  bedroom_bed: [6.9, 1.4, Math.PI / 2 + 0.2, -0.3],
  kitchen: [8.5, 3.5, -0.5, -0.1],
  kitchen_counter: [8.5, 1.6, -Math.PI / 2, -0.25],
  child: [5.6, 5.6, Math.PI - 0.3, -0.1],
  child_window: [4.6, 6.6, Math.PI, 0.0],
  bath: [9.1, 5.6, Math.PI * 0.75, -0.2, false, true],
  bath_ceiling: [8.8, 6.6, Math.PI / 2, 0.9, false, true],
  storage: [1.8, 5.6, Math.PI, -0.2, false, true],
  balcony: [2.2, -0.9, 0.2, 0.05],
  balcony_down: [2.6, -1.4, 0.3, -0.55],
  balcony_left: [1.2, -1.2, 1.1, 0.05],
  // the building
  stair4_landing: [12.2, 7.5, 0, -0.1, false, false, 0],
  stair4_up: [13.3, 5.2, 0.15, 0.45, false, false, 0],
  stair_well: [12.21, 3.75, 0, -1.35, false, false, 0],
  stair_half: [12.2, 0.7, Math.PI, 0.1, false, false, -1.55],
  f48_hall: [16.2, 4.55, -Math.PI / 2, -0.05, false, false, 0],
  f48_living: [19.5, 4.0, -Math.PI * 0.75, -0.05, false, false, 0],
  f51_hall: [9.3, 4.55, Math.PI / 2, -0.05, false, false, 3.1],
  f51_void: [3.4, 2.6, -0.2, -0.05, false, false, 3.1],
  f44_corridor: [17.6, 4.75, -Math.PI / 2, 0, false, false, -3.1],
  lobby: [12.6, 5.0, Math.PI, 0.05, false, false, -9.3],
  basement: [12.2, 5.5, Math.PI, -0.1, false, true, -12.4],
};

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: W, height: H } });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') { const t = m.text(); if (!/GPU stall|swiftshader|WebGL-|ReadPixels/i.test(t)) errors.push(`${m.type()}: ${t}`); } else if (process.argv.includes('--log')) console.log(m.text()); });
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
const t0 = Date.now();
await page.goto(pathToFileURL(join(root, 'dist/index.html')).href + '?shots&q=' + arg('--q', 'high') + (arg('--extra', '') ? '&' + arg('--extra', '') : ''));
await page.waitForFunction(() => window.__ready || document.getElementById('loadMsg').textContent.startsWith('Something'), null, { timeout: 240000 });
const fail = await page.evaluate(() => document.getElementById('loadMsg').textContent);
if (fail) { console.log(fail); errors.push(fail); }
console.log(`booted in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
console.log(await page.evaluate(() => { const r = window.__G.renderer.info; return `programs ${r.programs.length}`; }));
await page.evaluate(() => { document.getElementById('start').classList.add('hidden'); });
for (const [name, v] of Object.entries(VIEWS)) {
  if (only && !only.split(',').includes(name)) continue;
  const info = await page.evaluate(([x, z, yaw, pitch, crouch, torch, y]) => {
    window.__view(x, z, yaw, pitch, crouch, y || 0); if (window.__G.torch) window.__G.torch.set(!!torch);
    window.__step(20);
    const r = window.__G.renderer.info.render; return `calls ${r.calls} tris ${(r.triangles / 1000).toFixed(0)}k`;
  }, v);
  await page.screenshot({ path: join(out, name + '.png') });
  console.log(name.padEnd(20), info);
}
if (errors.length) { console.log('ERRORS:\n' + [...new Set(errors)].slice(0, 30).join('\n')); }
await browser.close();
process.exit(errors.length ? 1 : 0);
