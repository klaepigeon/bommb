// The roadmap test: the systems that turned XX8X from a crime sim with a ship into a space
// game. Weapon names on the HUD, gore in the future (oil, alien blood, plasma cuts, rail-rifle
// heads, implants ripped out of cyborgs), frontier worlds and a colony, Imperial customs, the
// rebel shipyard (and its cloak), your own orbital base, a recruited crew, and the galaxy chart.
//   node tools/roadmap.mjs [screenshot-dir]
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
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `roadmap_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });
const pick = (re) => run((re) => { const b = [...document.querySelectorAll('.sheet button, #story button')].find((x) => new RegExp(re).test(x.textContent)); if (b) b.click(); return !!b; }, re);

await p.click('#btnNew');
await p.waitForTimeout(900);
await closeAll();
await run(() => { BS2.SQ.flags.clamp = 0; R.game.player.cash = 500000; R.game.clock.t = Math.floor(R.game.clock.t / 1440) * 1440 + 12 * 60; });

// ---------------------------------------------------------------- the HUD knows its weapons
const hud = await run(() => {
  const pl = R.game.player, out = {};
  for (const w of ['colt45', 'machete', 'tommy', 'crossbow', 'revolver']) { pl.giveWeapon(w); pl.weapon = w; out[w] = R.SHORTW[w] || R.data.weapons[w].name.split(' ').pop().toUpperCase(); }
  pl.weapon = 'fists';
  return out;
});
check(!Object.values(hud).includes('FISTS'), `the HUD names every weapon: ${Object.entries(hud).map(([k, v]) => k + '=' + v).join(', ')}`);

// ---------------------------------------------------------------- gore in the future
const gore = await run(() => {
  const g = R.game, pl = g.player, out = { oil: 0, green: 0, cut: 0, burst: 0, torn: 0 };
  const spawn = (xeno) => { const h = g.actors.makeHuman(pl.x + 18, pl.y, {}); if (xeno === 'robot') { h.look = Object.assign({}, h.look, { xeno: 'robot' }); } if (xeno === 'grey') h.look = Object.assign({}, h.look, { xeno: 'grey' }); return h; };
  // a robot leaks oil
  const n0 = g.fx.decals.length, r = spawn('robot');
  pl.weapon = 'revolver'; R.combat.kill(r, pl, 'bullet');
  out.oil = g.fx.decals.slice(n0).filter((d) => /^rgba\(22,22,28/.test(d.c)).length;
  const gr = spawn('grey'), n1 = g.fx.decals.length;
  R.combat.kill(gr, pl, 'bullet');
  out.green = g.fx.decals.slice(n1).filter((d) => /^rgba\(58,154,74/.test(d.c)).length;
  // plasma machete: heads and limbs come off (cauterised)
  pl.giveWeapon('machete'); pl.weapon = 'machete';
  for (let i = 0; i < 20; i++) { const h = spawn(); R.combat.kill(h, pl, 'melee'); if (h.wnd && (h.wnd.headless || h.wnd.armless)) out.cut++; }
  // rail rifle: heads burst
  pl.giveWeapon('rifle'); pl.weapon = 'rifle';
  for (let i = 0; i < 20; i++) { const h = spawn(); R.combat.kill(h, pl, 'bullet'); if (h.wnd && h.wnd.burst) out.burst++; }
  // scatter blaster, point blank: torn apart
  pl.giveWeapon('sawedoff'); pl.weapon = 'sawedoff';
  for (let i = 0; i < 20; i++) { const h = spawn(); R.combat.kill(h, pl, 'bullet'); if (h.wnd && h.wnd.limbs) out.torn++; }
  for (let i = 0; i < 20; i++) g.tick(1 / 60);
  g.renderer.render();
  return out;
});
check(gore.oil > 0 && gore.green > 0, `robots leak oil (${gore.oil} stains), Greys bleed green (${gore.green})`);
check(gore.cut >= 6, `the plasma machete takes heads and limbs: ${gore.cut}/20`);
check(gore.burst >= 4 && gore.torn >= 4, `rail-rifle heads burst (${gore.burst}/20); a sawn-off scatter tears bodies apart (${gore.torn}/20)`);
await shot('gore');
const knife = await run(() => {
  const g = R.game, pl = g.player;
  pl.giveWeapon('knife'); pl.weapon = 'knife';
  const h = g.actors.makeHuman(pl.x + 12, pl.y, {}); h.look = Object.assign({}, h.look, { xeno: 'cyborg' }); R.combat.kill(h, pl, 'melee');
  R.butcher.menu(h);
  const opts = [...document.querySelectorAll('.sheet button')].map((x) => x.textContent);
  const rip = [...document.querySelectorAll('.sheet button')].find((x) => /implants/.test(x.textContent)); if (rip) rip.click();
  return { opts: opts.filter((o) => /implants|organs|head|arms/.test(o)), implants: pl.inv.loot.implant || 0 };
});
check(knife.implants > 0 && knife.opts.some((o) => /organs/.test(o)), `the knife on a cyborg: ${knife.opts.map((o) => o.split(/[A-Z][a-z]+ [a-z]/)[0]).join(' / ')} → ${knife.implants} implant(s)`);
await closeAll();

// ---------------------------------------------------------------- a colony on Io
const colony = await run(() => {
  const g = R.game;
  BS2.travelTo(g, 'io', true);
  const w = g.world; g.player.place(w.pad.sx - 20, w.pad.sy + 30);
  for (let i = 0; i < 5; i++) g.tick(1 / 60);
  const menu = R.game.player.contextAction(); if (menu) menu.fn();
  return { planet: R.planet.name, frontier: !!R.planet.frontier, grade: g.renderer.cv.style.filter || '', camps: w.cities.map((c) => `${c.nbx}x${c.nby}`).join(' ') };
});
check(colony.frontier && /sepia/.test(colony.grade), `Io is a frontier world (${colony.camps}), graded ${colony.grade.slice(0, 24)}…`);
await pick('Found a colony');
await closeAll();
const grown = await run(() => {
  const c = BS2.colonyHere(); if (!c) return null;
  R.game.clock.t += 1440 * 5; BS2.growColonies();
  return { name: c.name, pop: c.pop, bank: c.bank };
});
check(grown && grown.pop > 12 && grown.bank > 0, `founded ${grown && grown.name}: five days on, ${grown && grown.pop} colonists and $${grown && grown.bank} in the treasury`);
await shot('colony');

// ---------------------------------------------------------------- customs, the rebels, a base
const dockAt = (id) => run((id) => {
  const g = R.game, S = BS2.SPACE;
  if (!S.active) BS2.launch(g);
  g.ui.closeSheet();
  const st = BS2.STATIONS.sol.find((s) => s.id === id), q = BS2.stationPos(st);
  S.x = q.x; S.y = q.y; S.vx = q.vx / 60; S.vy = q.vy / 60;
  g.input.pressed = ((base) => { let once = true; return (k) => (k === 'use' && once ? ((once = false), true) : base.call(g.input, k)); })(g.input.pressed);
  g.tick(1 / 60);
  return (document.querySelector('.sheet') || {}).textContent || '';
}, id);
await run(() => { BS2.SQ.cargo.push({ good: 'blasters', n: 3, stolen: true, hidden: false }); BS2.SQ.bounty = 800; BS2.travelTo(R.game, 'earth', true); });
await closeAll();
const customs = await dockAt('customs');
const seized = await run(() => ({ stolen: BS2.SQ.cargo.filter((l) => l.stolen).length, story: (document.querySelector('#story') || {}).textContent || '' }));
check(seized.stolen === 0 && /seized/.test(seized.story), 'Imperial customs seizes stolen cargo in the open hold');
await closeAll();
await dockAt('customs');
await pick('Pay off your bounty');
check(await run(() => BS2.SQ.bounty === 0), 'and takes your bounty, at a markup');
await closeAll();
const yard = await dockAt('freeyard');
check(/no questions/.test(yard) && /Cloaking Field/.test(yard), 'the Free Ganymede Shipyard: fence, transponder, refit (the only cloak), base frames');
await pick('Refit in the drydock');
const refit = await run(() => [...document.querySelectorAll('.sw-pal button')].map((b) => b.title));
check(refit.includes('Cloaking Field'), 'the rebels fit a Cloaking Field in orbit');
await closeAll();
await dockAt('freeyard');
await pick('orbital base frame');
const base = await run(() => {
  const g = R.game, S = BS2.SPACE, e = S.B.find((q) => q.id === 'mars');
  g.ui.closeSheet();
  S.x = e.x + e.r + 400; S.y = e.y; S.vx = e.vx / 60; S.vy = e.vy / 60; g.tick(1 / 60);
  const ok = BS2.buildBase(g);
  return { ok, bases: (BS2.SQ.bases || []).length, nav: BS2.navTargets().filter((n) => n.kind === 'base').map((n) => n.name) };
});
check(base.ok && base.bases === 1 && base.nav.length === 1, `built ${base.nav[0]} over Mars; it's on the nav menu`);
await closeAll();
const baseDock = await run(() => {
  const g = R.game, S = BS2.SPACE, t = BS2.navTargets().find((n) => n.kind === 'base');
  BS2.autopilot(g, t); for (let i = 0; i < 60 * 60 && S.auto; i++) g.tick(1 / 60);
  g.input.pressed = ((base) => { let once = true; return (k) => (k === 'use' && once ? ((once = false), true) : base.call(g.input, k)); })(g.input.pressed);
  g.tick(1 / 60);
  return (document.querySelector('.sheet') || {}).textContent || '';
});
check(/Collect rent/.test(baseDock) && /Stash/.test(baseDock), 'the autopilot flies you home and you dock at your own base');
await shot('base');
await closeAll();

