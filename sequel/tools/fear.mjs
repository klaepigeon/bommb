// The Fear Man test: the newest layer. The Road Duster you start in, the blue marker back to
// your ship, the Fear Man as the (old, frail) boss of Earth, rings locked until he's dead,
// his ring and the Sinestro Corps uniform off his body, flying into space on the ring with
// no ship, landing on another world and calling the ship down; then the new ships: NPC
// hulls, a capital ship, missiles and drones; and the XX8X debug menu.
//   node tools/fear.mjs [screenshot-dir]
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
const log = [];
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `fear_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const tick = (n) => run((n) => { for (let i = 0; i < n; i++) R.game.tick(1 / 60); R.game.renderer.render(); }, n);
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });

await p.click('#btnNew');
await p.waitForTimeout(900);
await closeAll();

// ---------------------------------------------------------------- the look and the boss
const start = await run(() => {
  const g = R.game, pl = g.player;
  const don = g.pop.people.find((q) => q.isDon && q.faction === 'Vane');
  return { jacket: pl.style.jacket, shirt: pl.style.shirt, duster: !!pl.look.duster, don: don && g.pop.name(don), xeno: don && don.look.xeno };
});
check(start.jacket === 'duster' && start.shirt === 'tank' && start.duster, `you start in the Road Duster and a black tee (${start.jacket}, ${start.shirt})`);
check(start.xeno !== 'fearman' && /Tav/.test(start.don || ''), `the Brass Coast is run by the Fear Man's man: ${start.don}`);

// rings are locked while he lives
const locked = await run(() => { R.corps.give('red', true); return { owned: R.corps.count(), ring: !!R.game.player.inv.tools.ring }; });
check(locked.owned === 0 && !locked.ring, 'no ring will come to you while the Fear Man lives');

// the clamp comes off: a waypoint to the ship, and his club on the map
const marker = await run(() => { R.game.waypoint = null; R.game.player.cash += 2000; return { pad: !!R.game.world.pad }; });
await run(() => {
  const g = R.game, w = g.world;
  g.player.place(w.pad.sx - 20, w.pad.sy + 30);
  const a = g.player.contextAction(); if (a) a.fn();
});
for (const re of ['Launch \\(clamped\\)', 'release fee']) await run((re) => { if (re === 'release fee') { const pl = R.game.player; pl.place(pl.x - 600, pl.y); } const b = [...document.querySelectorAll('button')].find((x) => new RegExp(re).test(x.textContent)); if (b) b.click(); }, re);
await closeAll();
const wp = await run(() => {
  const g = R.game, w = g.world;
  g.player.place(w.pad.sx - 600, w.pad.sy); g.cam.x = g.player.x; g.cam.y = g.player.y;
  g.tick(1 / 60); g.renderer.render();
  return { clamp: BS2.SQ.flags.clamp, wp: g.waypoint && Math.round(g.waypoint.x) === Math.round(w.pad.sx) };
});
check(marker.pad && wp.clamp === 0 && wp.wp, `paying the fee frees the ship and sets a waypoint to its pad (${JSON.stringify(wp)})`);
await shot('marker');

// ---------------------------------------------------------------- the Fear Man dies
const fight = await run(() => {
  // he keeps court in Coast City, one sector north: Hal Jordan's hometown, all in yellow
  const g0 = R.game; BS2.landAt(g0, [12, 9], () => BS2.travelTo(g0, 'earth', true));
  for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } }
  const g = R.game, pl = g.player, p = g.pop.people.find((q) => q.isDon && q.look && q.look.xeno === 'fearman');
  if (!p) return { hp: 999, city: g.world.cities[0].name };
  const a = g.actors.makeHuman(pl.x + 30, pl.y, {}); a.person = p; a.look = p.look;
  g.actors.manage(); // the old man's frailty applies
  const hp = a.maxHp;
  R.combat.kill(a, pl);
  return { city: g.world.cities[0].name, coast: BS2.inCoastCity(), name: g.pop.name(p), hp, dead: BS2.SQ.flags.fearDead, yellow: R.corps.owns('yellow'), ring: !!pl.inv.tools.ring, suit: !!(pl.wardrobe['unlock:fearsuit'] && pl.wardrobe['unlock:scsuit']) };
});
check(fight.city === 'Coast City' && fight.coast && /Fear Man/.test(fight.name || ''), `${fight.name} keeps court in ${fight.city}`);
check(fight.hp <= 45, `he's old and frail: ${fight.hp} health`);
check(fight.dead === 1 && fight.yellow && fight.ring && fight.suit, 'killing him gives you his yellow ring and the Sinestro Corps uniform');
await p.waitForTimeout(700);
await closeAll();

