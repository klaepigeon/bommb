// The frontier test: aliens, ecosystems, stations and the belt, the Imperial bounty, and the
// jump drive, each driven through the real game (ticks, the USE button, menus, minigames).
//   node tools/frontier.mjs [screenshot-dir]
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
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `fr_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const tick = (n) => run((n) => { for (let i = 0; i < n; i++) R.game.tick(1 / 60); R.game.renderer.render(); }, n);
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });
// fly: from the ground, launch, park beside a body at its speed, and press USE
const landOn = (id) => run((id) => {
  const g = R.game, S = BS2.SPACE;
  if (!S.active) BS2.launch(g);
  g.tick(1 / 60);
  const m = S.B.find((b) => b.id === id), a = Math.random() * 6.28;
  S.x = m.x + Math.cos(a) * (m.r + 60); S.y = m.y + Math.sin(a) * (m.r + 60); S.vx = m.vx / 60; S.vy = m.vy / 60; S.cruise = false;
  g.input.pressedA.use = true; g.tick(1 / 60);
  for (let i = 0; i < 30; i++) g.tick(1 / 60);
  return { planet: R.planet.name, space: S.active };
}, id);
const choiceClick = (re) => run((re) => { const b = [...document.querySelectorAll('.sheet button, .sheet .opt')].find((x) => new RegExp(re).test(x.textContent)); if (b) b.click(); return !!b; }, re);

await p.click('#btnNew');
await p.waitForTimeout(800);
await closeAll();
await run(() => { R.game.player.cash = 50000; });

// ---------------------------------------------------------------- aliens on Luna
const luna = await landOn('luna');
await closeAll();
check(luna.planet === 'Luna' && !luna.space, 'landed on Luna');
const pop = await run(() => {
  const ps = R.game.pop.people.filter((p) => p.alive !== false);
  const by = {}; for (const p of ps) if (p.look && p.look.xeno) by[p.look.xeno] = (by[p.look.xeno] || 0) + 1;
  return { n: ps.length, by, named: ps.filter((p) => p._xeno).slice(0, 3).map((p) => R.game.pop.name(p)) };
});
check((pop.by.grey || 0) > 10 && (pop.by.choir || 0) > 10, `Luna's population includes ${pop.by.grey} Greys and ${pop.by.choir} of the Choir (e.g. ${pop.named.join(', ')})`);
// meet a Grey broker: stand next to one and use the context action
const grey = await run(() => {
  const g = R.game, pl = g.player;
  const h = g.actors.makeHuman(pl.x + 12, pl.y, { look: null });
  const grey = BS2.SPECIES.grey; h.look.xeno = 'grey'; h.look.oldOverride = { skin: ['#5a6268', '#8a969c', '#a8b4bc', '#d8e0e8'], style: 'bald' }; h.look.old = null;
  const a = pl.contextAction();
  const line = R.dialog.line('greet', h);
  return { label: a && a.label, line, isGrey: grey.lines.includes(line) };
});
check(/^Trade with/.test(grey.label || ''), `USE next to a Grey offers "${grey.label}"`);
check(grey.isGrey, `the Grey speaks for itself: "${grey.line}"`);
await run(() => R.game.player.contextAction().fn());
await shot('grey_trade');
check(await choiceClick('Buy Xeno-Tech'), 'bought Xeno-Tech from the broker');
check(await run(() => BS2.SQ.cargo.some((l) => l.good === 'xeno' && l.stolen)), 'Xeno-Tech is aboard, flagged as contraband');
await tick(20);
await shot('luna_aliens');

// ---------------------------------------------------------------- Europa: first contact
await run(() => { BS2.launch(R.game); R.game.tick(1 / 60); });
const contact = await run(async () => {
  const g = R.game, S = BS2.SPACE, m = S.B.find((b) => b.id === 'europa');
  S.x = m.x + m.r + 80; S.y = m.y; S.vx = m.vx / 60; S.vy = m.vy / 60;
  g.input.pressedA.use = true; g.tick(1 / 60);
  const st = BS2.CONTACT.st;
  if (!st) return { opened: false };
  // watch each phrase, then play it back
  for (let guard = 0; guard < 20 && !st.done; guard++) { st.show = 0; const seq = st.seq.slice(); for (const t of seq) st.press(String(t)); }
  await new Promise((r) => setTimeout(r, 1800));
  return { opened: true, contact: BS2.SQ.flags.europa, pearls: BS2.SQ.cargo.filter((l) => l.good === 'pearls').reduce((s, l) => s + l.n, 0) };
});
check(contact.opened, 'scanning Europa opens a channel');
check(contact.contact === 1 && contact.pearls >= 3, `first contact with the Europans (${contact.pearls} Song-Pearls)`);
await closeAll();

