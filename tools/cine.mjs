// Play the opening cutscene headless and save a frame from each shot; then walk into the
// box room and check the encounter fires.
import { createRequire } from 'node:module';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const out = join(root, 'shots'); mkdirSync(out, { recursive: true });
const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
const p = await b.newPage({ viewport: { width: 960, height: 540 } });
const errors = []; p.on('pageerror', (e) => errors.push(e.stack));
await p.goto(pathToFileURL(join(root, 'dist/index.html')).href + '?q=low');
await p.waitForFunction(() => window.__ready, null, { timeout: 300000 });
await p.evaluate(() => { document.getElementById('enter').onclick(); window.__G.running = false; }); // the test drives time itself
let fails = 0;
// times into the cutscene to grab: one per shot (shots are 9, 7, 7.5, 7, 4.2, 4.6 s long)
const marks = [5, 12, 20, 29, 34, 38.5];
let t = 0;
for (const [i, m] of marks.entries()) {
  await p.evaluate((d) => window.__advance(d), m - t); t = m;
  await p.waitForTimeout(700);
  await p.screenshot({ path: join(out, `cine_${i + 1}.png`) });
  console.log('shot', i + 1, await p.evaluate(() => document.getElementById('subs').textContent));
}
await p.evaluate(() => window.__advance(3));
const after = await p.evaluate(() => ({ cut: !!window.__G.cutscene, pos: [window.__P.pos.x.toFixed(2), window.__P.pos.z.toFixed(2)], chained: window.__G.entry.door.max < 0.2 }));
console.log('after', JSON.stringify(after)); if (after.cut || !after.chained) fails++;
// the box room: push the wardrobe, slide the bolt, go in
const enc = await p.evaluate(() => {
  window.__goto(1.05, 4.85); for (let i = 0; i < 6; i++) window.__walk(3.6, 4.85, 1);
  window.__goto(1.85, 4.7); window.__reach(1.99, 1.38, 5.12); window.__use(); window.__step(5); window.__reach(1.85, 1.2, 5.15); window.__use(); window.__step(120);
  window.__walk(1.75, 4.95, 1); window.__walk(1.72, 5.45, 1.5); window.__walk(1.62, 5.75, 1.5); window.__P.yaw = -1.2; window.__advance(1.5);
  return [window.__P.room, window.__G.flags.foundMarta];
});
console.log('found her', JSON.stringify(enc));
await p.evaluate(() => { window.__G.torch.set(true); window.__advance(5); window.__walk(1.55, 5.85, 1); window.__aim(2.35, 0.7, 5.95); window.__advance(0.3); }); await p.screenshot({ path: join(out, 'marta.png') });
const look = await p.evaluate(() => { if (!window.__G.flags.foundMarta) return ['not found', false]; const a = window.__reach(2.4, 0.75, 5.95); window.__use(); const open = !document.getElementById('doc').classList.contains('hidden'); window.__use(); return [a, open]; });
console.log('look', JSON.stringify(look)); if (!look[1]) fails++;
const tch = await p.evaluate(() => { const a = window.__reach(2.4, 0.75, 5.95); window.__use(); window.__advance(1.2); return a; });
console.log('touch', tch); if (!/Touch/.test(tch || '')) fails++;
await p.screenshot({ path: join(out, 'marta_reach.png') });
await p.evaluate(() => window.__advance(1.2)); await p.screenshot({ path: join(out, 'marta_grab.png') });
await p.evaluate(() => window.__advance(5.6)); 
await p.evaluate(() => window.__advance(2.4)); await p.screenshot({ path: join(out, 'wake.png') });
await p.evaluate(() => window.__advance(2.5)); await p.waitForTimeout(400); await p.screenshot({ path: join(out, 'socko.png') });
const st = await p.evaluate(() => ({ box: document.getElementById('socko').className, socko: window.__G.flags.socko, gone: !window.__G.marta.g.visible, room: window.__P.room, line: document.querySelector('#socko span').textContent }));
console.log('after', JSON.stringify(st)); if (!st.socko || !st.gone) fails++;
console.log(errors.length ? 'ERRORS\n' + errors.join('\n') : 'no errors', `| ${fails} failed`);
await b.close(); process.exit(errors.length || fails ? 1 : 0);