// ---------------------------------------------------------------- ring flight
const lib = await run(() => { R.game.player.will = 100; R.ring.openLibrary(true); const b = document.querySelector('[data-ringfly]'); return { btn: !!b, text: b && b.textContent }; });
check(lib.btn, `the construct menu has "${(lib.text || '').slice(0, 24)}"`);
const fly = await run(() => {
  const g = R.game, shipBefore = BS2.SQ.ship.hull, thrust = BS2.stats(BS2.SQ.ship).thrust;
  document.querySelector('[data-ringfly]').click();
  for (let i = 0; i < 30; i++) g.tick(1 / 60);
  g.renderer.render();
  const skiff = BS2.stats(BS2.SQ.ship);
  return { space: BS2.SPACE.active, ring: !!BS2.SQ.ringFly, parked: BS2.SQ.ringFly && BS2.SQ.ringFly.ship.hull === shipBefore, hull: BS2.SQ.ship.hull, uniform: g.player.style.shirt, starterThrust: skiff.thrust, will: g.player.will };
});
check(fly.space && fly.ring && fly.parked, 'TAKE OFF puts you in space with no ship (yours stays parked)');
check(fly.hull === 'skiff' && fly.uniform === 'sccorps', `you fly at the starter skiff's speed (thrust ${Math.round(fly.starterThrust)}) in the ${fly.uniform} uniform`);
await run(() => { R.game.input.stick.x = 1; for (let i = 0; i < 20; i++) R.game.tick(1 / 60); R.game.renderer.render(); });
await shot('ringflight');
const land = await run(() => {
  const g = R.game;
  g.input.stick.x = 0;
  BS2.SPACE.active = false;
  // land on Mars the way the ship would
  BS2.HOOKS.landed.forEach((h) => h(g, 'mars'));
  BS2.SQ.mode = 'planet';
  BS2.travelTo(g, 'mars', true);
  return { ring: !!BS2.SQ.ringFly, name: BS2.SQ.ship.name, jacket: g.player.style.jacket, here: BS2.shipHere(), loc: BS2.SQ.shipLoc && BS2.SQ.shipLoc.planet };
});
check(!land.ring && land.name === 'Brass Buzzard' && land.jacket === 'duster', `landing takes the uniform off and gives you your ship back (${JSON.stringify(land)})`);
check(!land.here && land.loc === 'earth', 'the ship is still parked on Earth');
const call = await run(() => {
  const g = R.game, w = g.world, pl = g.player;
  pl.place(w.pad.sx - 20, w.pad.sy + 30);
  for (const q of g.actors.list.slice()) if (q !== pl && Math.hypot(q.x - pl.x, q.y - pl.y) < 120) g.actors.remove(q);
  const a = pl.contextAction(); const label = a && a.label; if (a) a.fn();
  return { label, here: BS2.shipHere() };
});
check(/^Call /.test(call.label || '') && call.here, `on Mars, "${call.label}" brings the ship down from Earth`);
await closeAll();

// ---------------------------------------------------------------- the ships
const ships = await run(() => {
  const g = R.game;
  BS2.SQ.flags.clamp = 0;
  BS2.launch(g);
  BS2.SPACE.crafts = [];
  const kinds = ['freighter', 'patrol', 'hunter', 'capital', 'rebel'].map((k) => BS2.spawnCraft(k, false, 300 + Math.random() * 200));
  for (let i = 0; i < 10; i++) g.tick(1 / 60);
  g.renderer.render();
  return kinds.map((c) => `${c.kind}:${c.ship.hull}`);
});
check(ships.length === 5 && /capital:(destroyer|dreadnought)/.test(ships.join(' ')), `NPC ships from the hull catalogue: ${ships.join(', ')}`);
await shot('ships');
const arms = await run(() => {
  const g = R.game, S = BS2.SPACE;
  // a gunship with missile racks and a drone bay
  const sh = BS2.npcShip('capital', Math.random, 'Test', 'frigate');
  sh.grid = sh.grid.map((m, i) => (m === 'plate' || m === 'quarters' || m === 'cryo' ? (i % 2 ? 'missile' : 'drone') : m));
  BS2.SQ.ship = sh; BS2.SQ.hull = BS2.stats(sh).hull;
  S.crafts = [];
  const t = BS2.spawnCraft('hunter', true, 250);
  const hp0 = t.hull + t.shield;
  g.input.held = ((base) => (k) => k === 'attack' || base.call(g.input, k))(g.input.held);
  for (let i = 0; i < 240; i++) g.tick(1 / 60);
  g.renderer.render();
  const st = BS2.stats(sh);
  return { missiles: st.missiles, drones: BS2.WEAPONS.drones.length, hurt: t.dead || t.hull + t.shield < hp0 };
});
check(arms.missiles > 0 && arms.drones > 0 && arms.hurt, `missiles (${arms.missiles} racks) and ${arms.drones} drones take a hunter apart`);
await shot('arms');

// ---------------------------------------------------------------- the debug menu
const dbg = await run(() => {
  R.game.ui.closeSheet(); R.game.ui.openMenu('debug');
  const t = document.body.textContent;
  return { t: t.slice(0, 300), xx: /XX8X/.test(t), fear: /The Fear Man & the rings/.test(t), old: !!document.querySelector('details summary') };
});
check(dbg.xx && dbg.fear && dbg.old, 'the Debug tab opens on the XX8X tools, game 1\'s folded underneath' + (dbg.xx ? '' : dbg.t));
await shot('debug');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('fear ok');