// ---------------------------------------------------------------- stations: the Red Velvet Orbital
const casino = await run(() => {
  const g = R.game, S = BS2.SPACE, st = BS2.STATIONS.sol[0], q = BS2.stationPos(st);
  S.x = q.x + 30; S.y = q.y; S.vx = q.vx / 60; S.vy = q.vy / 60;
  const a = g.player.contextAction();
  g.input.pressedA.use = true; g.tick(1 / 60);
  for (let i = 0; i < 20; i++) g.tick(1 / 60);
  const room = g.player.room;
  return { label: a && a.label, inside: !!room && room.b.type === 'casino', people: room ? g.actors.list.filter((h) => h.room === room).length : 0 };
});
check(casino.label === 'Dock', 'USE by the Red Velvet Orbital offers "Dock"');
check(casino.inside, `docked: inside the orbital casino (${casino.people} people aboard)`);
await tick(30);
await shot('casino');
await run(() => R.game.interiors.exit());
check(await run(() => BS2.SPACE.active && !R.game.player.room), 'undocked back into space');

// ---------------------------------------------------------------- the belt: mine a rock
const mine = await run(() => {
  const g = R.game, S = BS2.SPACE, ceres = S.B.find((b) => b.id === 'ceres');
  S.x = ceres.x + 3000; S.y = ceres.y; S.vx = S.vy = 0; S.cruise = false;
  for (let i = 0; i < 40; i++) g.tick(1 / 60);
  const bs = BS2.beltState();
  const rock = bs.rocks.slice().sort((a, b) => Math.hypot(a.x - S.x, a.y - S.y) - Math.hypot(b.x - S.x, b.y - S.y))[0];
  if (!rock) return { inBelt: BS2.inBelt(), rocks: 0 };
  const ore0 = BS2.SQ.cargo.filter((l) => ['ore', 'ice', 'plat'].includes(l.good)).reduce((s, l) => s + l.n, 0);
  // park beside it, nose on, and fire until it cracks
  for (let i = 0; i < 1200 && !bs.broken.has(rock.key); i++) { S.x = rock.x - rock.r - 50; S.y = rock.y; S.vx = S.vy = 0; S.a = 0; g.input.heldA.attack = true; g.tick(1 / 60); }
  g.input.heldA.attack = false;
  const cracked = bs.broken.has(rock.key);
  // sweep through the pieces
  for (let i = 0; i < 400; i++) { const c = BS2.beltState().chunks[0]; if (!c) break; S.x = c.x; S.y = c.y; S.vx = S.vy = 0; g.tick(1 / 60); }
  const ore1 = BS2.SQ.cargo.filter((l) => ['ore', 'ice', 'plat'].includes(l.good)).reduce((s, l) => s + l.n, 0);
  g.renderer.render();
  return { inBelt: BS2.inBelt(), rocks: bs.rocks.length + 1, cracked, got: ore1 - ore0, good: rock.good };
});
check(mine.inBelt && mine.rocks > 3, `in the asteroid belt among ${mine.rocks} rocks`);
check(mine.cracked, `cracked a ${mine.good} rock with the guns`);
check(mine.got > 0, `scooped up ${mine.got} units of the pieces`);
await shot('belt');
// the assay station buys it
const assay = await run(() => {
  const g = R.game, S = BS2.SPACE, st = BS2.STATIONS.sol[1], q = BS2.stationPos(st), c0 = g.player.cash;
  S.x = q.x + 20; S.y = q.y; S.vx = q.vx / 60; S.vy = q.vy / 60;
  g.input.pressedA.use = true; g.tick(1 / 60);
  const opts = [...document.querySelectorAll('.sheet button, .sheet .opt')].filter((x) => /^Sell /.test(x.textContent) && !/\(0\)/.test(x.textContent));
  for (const o of opts.slice(0, 1)) o.click();
  return { sold: g.player.cash - c0, menu: !!opts.length };
});
check(assay.menu && assay.sold > 0, `sold the haul at the Haulyard Assay Station for $${assay.sold}`);
await closeAll();

