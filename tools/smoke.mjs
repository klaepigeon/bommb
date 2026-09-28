// Headless smoke test: boots the built game at phone size, plays for a bit, and
// fails on any page error. Needs Playwright + Chromium available locally.
//   node tools/build.mjs && node tools/smoke.mjs
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch {
  try { ({ chromium } = require('/opt/node22/lib/node_modules/playwright')); } catch { console.log('playwright not installed; skipping'); process.exit(0); }
}
const page = 'file://' + join(dirname(fileURLToPath(import.meta.url)), '..', 'dist', 'index.html') + '?quick';
const browser = await chromium.launch();
const p = await (await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true })).newPage();
const errors = [];
p.on('pageerror', (e) => errors.push(e.message));
await p.goto(page);
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 30000 });
await p.click('#btnNew');
await p.click('#story button');
await p.keyboard.down('KeyD'); await p.waitForTimeout(2000); await p.keyboard.up('KeyD');
const stats = await p.evaluate(() => {
  const g = R.game;
  for (let d = 0; d < 3; d++) g.clock.skip(1440);
  return { people: g.pop.people.filter((x) => x.alive).length, actors: g.actors.list.length, cars: g.traffic.list.length, day: g.pop.day };
});
await p.waitForTimeout(3000);
await browser.close();
console.log(stats);
if (errors.length) { console.error('page errors:\n' + errors.join('\n')); process.exit(1); }
console.log('smoke ok');
