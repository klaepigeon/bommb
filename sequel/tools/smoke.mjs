// Smoke test for the sequel on game 1's engine. Boots headless and plays the loop through
// the real systems: new game on Veridia → walk to the ship → launch → disable a freighter
// → board it (a game 1 interior: crew fight with game 1 combat) → take crates → airlock →
// jump to Hollow Moon → land (the world rebuilds as Hollow Moon, the player carries over)
// → sell the loot on the black market → refit → back to Veridia (its save reloads).
//   node tools/smoke.mjs [screenshot-dir]
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SHOTS = process.argv[2] || null;
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' | ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
p.on('console', (m) => { if (m.type() === 'error') errs.push('console: ' + m.text().slice(0, 300)); });
await p.goto('file://' + join(ROOT, 'dist/index.html') + '?quick');
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `bs2_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const log = [];
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
// tick the game directly (headless rAF is throttled)
const tick = (n) => run((n) => { for (let i = 0; i < n; i++) R.game.tick(1 / 60); R.game.renderer.render(); }, n);
const closeStory = () => run(() => { for (let i = 0; i < 5; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });

await shot('title');
await p.click('#btnNew');
await p.waitForTimeout(800);
await shot('intro');
await closeStory();
const start = await run(() => ({ planet: R.planet.name, city: R.game.world.cities[0].name, cash: R.game.player.cash, job: !!R.game.jobs.active }));
check(start.planet === 'Earth' && start.city === 'Port Hollow', `new game on ${start.planet} (${start.city})`);
check(start.job, 'first family job accepted');
const aged = await run(() => { const l = R.game.player.look; return { aged: !!l.aged, stubble: l.faceExtra, hair: l.oldOverride.hair[3] }; });
check(aged.aged && aged.stubble, `protagonist ten years older (${aged.stubble}, hair ${aged.hair})`);
// a marker in the Brass Coast's population, to prove its own save comes back later
await run(() => { R.game.pop.people[7].opinion = 77; });
await tick(30);
await shot('pad');

// the safe is a Mastermind PIN pad now: solve one by deduction through the real buttons
const safe = await run(async () => {
  window.__safe = null;
  const s = R.mini.safe({}, (r) => { window.__safe = r; });
  let cands = [];
  for (let n = 0; n < 10000; n++) { const d = String(n).padStart(4, '0').split('').map(Number); if (new Set(d).size === 4) cands.push(d); }
  let guesses = 0;
  while (!s.done && cands.length) {
    const g = cands[0];
    for (const d of g) s.press(String(d));
    s.press('ok'); guesses++;
    const h = s.hist[s.hist.length - 1];
    // keep the codes that would have lit the same lights
    cands = cands.filter((c) => { let a = 0, b = 0; for (let i = 0; i < 4; i++) { if (c[i] === g[i]) a++; else if (c.includes(g[i])) b++; } return a === h.green && b === h.amber; });
  }
  await new Promise((r) => setTimeout(r, 1500));
  return { won: window.__safe, guesses, tries: s.tries, left: cands.length };
});
check(safe.won === true, `cracked the PIN safe by deduction in ${safe.guesses}/${safe.tries} tries`);

// the ship on the pad: the USE action is the ship's menu
const ctx = await run(() => { const pl = R.game.player, w = R.game.world; pl.place(w.pad.sx - 20, w.pad.sy + 30); const a = pl.contextAction(); return a && a.label; });
check(ctx === 'Brass Buzzard', `USE by the ship offers "${ctx}"`);
await run(() => R.game.player.contextAction().fn());
await shot('shipmenu');
// Tav's clamp: pay the release fee, then launch
const clamp = await run(() => {
  R.game.player.cash += 1500;
  [...document.querySelectorAll('.sheet button, .sheet .opt')].find((x) => /Launch \(clamped\)/.test(x.textContent)).click();
  const pay = [...document.querySelectorAll('.sheet button, .sheet .opt')].find((x) => /release fee/.test(x.textContent));
  if (pay) pay.click();
  return BS2.SQ.flags.clamp;
});
check(clamp === 0, 'paid Tav to take the clamp off the ship');
await run(() => { for (let i = 0; i < 5; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') s.querySelector('button').click(); } R.game.player.contextAction().fn(); });
await run(() => [...document.querySelectorAll('.sheet button, .sheet .opt')].find((x) => /^Launch/.test(x.textContent)).click());
await tick(20);
check(await run(() => BS2.SPACE.active), 'launched into space');
await shot('space');
// real physics: let go of the stick with assist off and the ship falls along its orbit
const orbit = await run(() => {
  const S = BS2.SPACE, g = R.game; S.assist = false;
  const d0 = Math.hypot(S.x - S.B.find((b) => b.id === 'earth').x, S.y - S.B.find((b) => b.id === 'earth').y), x0 = S.x, y0 = S.y;
  for (let i = 0; i < 180; i++) g.tick(1 / 60);
  const m = S.B.find((b) => b.id === 'earth'), d1 = Math.hypot(S.x - m.x, S.y - m.y);
  S.assist = true;
  return { moved: Math.round(Math.hypot(S.x - x0, S.y - y0)), d0: Math.round(d0), d1: Math.round(d1), dom: S.g.dom.id };
});
check(orbit.dom === 'earth' && orbit.moved > 50 && Math.abs(orbit.d1 - orbit.d0) < orbit.d0 * 0.3, `in orbit around Earth (moved ${orbit.moved}, altitude held ${orbit.d0}→${orbit.d1})`);

// shoot a freighter until it's disabled (attack held, freighter kept in front)
const disabled = await run(() => {
  const S = BS2.SPACE, g = R.game, f = S.crafts.find((c) => c.kind === 'freighter' && !c.dead);
  for (let i = 0; i < 1500 && !f.disabled; i++) { f.x = S.x + 60; f.y = S.y; f.vx = f.vy = 0; S.a = 0; S.vx = S.vy = 0; g.input.heldA.attack = true; g.tick(1 / 60); }
  g.input.heldA.attack = false; g.renderer.render();
  return f.disabled;
});
check(disabled, 'freighter disabled with the ship\'s guns');
await shot('space_fight');

// board: a game 1 interior with a hostile armed crew
const board = await run(() => {
  const S = BS2.SPACE, g = R.game, f = S.crafts.find((c) => c.disabled && !c.looted);
  S.x = f.x - 30; S.y = f.y; g.input.pressedA.use = true; g.tick(1 / 60);
  const room = g.player.room;
  return { inRoom: !!room && room.b.type === 'freighter', crew: g.actors.list.filter((a) => a.room === room && a.hostile && !a.dead).length };
});
check(board.inRoom, 'boarded: inside the freighter');
check(board.crew >= 3, `${board.crew} armed crew aboard`);
await tick(40);
await shot('board');
// fight through game 1's combat: hit the crew until they're down (a fast test fight)
const fight = await run(() => {
  const g = R.game, room = g.player.room;
  const crew = g.actors.list.filter((a) => a.room === room && a.hostile);
  for (const h of crew) R.combat.damage(h, 500, g.player, 'bullet');
  for (let i = 0; i < 60; i++) g.tick(1 / 60);
  return crew.filter((h) => h.dead || h.down > 0).length;
});
check(fight >= 3, `crew down through game 1 combat (${fight})`);
// take every crate
const took = await run(() => {
  const g = R.game, w = g.world, pl = g.player, room = pl.room; let n = 0;
  for (let y = room.y0; y < room.y0 + room.h; y++) for (let x = room.x0; x < room.x0 + room.w; x++) {
    if (w.o(x, y) !== R.data.O.CRATE) continue;
    pl.place(x * 16 + 8, (y + 1) * 16 + 4);
    const a = pl.contextAction(); if (a && /^Take /.test(a.label)) { a.fn(); n++; }
  }
  return { crates: n, cargo: BS2.SQ.cargo.reduce((s, l) => s + l.n, 0) };
});
check(took.cargo > 0, `took ${took.crates} crates (${took.cargo} units)`);
await shot('board_looted');
// the airlock
await run(() => R.game.interiors.exit());
check(await run(() => BS2.SPACE.active && !R.game.player.room), 'back in space through the airlock');

// set a course for Luna on the System tab, engage cruise, and fly there for real
const cash0 = await run(() => R.game.player.cash);
await run(() => { R.game.ui.closeSheet(); R.game.ui.openMenu('system'); });
await shot('system');
const flight = await run(() => {
  document.querySelector('[data-c="luna"]').click();
  const g = R.game, S = BS2.SPACE;
  g.input.pressedA.run = true; g.tick(1 / 60);
  const cruising = S.cruise; let t = 0, top = 0;
  const x0 = S.x, y0 = S.y;
  // re-engage cruise if it drops out short of Luna (a gravity well on the way)
  while ((S.cruise || !S.g || S.g.near.id !== 'luna') && t < 60 * 400) { g.tick(1 / 60); t++; top = Math.max(top, Math.hypot(S.vx, S.vy)); if (!S.cruise && t % 600 === 0) g.input.pressedA.run = true; }
  return { cruising, secs: Math.round(t / 60), top: Math.round(top), au: +(Math.hypot(S.x - x0, S.y - y0) / 60000).toFixed(2), near: S.g && S.g.near.id, zoom: +S.zoom.toFixed(4) };
});
log.push('flight: ' + JSON.stringify(flight));
check(flight.cruising, 'cruise drive engaged');
check(flight.near === 'luna', `cruised ${flight.au} AU to Luna in ${flight.secs}s (top speed ${flight.top} u/s)`);
await run(() => R.game.renderer.render());
await shot('arrive_luna');
await run(() => { const S = BS2.SPACE, g = R.game, m = S.B.find((b) => b.id === 'luna'); const a = Math.atan2(S.y - m.y, S.x - m.x); S.x = m.x + Math.cos(a) * (m.r + 60); S.y = m.y + Math.sin(a) * (m.r + 60); S.vx = m.vx / 60; S.vy = m.vy / 60; g.input.pressedA.use = true; g.tick(1 / 60); });
await tick(30);
const hollow = await run(() => ({ planet: R.planet.name, city: R.game.world.cities[0].name, space: BS2.SPACE.active, cash: R.game.player.cash }));
check(hollow.planet === 'Luna' && !hollow.space, `landed on ${hollow.planet} (${hollow.city})`);
check(hollow.cash === cash0, `cash carried over ($${hollow.cash})`);
await closeStory();
await shot('hollow');

// sell the stolen cargo at the black market (from the pad)
const sold = await run(() => {
  const g = R.game, pl = g.player, w = g.world, c0 = pl.cash;
  pl.place(w.pad.sx - 20, w.pad.sy + 30);
  g.ui.openMenu('cargo');
  for (let k = 0; k < 80; k++) { const b = document.querySelector('.sw-trade button[data-s]:not([disabled])'); if (!b) break; b.click(); }
  return pl.cash - c0;
});
check(sold > 0, `sold loot on the black market for $${sold}`);
await shot('market');
// refit: fit a smuggler's hold
const fitted = await run(() => {
  const g = R.game; g.player.cash += 2000; g.ui.openMenu('ship');
  document.querySelector('.sw-pal [data-m="hold"]').click();
  const empty = [...document.querySelectorAll('.sw-grid button')].find((c) => !c.querySelector('canvas'));
  empty.click();
  return BS2.SQ.ship.grid.filter((m) => m === 'hold').length;
});
check(fitted > 0, 'fitted a smuggler\'s hold');
await shot('shiptab');
await run(() => R.game.ui.closeSheet());

// Earth: the Brass Coast itself, ten years on, under game 1's own names
const fly = (id) => run((id) => {
  const g = R.game, S = BS2.SPACE; BS2.SQ.course = id;
  g.input.pressedA.run = true; g.tick(1 / 60); let t = 0;
  while ((S.cruise || !S.g || S.g.near.id !== id) && t < 60 * 600) { g.tick(1 / 60); t++; if (!S.cruise && t % 600 === 0) g.input.pressedA.run = true; }
  const m = S.B.find((b) => b.id === id), a = Math.atan2(S.y - m.y, S.x - m.x);
  S.x = m.x + Math.cos(a) * (m.r + 60); S.y = m.y + Math.sin(a) * (m.r + 60); S.vx = m.vx / 60; S.vy = m.vy / 60; g.input.pressedA.use = true; g.tick(1 / 60);
  const lz = document.querySelector('[data-lz="home"]'); if (lz) lz.click();
  return { secs: Math.round(t / 60), arrived: t < 60 * 600, chooser: !!lz };
}, id);
await run(() => BS2.launch(R.game));
const tMars = await fly('mars');
await tick(30);
const mars = await run(() => ({ planet: R.planet.name, city: R.game.world.cities[0].name }));
check(tMars.arrived, `cruised to Mars in ${tMars.secs}s`);
check(mars.planet === 'Mars' && mars.city === 'Olympus Quay', `landed on Mars (${mars.city})`);
await closeStory();
await shot('mars');
await run(() => BS2.launch(R.game));
const tEarth = await fly('earth');
await tick(20);
const home = await run(() => ({ planet: R.planet.name, city: R.game.world.cities[0].name, marker: R.game.pop.people[7].opinion, hold: BS2.SQ.ship.grid.includes('hold') }));
check(tEarth.arrived && tEarth.chooser, `cruised home to Earth in ${tEarth.secs}s and picked the Brass Coast as the landing zone`);
check(home.planet === 'Earth' && home.city === 'Port Hollow' && home.marker === 77, 'back on the Brass Coast: its population came back from its own save');
check(home.hold, 'the refit carried over');
await closeStory();
await tick(30);
await shot('home');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('smoke ok');
