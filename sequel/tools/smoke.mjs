// Smoke test: boot the built page in headless Chromium (phone-sized) and play the v0.1 loop:
// new game → Pad Control → launch → disable and board a freighter → loot → jump to Hollow Moon →
// land → sell at the black market → refit the ship. Fails on any page error or broken step.
//   node tools/smoke.mjs [screenshot-dir]
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SHOTS = process.argv[2] || null;
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 360, height: 780 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' ' + (e.stack || '').split('\n')[1]));
await p.goto('file://' + join(ROOT, 'dist/index.html'));
await p.waitForTimeout(700);
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `bs_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg);
const frames = (n) => run((n) => new Promise((res) => { let k = 0; const f = () => (++k >= n ? res() : requestAnimationFrame(f)); requestAnimationFrame(f); }), n);
// close any dialogue boxes, picking the last (safe) choice
const drain = () => run(() => { const u = BS.ui; for (let i = 0; i < 30 && u.busy(); i++) { const c = document.querySelector('#dialog .choices button:last-child'); if (c) c.click(); else { u.typing = 1e9; u.advance(); } } });
const hold = (x, y, n) => run(([x, y, n]) => new Promise((res) => { const I = BS.input; let k = 0; const f = () => { I.x = x; I.y = y; I.poll = () => {}; if (++k >= n) { delete I.poll; res(); } else requestAnimationFrame(f); }; requestAnimationFrame(f); }), [x, y, n]);
const log = [];
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };

await shot('title');
await p.click('#tNew');
await frames(80);
await shot('intro');
await drain();

// walk a little (collision + animation), then Pad Control
const y0 = await run(() => BS.game.scene.name);
check(y0 === 'planet:veridia', 'starts on Veridia');
await hold(1, 0, 30);
await run(() => { BS.game.complete('talk'); BS.ui.openApp('goals'); });
await frames(5);
await shot('veridia');
log.push('visit: ' + await run(() => BS.game.scene.test.visit()));
await frames(5);
await shot('veridia_town');
await run(() => BS.game.scene.test.terminal());
await frames(5);
await shot('veridia_terminal');

// night on Veridia
await run(() => { BS.game.minutes = Math.floor(BS.game.minutes / 1440) * 1440 + 22 * 60; });
await frames(5);
await shot('veridia_night');
await run(() => { BS.game.minutes = Math.floor(BS.game.minutes / 1440) * 1440 + 10 * 60 + 1440; });

// launch
await run(() => { const g = BS.game; g.complete('launch'); g.go(() => BS.spaceScene(g, 'veridia')); });
await frames(60); await drain();
check(await run(() => BS.game.scene.name) === 'space', 'launched into space');
await hold(1, -0.3, 40);
await run(() => BS.ui.openApp('map'));
await frames(10);
await shot('space');

// put a freighter alongside, shoot it until it's disabled
const disabled = await run(() => new Promise((res) => {
  const g = BS.game, S = BS.spaceState(g);
  const f = S.crafts.find((c) => c.kind === 'freighter' && !c.dead);
  f.x = S.x + 60; f.y = S.y; f.vx = f.vy = 0; S.a = 0; S.vx = S.vy = 0; f.target = 'hollow';
  let k = 0;
  const tick = () => { BS.input.press('b'); f.x = S.x + 60; f.y = S.y; f.vx = f.vy = 0; S.a = 0; if (f.disabled || ++k > 900) { BS.input.release('b'); res(f.disabled); } else requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
}));
check(disabled, 'freighter disabled by gunfire');
await frames(10);
await shot('space_fight');
await drain();

// board it
await run(() => { const g = BS.game, S = BS.spaceState(g); const f = S.crafts.find((c) => c.disabled && !c.looted); g.go(() => BS.boardScene(g, f)); });
await frames(60); await drain();
check(await run(() => BS.game.scene.name) === 'board', 'boarded the freighter');
await shot('board');
// clear the crew and loot every crate (test hooks), then back through the tube
const took = await run(() => { const t = BS.game.scene.test; t.clearCrew(); return t.lootAll(); });
check(took > 0, `looted ${took} crates`);
await frames(5);
await shot('board_looted');
await run(() => BS.game.scene.test.leave());
await frames(60); await drain();
check(await run(() => BS.game.objectives.find((o) => o.id === 'rob').done), 'rob objective done');

// hyperlane jump to Hollow Moon from the map app, then land
await run(() => BS.ui.openApp('map'));
await frames(3);
await run(() => { const b = [...document.querySelectorAll('#jumps button')].find((x) => x.dataset.p === 'hollow'); b.click(); });
await frames(20); await drain();
await shot('space_hollow');
await run(() => { const g = BS.game; g.go(() => BS.planetScene(g, 'hollow', true)); });
await frames(60); await drain();
check(await run(() => BS.game.scene.name) === 'planet:hollow', 'landed on Hollow Moon');
await shot('hollow');
await run(() => BS.game.scene.test.visit());
await frames(5);
await shot('hollow_town');

// sell stolen cargo at the black market
const sold = await run(() => {
  const g = BS.game, c0 = g.credits;
  BS.ui.openApp('market');
  for (let k = 0; k < 60; k++) { const b = document.querySelector('.trade button[data-s]:not([disabled])'); if (!b) break; b.click(); }
  return g.credits - c0;
});
check(sold > 0, `sold loot for ${sold}`);
check(await run(() => BS.game.objectives.find((o) => o.id === 'fence').done), 'fence objective done');
await shot('market');

// refit: pick a shield module and fit it in an empty slot
const fitted = await run(() => {
  const g = BS.game; BS.ui.openApp('ship');
  document.querySelector('.mod[data-m="shield"]').click();
  const empty = [...document.querySelectorAll('.cell')].find((c) => !c.classList.contains('full'));
  if (empty) empty.click(); else document.querySelectorAll('.cell')[5].click();
  return g.ship.grid.filter((m) => m === 'shield').length;
});
check(fitted > 0, 'fitted a deflector');
await shot('shipapp');
await run(() => { BS.game.minutes = Math.floor(BS.game.minutes / 1440) * 1440 + 23 * 60 + 1440; BS.ui.openApp('goals'); });
await frames(5);
await shot('hollow_night');
// save and reload
check(await run(() => { BS.game.save(); return !!localStorage.getItem('rhapsody2.save'); }), 'saved');
await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('smoke ok');