// ---------------------------------------------------------------- Ceres, and its wildlife
const cer = await landOn('ceres');
await closeAll();
check(cer.planet === 'Ceres', 'landed on Ceres (ice world, lawless)');
const eco = await run(() => {
  const g = R.game, pl = g.player, w = g.world;
  // walk out of town so the wild things come
  const s = w.findNear((pl.x / 16) | 0, (pl.y / 16) | 0, 40, 90, (x, y) => !w.solidPed(x, y) && w.cityAt(x, y) === null);
  if (s) pl.place(s.x * 16 + 8, s.y * 16 + 8);
  for (let i = 0; i < 60 * 20; i++) g.tick(1 / 60);
  const an = g.actors.list.filter((a) => a.kind === 'a' && !a.dead);
  return { types: [...new Set(an.map((a) => a.def.name))], game1: an.filter((a) => !a.def.fauna).map((a) => a.def.name) };
});
check(eco.types.length > 0 && !eco.game1.filter((n) => !/Frost|Claim|Ice|Tunnel/.test(n)).length, `Ceres wildlife only: ${eco.types.join(', ')}`);
await shot('ceres');
// the food chain: kill off the predators and the grazers boom, then strip the land
const chain = await run(() => {
  const e = BS2.eco('ceres'); Object.assign(e, { prey: 60, pred: 12, land: 1 });
  const before = { prey: Math.round(e.prey), pred: Math.round(e.pred) };
  e.pred = 0.5;
  for (let d = 0; d < 10; d++) BS2.stepEco(e);
  return { before, prey: Math.round(e.prey), pred: Math.round(e.pred * 10) / 10, land: Math.round(e.land * 100) / 100 };
});
check(chain.prey > chain.before.prey && chain.land < 1, `no predators: grazers ${chain.before.prey} → ${chain.prey}, land ${chain.land}`);

// ---------------------------------------------------------------- the bounty
await run(() => { BS2.SQ.bounty = 1200; BS2.huntersNow(); for (let i = 0; i < 30; i++) R.game.tick(1 / 60); });
const ground = await run(() => BS2.hunted().map((h) => h.strangerName));
check(ground.length >= 2, `bounty hunters on the ground: ${ground.join(', ')}`);
await tick(10);
await shot('hunters');
// clear them, then go to space and meet one there
await run(() => { for (const h of BS2.hunted()) R.combat.damage(h, 500, R.game.player, 'bullet'); for (let i = 0; i < 30; i++) R.game.tick(1 / 60); });
const space = await run(() => {
  const g = R.game; BS2.launch(g); g.tick(1 / 60); BS2.huntersNow();
  for (let i = 0; i < 20; i++) g.tick(1 / 60);
  const h = BS2.SPACE.crafts.find((c) => c.kind === 'hunter');
  if (!h) return { hunter: false };
  // it shoots you down to 20% and docks
  BS2.SQ.hull = 5; h.x = BS2.SPACE.x + 60; h.y = BS2.SPACE.y;
  for (let i = 0; i < 5; i++) g.tick(1 / 60);
  const room = g.player.room;
  return { hunter: true, name: h.name, boarded: !!room, crew: room ? g.actors.list.filter((a) => a.room === room && a.hostile && !a.dead).length : 0 };
});
check(space.hunter, `a bounty hunter's gunship in space (${space.name})`);
check(space.boarded && space.crew >= 2, `boarded by ${space.crew} of their crew`);
await tick(20);
await shot('boarded');
const repel = await run(() => {
  const g = R.game, room = g.player.room;
  for (const h of g.actors.list.filter((a) => a.room === room && a.hostile)) R.combat.damage(h, 500, g.player, 'bullet');
  for (let i = 0; i < 30; i++) g.tick(1 / 60);
  g.interiors.exit();
  return { space: BS2.SPACE.active, bounty: BS2.SQ.bounty };
});
check(repel.space, 'repelled the boarders and got back to the cockpit');
await closeAll();
// the court on Venus: pay it off
const court = await landOn('venus');
await closeAll();
check(court.planet === 'Venus', 'landed on Venus');
await run(() => { const pl = R.game.player, w = R.game.world; pl.place(w.pad.sx - 20, w.pad.sy + 30); pl.contextAction().fn(); });
check(await choiceClick('Imperial Court'), 'the ship menu on Venus offers the Imperial Court');
await shot('court');
check(await choiceClick('^Pay it'), 'paid the bounty');
check(await run(() => BS2.SQ.bounty === 0), 'the bounty is cleared');
await closeAll();

