// Game 1 extras: the Phone Man, the dog, the cop's uniform, roadblocks and spike strips,
// hurricanes and the blackout, moonshine, the armored car and mob funerals.
//   node tools/game1x.mjs
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 844, height: 390 } })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' | ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
await p.goto('file://' + join(ROOT, 'dist/rhapsody.html') + '?quick');
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
const log = [];
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
await p.click('#btnNew');
await p.waitForTimeout(1200);
await p.evaluate(() => {
  const g = R.game;
  if (R.opening && R.opening.active && R.opening.skip) R.opening.skip();
  for (let i = 0; i < 8; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } }
  g.ui.closeSheet && g.ui.closeSheet();
  if (g.cutscene) g.cutscene = null;
  if (g.player.room && g.interiors.exit) g.interiors.exit();
  if (R.opening) { R.opening.lock = null; R.opening.active = false; }
  g.cheats = g.cheats || {};
});
// each feature runs on its own, so one failure doesn't hide the rest
const step = async (name, fn) => { try { return await p.evaluate(fn); } catch (e) { errs.push(name + ': ' + e.message); return {}; } };
const helpers = `
  window.T = {
    g: () => R.game,
    clear() { const g = R.game, pl = g.player; for (const q of g.actors.list.slice()) if (q !== pl && Math.hypot(q.x - pl.x, q.y - pl.y) < 200) g.actors.remove(q); g.ui.closeSheet(); if (g.law.incident) g.law.incident = null; },
    tick(n) { for (let i = 0; i < (n || 1); i++) R.game.tick(1 / 60); },
    press(re) { const x = [...document.querySelectorAll('.sheet button, #story button')].find((q) => re.test(q.textContent)); if (x) x.click(); return !!x; },
    tile(pred) { const w = R.game.world, pl = R.game.player; for (let r = 20; r < 600; r *= 1.5) for (let k = 0; k < 20; k++) { const s = w.findNear((pl.x / 16) | 0, (pl.y / 16) | 0, 0, r, pred); if (s) return s; } return null; },
  };`;
await p.evaluate(helpers);

// 1. the Phone Man
let r = await step('phone', () => {
  const g = R.game, pl = g.player, w = g.world, D = R.data, PM = R.phoneman, s = PM.state(), TS = R.TILE;
  T.clear();
  const ph = w.phones.find((q) => w.o(q.x, q.y) === D.O.PHONE && !w.solidPed(q.x, q.y + 1));
  pl.place(ph.x * TS + 8, ph.y * TS + 8 + 12);
  const rang = PM.ringNear();
  const a = pl.contextAction();
  const label = a && a.label;
  s.job = PM.offer(); s.ring = null;
  const job = s.job, person = g.pop.people[job.pid];
  job.style = 'any';
  g.life.spawnPerson(person, pl.x + 20, pl.y);
  R.combat.kill(person.actor, pl, 'bullet');
  const done = !!job.done;
  const cash = pl.cash, b = pl.contextAction(), col = b && b.label;
  if (b) b.fn();
  return { rang, label, done, col, paid: pl.cash - cash };
});
check(r.rang && r.label === 'Answer the ringing phone', `a payphone rings near you: "${r.label}"`);
check(r.done && r.col === 'Feel under the payphone' && r.paid > 0, `do the contract, collect under the phone: +$${r.paid}`);

// 2. the dog
r = await step('dog', () => {
  const g = R.game, pl = g.player;
  T.clear(); R.shark.street().dog = null;
  pl.inv.cons.sandwich = 1;
  const d = g.actors.makeAnimal(pl.x + 14, pl.y, 'dog'); T.tick(1);
  const a = pl.contextAction(), label = a && a.label;
  if (a) a.fn();
  T.press(/./);
  const info = R.dog.info(), own = R.dog.actor();
  pl.place(pl.x + 120, pl.y);
  T.tick(240);
  const dist = own ? Math.hypot(own.x - pl.x, own.y - pl.y) : 999;
  void d;
  return { label, name: info && info.name, comp: !!own, dist: Math.round(dist) };
});
check(r.label === 'Feed the stray' && r.name && r.comp, `feed a stray a sandwich: it's yours (${r.name})`);
check(r.dist < 100, `${r.name} follows you (${r.dist}px behind after 4s)`);

