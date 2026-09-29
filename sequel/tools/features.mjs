// The features test: the brainstorm batch. Market news moving prices, a paint job and a new
// name, a contract taken and delivered, a freighter hailed and shaken down, a distress call,
// a derelict and a solar storm, chrome installed, a street race, the Pit, the pirate radio,
// and the achievements list.
//   node tools/features.mjs [screenshot-dir]
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
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `features_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });
const click = (re) => run((re) => { const b = [...document.querySelectorAll('.sheet button')].find((x) => new RegExp(re).test(x.textContent)); if (b) b.click(); return !!b; }, re);

await p.click('#btnNew');
await p.waitForTimeout(900);
await closeAll();
await run(() => { BS2.SQ.flags.clamp = 0; R.game.player.cash = 100000; R.game.clock.t = Math.floor(R.game.clock.t / 1440) * 1440 + 13 * 60; });

// ---------------------------------------------------------------- the market
const market = await run(() => { const ev = BS2.activeEvents(); return { n: ev.length, text: BS2.headlines()[0] }; });
check(market.n >= 2 && market.text, `market news: "${market.text}"`);

// ---------------------------------------------------------------- paint and name
const paint = await run(() => {
  const g = R.game, w = g.world; g.player.place(w.pad.sx - 20, w.pad.sy + 30);
  const menu = BS2.SQ; const before = menu.ship.paint;
  const opt = document; return before;
});
await run(() => { const g = R.game; const a = g.player.contextAction(); if (a) a.fn(); });
await click('Paint and name'); await click('Repaint'); await click('Miami Pink');
const painted = await run(() => BS2.SQ.ship.paint);
check(painted === '#ff5a9a' && painted !== paint, `repainted the ship Miami Pink (${painted})`);
await closeAll();

// ---------------------------------------------------------------- a contract
const contract = await run(() => {
  const g = R.game, offers = BS2.offers('earth'), c = offers.find((o) => o.kind === 'cargo') || offers[0];
  BS2.takeContract(c);
  const loaded = BS2.SQ.cargo.filter((l) => l.job === c.id).reduce((a, l) => a + l.n, 0);
  const cash0 = g.player.cash;
  BS2.SPACE.active = false; BS2.SQ.mode = 'planet';
  BS2.HOOKS.landed.forEach((h) => h(g, c.to));
  return { name: c.name, loaded, n: c.n, paid: g.player.cash - cash0, pay: c.pay, done: BS2.contracts().find((k) => k.id === c.id).done };
});
check(contract.loaded === contract.n && contract.paid === contract.pay && contract.done, `contract: ${contract.name}, loaded, delivered, paid $${contract.paid}`);
await closeAll();

// ---------------------------------------------------------------- hail a freighter
const hail = await run(() => {
  const g = R.game, S = BS2.SPACE;
  BS2.launch(g); g.ui.closeSheet(); S.crafts = [];
  const c = BS2.spawnCraft('freighter', false, 150);
  c.vx = S.vx; c.vy = S.vy; c.cargo = [{ good: 'rum', n: 6 }];
  const my = BS2.SQ.ship; my.grid = my.grid.map((m) => (m === 'quarters' || m === 'fuel' ? 'gun' : m));
  BS2.SQ.cargo = [];
  const label = BS2.HOOKS.use.map((h) => h(g)).find(Boolean);
  let got = 0;
  for (let k = 0; k < 8 && !got; k++) {
    c.hostile = false; c.looted = false; c.cargo = [{ good: 'rum', n: 6 }];
    BS2.hail(c);
    const bt = [...document.querySelectorAll('.sheet button')].find((x) => /Demand/.test(x.textContent)); if (bt) bt.click();
    got = BS2.SQ.cargo.filter((l) => l.stolen).reduce((a, l) => a + l.n, 0);
  }
  return { label: label && label.label, got };
});
check(hail.label === 'Hail' && hail.got > 0, `hailed a freighter and she dumped ${hail.got} crates`);
await closeAll();

// ---------------------------------------------------------------- space events
const ev = await run(() => {
  const g = R.game, S = BS2.SPACE;
  S.crafts = [];
  BS2.spaceEvent('storm');
  const sh0 = S.shield = 200; for (let i = 0; i < 60; i++) g.tick(1 / 60);
  const drained = sh0 - S.shield;
  BS2.spaceEvent('derelict');
  const der = BS2.eventsTracked().find((t) => t.kind === 'derelict');
  BS2.spaceEvent('sos');
  const sos = BS2.eventsTracked().filter((t) => t.kind === 'sos' || t.kind === 'trap').pop();
  S.x = sos.c.x; S.y = sos.c.y; S.vx = sos.c.vx; S.vy = sos.c.vy;
  for (let i = 0; i < 10; i++) g.tick(1 / 60);
  return { drained: Math.round(drained), derelict: der && der.c.disabled && der.c.cargo.length > 0, sos: sos.kind, done: sos.done, hunters: S.crafts.filter((c) => c.kind === 'hunter' && !c.dead).length };
});
check(ev.drained > 5, `a solar storm drains the shields (${ev.drained} in a second)`);
check(ev.derelict, 'a derelict hauler drifts in, full holds, ready to board');
check(ev.done && (ev.sos === 'sos' || ev.hunters >= 2), `a distress call: ${ev.sos === 'trap' ? `a trap (${ev.hunters} hunters)` : 'a rescue, and a reward'}`);
await shot('events');
await closeAll();

// ---------------------------------------------------------------- chrome
const chrome = await run(() => {
  const g = R.game, pl = g.player;
  BS2.SPACE.active = false; BS2.SQ.mode = 'planet'; BS2.SPACE.crafts = [];
  BS2.travelTo(g, 'earth', true);
  const hp0 = pl.hp = 100; pl.hurt(20, null, 'melee'); const plain = hp0 - pl.hp;
  BS2.install('dermal'); BS2.install('reflex'); BS2.install('arm');
  pl.hp = 100; pl.hurt(20, null, 'melee'); const plated = 100 - pl.hp;
  const clinic = g.world.buildings.find((b) => b && b.type === 'pharmacy');
  const opts = clinic ? g.ui.interiorOptions(clinic).map((o) => o.label) : [];
  return { plain: Math.round(plain), plated: Math.round(plated), installed: BS2.implants(), clinic: opts.filter((o) => /Install|installed/.test(o)).length };
});
check(chrome.installed.length === 3 && chrome.plated < chrome.plain && chrome.clinic === 4, `chrome: ${chrome.installed.join(', ')} installed; a hit that did ${chrome.plain} now does ${chrome.plated}; the clinic sells ${chrome.clinic}`);

// ---------------------------------------------------------------- a street race
const race = await run(() => {
  const g = R.game, pl = g.player;
  const ok = BS2.startRace(200);
  const r = BS2.raceState();
  if (!r) return { ok };
  const inCar = !!pl.inCar;
  const cash0 = pl.cash;
  for (const gt of r.gates) { pl.inCar.x = gt.x * 16 + 8; pl.inCar.y = gt.y * 16 + 8; pl.x = pl.inCar.x; pl.y = pl.inCar.y; g.tick(1 / 60); }
  return { ok, inCar, gates: r.gates.length, won: pl.cash - cash0, done: !BS2.raceState() };
});
check(race.ok && race.inCar && race.done && race.won > 0, `a street race: a borrowed Stallion, ${race.gates} gates, beat Raven, won $${race.won}`);
await closeAll();

// ---------------------------------------------------------------- the Pit
const pit = await run(() => {
  const g = R.game, pl = g.player;
  if (pl.inCar) pl.exitCar();
  const club = g.world.buildings.find((b) => b && b.type === 'club');
  g.interiors.enter(club, 'normal');
  const opt = g.ui.interiorOptions(club).find((o) => /Pit/.test(o.label));
  if (opt) opt.fn();
  let rounds = 0;
  for (let k = 0; k < 4 && BS2.arenaState(); k++) {
    const f = BS2.arenaState(); rounds = f.wave + 1;
    for (const h of f.foes) R.combat.kill(h, pl, 'melee');
    g.tick(1 / 60);
  }
  return { offered: !!opt, rounds, done: !BS2.arenaState(), pit: (BS2.SQ.achieved || {}).pit };
});
check(pit.offered && pit.rounds === 3 && pit.done && pit.pit === 1, `the Pit: three rounds, champion`);
await closeAll();
await run(() => { if (R.game.player.room) R.game.interiors.exit(); });

// ---------------------------------------------------------------- radio and achievements
const radio = await run(() => BS2.patter());
check(typeof radio === 'string' && radio.length > 20, `Radio Free Luna: "${radio.slice(0, 70)}…"`);
const feats = await run(() => {
  const g = R.game;
  for (let i = 0; i < 400; i++) g.tick(1 / 60);
  g.ui.openMenu('status');
  const t = document.querySelector('.sheet') ? document.querySelector('.sheet').textContent : '';
  const got = g.player.stats.feats || {};
  return { listed: /Achievements/.test(t), got: Object.keys(got) };
});
check(feats.listed && feats.got.length >= 2, `achievements: ${feats.got.join(', ')}`);
await shot('status');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('features ok');