// ---------------------------------------------------------------- the jump drive
await run(() => {
  const g = R.game, pl = g.player, w = g.world; pl.place(w.pad.sx - 20, w.pad.sy + 30);
  const s = BS2.SQ.ship; s.hull = 'freighter'; s.grid = new Array(45).fill(null);
  const set = (x, y, m) => { s.grid[y * 9 + x] = m; };
  set(8, 2, 'cockpit'); set(0, 1, 'engine'); set(0, 2, 'engine'); set(0, 3, 'engine'); set(1, 2, 'reactor'); set(2, 2, 'reactor'); set(1, 1, 'reactor');
  set(3, 2, 'jump'); set(4, 2, 'cargo'); set(5, 2, 'fuel'); set(6, 2, 'fuel'); set(7, 1, 'gun'); set(7, 3, 'gun'); set(4, 1, 'tube'); set(4, 3, 'tractor'); set(5, 1, 'shield');
  BS2.SQ.hull = -1; BS2.SQ.fuel = 6;
});
const out = await run(() => {
  const g = R.game, S = BS2.SPACE; BS2.launch(g); g.tick(1 / 60);
  const near = BS2.clearSpace();
  // out past the asteroid belt, into clear space
  const a = Math.atan2(S.y, S.x); S.x = Math.cos(a) * 5 * 60000; S.y = Math.sin(a) * 5 * 60000 + 30000; S.vx = S.vy = 0;
  g.tick(1 / 60);
  return { near: near.why, clear: BS2.clearSpace() };
});
check(!!out.near && out.clear.ok, `jump drive refuses near a world ("${out.near}") and is clear at 5 AU`);
await run(() => R.game.ui.openMenu('system'));
await shot('jump_menu');
const jump = await run(() => {
  const b = document.querySelector('[data-j="centauri"]');
  if (!b || b.disabled) return { button: !!b, disabled: b && b.disabled };
  b.click();
  for (let i = 0; i < 30; i++) R.game.tick(1 / 60);
  return { button: true, system: BS2.SQ.system, sun: R.game && BS2.SPACE.B.find((x) => x.id === 'sun') && BS2.SQ.system, worlds: Object.keys(BS2.genSystem('centauri').planets) };
});
check(jump.system === 'centauri', `jumped to Alpha Centauri (inhabited: ${jump.worlds && jump.worlds.join(', ')})`);
await closeAll();
await tick(10);
await shot('centauri');
const alien = await landOn(jump.worlds[0]);
await closeAll();
const world = await run(() => {
  const g = R.game, ps = g.pop.people;
  const xs = ps.filter((p) => p.look && p.look.xeno);
  return { planet: R.planet.name, city: g.world.cities[0].name, aliens: xs.length, kinds: [...new Set(xs.map((p) => BS2.SPECIES[p.look.xeno].plural))], total: ps.length };
});
check(!alien.space && world.aliens > 20, `landed on ${world.planet} (${world.city}): ${world.aliens} of ${world.total} people are ${world.kinds.join(' and ')}`);
await tick(30);
await shot('alien_world');
// and home again
const home = await run(() => {
  const g = R.game, S = BS2.SPACE; BS2.launch(g); g.tick(1 / 60);
  for (let k = 0; k < 16; k++) { const a = k * 0.4; S.x = Math.cos(a) * 3.2 * 60000; S.y = Math.sin(a) * 3.2 * 60000; S.vx = S.vy = 0; g.tick(1 / 60); if (BS2.clearSpace().ok) break; }
  const why = BS2.clearSpace().why, ok = BS2.jump(g, 'sol');
  return { ok, why, system: BS2.SQ.system, fuel: BS2.SQ.fuel };
});
check(home.ok && home.system === 'sol', `jumped home to Sol (fuel left ${home.fuel})${home.ok ? '' : ' ' + home.why}`);
await closeAll();
const back = await landOn('mars');
await closeAll();
check(back.planet === 'Mars', 'and landed on Mars again');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('frontier ok');