// 3. the uniform
r = await step('uniform', () => {
  const g = R.game, pl = g.player;
  T.clear();
  const cop = g.actors.makeHuman(pl.x + 14, pl.y, { cop: true, role: 'cop' }); T.tick(1);
  cop.down = 999; cop.state = 'down';
  const a = pl.contextAction(), label = a && a.label;
  if (a && label === 'Take the uniform') a.fn();
  const on = !!pl.disguise, shirt = pl.look.oldOverride && pl.look.oldOverride.shirt;
  const st = g.world.buildings.find((b) => b && b.type === 'police');
  const opts = g.ui.interiorOptions(st).map((o) => o.label);
  g.law.crime('murder', pl.x, pl.y, {});
  const blown = !pl.disguise;
  g.law.incident = null;
  return { label, on, shirt: !!shirt, opts: opts.filter((o) => /case file|property room/.test(o)), blown };
});
check(r.label === 'Take the uniform' && r.on && r.shirt, 'take a downed cop\'s uniform and wear it');
check(r.opts && r.opts.length === 2, `in the station, in uniform: ${JSON.stringify(r.opts)}`);
check(r.blown, 'a murder in uniform blows the disguise');

// 4. roadblock and spike strip
r = await step('roadblock', () => {
  const g = R.game, pl = g.player, w = g.world, TS = R.TILE, RB = R.roadblock;
  T.clear();
  const s = T.tile((x, y) => { const f = w.flow[w.idx(x, y)]; return f && !(f & R.FLOW.X) && (f & R.DIRBIT[1]); });
  const v = g.traffic.make('sedan', s.x * TS + 8, s.y * TS + 8, 0, { parked: false, keep: true, locked: false });
  pl.place(v.x, v.y); pl.inCar = v; v.driver = pl;
  g.law.crime('murder', pl.x, pl.y, {});
  const inc = g.law.incident || g.law.startIncident({ type: 'murder', def: g.law.CRIMES.murder, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: true, lvl: 2, bounty: 100 }, null) || g.law.incident;
  if (g.law.incident) g.law.incident.level = Math.max(2, g.law.incident.level);
  const before = g.traffic.list.filter((q) => q.roadblock && !q.removed).length;
  const placed = RB.place();
  const cars = g.traffic.list.filter((q) => q.roadblock && !q.removed).length - before;
  const top = v.model.top;
  RB.spike(v);
  const slowed = v.model.top < top * 0.5;
  const gar = g.world.buildings.find((b) => b && b.type === 'garage');
  const tyres = g.ui.interiorOptions(gar).find((o) => o.label === 'New tyres');
  if (tyres) { pl.cash += 100; tyres.fn(); }
  const fixed = v.model.top === top;
  pl.inCar = null; v.driver = null; g.law.incident = null; void inc;
  return { placed, cars, strips: RB.strips.length, slowed, tyres: !!tyres, fixed };
});
check(r.placed && r.cars === 2 && r.strips > 0, `wanted level 2 in a car: roadblock ahead (${r.cars} cruisers, a spike strip)`);
check(r.slowed && r.tyres && r.fixed, 'the strip shreds your tyres; a garage sells new ones');

// 5. hurricane
r = await step('hurricane', () => {
  const g = R.game, HU = R.hurricane;
  HU.start(2); T.tick(2);
  const storm = g.env.weather.kind === 'storm', black = !!R.blackout;
  const shop = g.world.buildings.find((b) => b && b.type === 'general');
  const reg = g.ui.interiorOptions(shop).find((o) => o.label === 'Clean out the register');
  const cash = g.player.cash; if (reg) reg.fn();
  const took = g.player.cash - cash;
  g.clock.t += 7 * 60; T.tick(200);
  const over = !R.blackout;
  g.law.incident = null;
  return { storm, black, reg: !!reg, took, over, count: HU.state().count };
});
check(r.storm && r.black, 'a hurricane: storm weather, the power goes out');
check(r.reg && r.took > 0, `blackout looting: "Clean out the register" +$${r.took}`);
check(r.over && r.count === 1, 'the wind drops, the lights come back, the papers count the damage');