// ---------------------------------------------------------------- crew
const crew = await run(() => {
  const g = R.game, pl = g.player;
  BS2.SPACE.active = false; BS2.SQ.mode = 'planet';
  BS2.travelTo(g, 'luna', true);
  for (let k = 0; k < 40 && !g.actors.list.some((a) => a.kind === 'h' && a.person && !a.person.isDon && a.person.role !== 'cop'); k++) { for (let i = 0; i < 30; i++) g.tick(1 / 60); const c = g.world.cities[k % 5]; g.player.place((c.colX + 2) * 16, (c.rowY + 3) * 16); }
  const h = g.actors.list.find((a) => a.kind === 'h' && !a.dead && a.person && !a.person.isDon && a.person.role !== 'cop' && a.person.age > 18 && a.look && a.look.xeno === 'grey') || g.actors.list.find((a) => a.kind === 'h' && !a.dead && a.person && !a.person.isDon && a.person.role !== 'cop' && a.person.age > 18);
  const t = R.dialog.tree(h), o = t.options.find((x) => /fly with me/.test(x.label));
  const range0 = BS2.stats(BS2.SQ.ship);
  if (o) o.fn();
  const st = BS2.stats(BS2.SQ.ship);
  return { offered: !!o, crew: BS2.crew().map((c) => `${c.name} (${c.species} ${c.role})`), before: range0, after: st };
});
check(crew.offered && crew.crew.length === 1, `recruited ${crew.crew[0]}`);
check(JSON.stringify(crew.before) !== JSON.stringify(crew.after), 'and the ship is better for it');
await closeAll();

// ---------------------------------------------------------------- the galaxy chart
const chart = await run(() => {
  const g = R.game;
  const pad = g.world.pad; g.player.place(pad.sx - 20, pad.sy + 30);
  g.ui.openMenu('system');
  const cv = document.querySelector('.sw-chart');
  return { chart: !!cv, stars: R.data && window.BS2 && document.querySelectorAll('#swjump button').length };
});
check(chart.chart, 'the System tab carries a galaxy chart');
await shot('chart');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('roadmap ok');