// 6. moonshine
r = await step('moonshine', () => {
  const g = R.game, pl = g.player, w = g.world, TS = R.TILE, MS = R.moonshine;
  T.clear();
  const inTown = (x, y) => w.cities.some((c) => x >= c.x0 - 8 && x <= c.x1 + 8 && y >= c.y0 - 8 && y <= c.y1 + 8);
  const gen = w.buildings.find((b) => b && b.type === 'general');
  pl.cash += 400;
  const buy = g.ui.interiorOptions(gen); buy.find((o) => o.label === 'Copper still').fn(); buy.find((o) => /Sugar and cornmeal/.test(o.label)).fn();
  const s = T.tile((x, y) => !inTown(x, y) && !w.isWater(x, y) && !w.solidPed(x, y) && !R.data.roadTile[w.t(x, y)]);
  pl.place(s.x * TS + 8, s.y * TS + 8);
  const a = pl.contextAction(), label = a && a.label;
  if (a) a.fn();
  const st = MS.near(pl);
  MS.menu(st); T.press(/Load it with mash/);
  g.clock.t += 60 * 11; MS.t = 0; MS.update(0.1);
  const jugs = st.jugs;
  MS.menu(st); T.press(/Collect the jugs/);
  const bar = w.buildings.find((b) => b && b.type === 'bar');
  const sell = g.ui.interiorOptions(bar).find((o) => /Sell moonshine/.test(o.label));
  const cash = pl.cash; if (sell) sell.fn();
  return { label, st: !!st, jugs, sold: pl.cash - cash };
});
check(r.label === 'Set up the still' && r.st, 'buy a still, set it up out in the country');
check(r.jugs >= 2, `load it with mash; 11 hours later: ${r.jugs} jugs`);
check(r.sold > 0, `a bar buys them out the back: +$${r.sold}`);

// 7. armored car
r = await step('armored', () => {
  const g = R.game, pl = g.player, AR = R.armored;
  T.clear();
  const road = T.tile((x, y) => { const f = g.world.flow[g.world.idx(x, y)]; return f && !(f & R.FLOW.X); });
  pl.place(road.x * R.TILE + 8, road.y * R.TILE + 8);
  const v = AR.spawn(pl);
  if (!v) return { spawned: false };
  g.traffic.damage(v, 5000, pl, true); T.tick(1);
  const survived = !v.wrecked;
  AR.t = 0; AR.update(0.1);
  const dead = v.armored.dead;
  for (const c of v.crew) if (!c.dead) R.combat.kill(c, pl, 'bullet');
  pl.place(v.x + 20, v.y + 20);
  const a = pl.contextAction(), label = a && a.label;
  const cash = pl.cash;
  AR.crack(v, 'pry');
  const inc = g.law.incident && g.law.incident.level;
  g.law.incident = null;
  return { spawned: true, survived, dead, label, took: pl.cash - cash, inc };
});
check(r.spawned && r.survived && r.dead, 'an armored car: it won\'t blow up, but it dies on the road');
check(r.label === 'The back doors' && r.took > 1000 && r.inc >= 3, `crew down, pry the back doors: +$${r.took}, heat ${r.inc}`);

// 8. funeral
r = await step('funeral', () => {
  const g = R.game, pl = g.player, FU = R.funeral, TS = R.TILE;
  T.clear();
  const capo = g.pop.people.find((q) => q.alive && q.role === 'capo' && q.faction && !q.actor);
  capo.alive = false;
  R.bus.emit('person:died', capo, false);
  const f = FU.state().list.find((x) => x.pid === capo.id);
  if (!f) return { booked: false };
  g.pop.day = f.day; g.clock.t = g.pop.day * 1440 + 10 * 60;
  const ch = g.world.buildings[f.bid];
  pl.place(ch.out.x * TS + 8, ch.out.y * TS + 8 + 24);
  FU.t = 0; FU.update(0.1);
  const a = pl.contextAction(), label = a && a.label;
  const guest = f.guestActor;
  const cash = pl.cash; pl.cash += 100;
  FU.respects(f);
  const paid = f.paid;
  if (guest) R.combat.kill(guest, pl, 'bullet');
  FU.t = 0; FU.update(0.1);
  g.clock.t = g.pop.day * 1440 + 14 * 60; FU.t = 0; FU.update(0.1);
  void cash;
  return { booked: true, staged: !!f.staged, label, guest: !!guest, paid, hit: !!f.hit, over: f.over };
});
check(r.booked && r.staged && /funeral/.test(r.label || ''), `a capo dies: the funeral at the church next morning ("${r.label}")`);
check(r.paid && r.guest && r.hit, 'pay respects, and a rival boss attends (and can be hit)');
check(r.over, 'the mourners go home after one');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('game1x ok');
