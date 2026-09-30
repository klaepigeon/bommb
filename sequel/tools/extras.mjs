// The XX8X extras test: game 1's newer systems in the future's words; skimming a gas giant for
// jump fuel; proximity mines; a convoy escort through two raids; a void leviathan (its song
// recorded and sold on Luna, then harpooned and harvested); a tithe barge cracked; passengers
// carried and a fugitive's hunter; a riot on Earth; the curfew and its drones.
//   node tools/extras.mjs
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 844, height: 390 } })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' | ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
p.on('console', (m) => { if (m.type() === 'error') errs.push('console: ' + m.text().slice(0, 300)); });
await p.goto('file://' + join(ROOT, 'dist/index.html') + '?quick');
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
const log = [];
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const closeAll = () => p.evaluate(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });
// each step runs on its own, so one failure doesn't hide the rest
const step = async (name, fn) => { try { const r = await p.evaluate(fn); await closeAll(); return r || {}; } catch (e) { errs.push(name + ': ' + e.message.split('\n')[0]); await closeAll().catch(() => {}); return {}; } };

await p.click('#btnNew');
await p.waitForTimeout(900);
await closeAll();
await p.evaluate(() => {
  BS2.SQ.flags.clamp = 0; R.game.player.cash = 100000; R.game.clock.t = Math.floor(R.game.clock.t / 1440) * 1440 + 13 * 60;
  window.T = {
    // dismiss any story or menu a timer opened (they pause the game)
    shut() { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } if (R.game.ui.paused()) R.game.ui.closeSheet(); },
    ticks(n) { for (let i = 0; i < n; i++) { if (i % 20 === 0) T.shut(); R.game.tick(1 / 60); } },
    press(re) { const x = [...document.querySelectorAll('.sheet button, #story button')].find((q) => re.test(q.textContent)); if (x) x.click(); return !!x; },
    use() { const g = R.game; for (const h of BS2.HOOKS.use) { const u = h(g); if (u) return u; } return null; },
    space() { const g = R.game; if (!BS2.SPACE.active) BS2.launch(g); g.ui.closeSheet(); BS2.SPACE.crafts = []; BS2.SQ.hull = 9999; BS2.SPACE.cruise = false; BS2.SPACE.auto = null; },
    ground() { const g = R.game; BS2.SPACE.active = false; BS2.SQ.mode = 'planet'; BS2.SPACE.crafts = []; if (BS2.SQ.planet !== 'earth') BS2.travelTo(g, 'earth', true); g.ui.closeSheet(); if (g.law.incident) g.law.incident = null; },
    inCity() { const g = R.game, c = g.world.cities[0], w = g.world; const s = w.findNear(c.cx, c.cy, 0, 6, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y)) || { x: c.cx, y: c.cy }; g.player.place(s.x * 16 + 8, s.y * 16 + 8); return c; },
  };
});

// 1. game 1's systems, in the future's words
let r = await step('retheme', () => {
  const g = R.game;
  const said = BS2.say('The armored car went past the payphone. HURRICANE Agnes. 3 jugs of moonshine, and the Revenuers.');
  const gen = g.world.buildings.find((b) => b && b.type === 'general');
  const labels = g.ui.interiorOptions(gen).map((o) => o.label);
  return { said, still: labels.find((l) => /still/i.test(l)) };
});
check(/credit hauler/.test(r.said) && /vid-phone/.test(r.said) && /ACID MONSOON/.test(r.said) && /synth-shine/.test(r.said) && /Excise men/.test(r.said), `re-themed: "${r.said}"`);
check(r.still === 'Synth-still', `the Synth-Mart sells a "${r.still}"`);
r = await step('storms', () => {
  const g = R.game, HU = R.hurricane;
  HU.start(1); T.ticks(3);
  const earth = !!R.blackout;
  g.clock.t += 6 * 60; T.ticks(200);
  return { earth, over: !R.blackout };
});
check(r.earth && r.over, 'acid monsoons still hit Earth (blackout, then the power back)');

// 2. skimming Jupiter
r = await step('scoop', () => {
  const g = R.game, S = BS2.SPACE; T.space();
  const j = S.B.find((q) => q.id === 'jupiter');
  S.x = j.x + j.r * 1.08; S.y = j.y; S.vx = j.vx / 60; S.vy = j.vy / 60; S.shield = 50;
  BS2.SQ.fuel = 0;
  const hull0 = BS2.SQ.hull;
  for (let i = 0; i < 60 * 9; i++) { const jj = S.B.find((q) => q.id === 'jupiter'); if (jj) { S.x = jj.x + jj.r * 1.08; S.y = jj.y; } g.tick(1 / 60); }
  return { world: BS2.SKIM.world, fuel: BS2.SQ.fuel, shield: Math.round(S.shield), hurt: hull0 > BS2.SQ.hull };
});
check(r.world === 'Jupiter' && r.fuel >= 1, `skimming ${r.world}'s cloud tops: ${r.fuel} jump cell(s) in 9 s`);
check(r.shield === 0 && r.hurt, 'the turbulence strips the shields, then works on the hull');

// 3. mines
r = await step('mines', () => {
  const g = R.game, S = BS2.SPACE; T.space();
  S.x += 40000; S.vx = S.vy = 0;
  BS2.SQ.flags.mines = 0;
  // buy a rack from the ship menu's chandler
  const opt = BS2.SHIP_MENU.map((f) => f(g)).find((o) => o && /mines/.test(o.label));
  opt.fn(); T.press(/Buy 4 mines/);
  const bought = BS2.SQ.flags.mines;
  const nav = BS2.HOOKS.navExtra.map((h) => h(g)).find((o) => o && /Drop a mine/.test(o.label));
  nav.fn();
  const m = BS2.MINES[BS2.MINES.length - 1];
  S.x += 300;
  T.ticks(120);
  const h = BS2.spawnCraft('hunter', true, 0); h.x = m.x + 10; h.y = m.y; h.vx = m.vx; h.vy = m.vy; h.shield = 0;
  const hull0 = h.hull;
  T.ticks(2);
  return { bought, left: BS2.SQ.flags.mines, blown: m.life <= 0, dmg: hull0 - (h.dead ? 0 : h.hull), label: nav.label, dbg: JSON.stringify({ arm: m.arm, life: m.life, d: Math.hypot(h.x - m.x, h.y - m.y), hull0, hull: h.hull, dead: h.dead, n: S.crafts.length }) };
});
check(r.bought === 4 && r.left === 3, `bought 4 proximity mines; "${r.label}" from the nav menu`);
check(r.blown && r.dmg >= 60, `a hunter drifts onto it: boom (${r.dmg} hull) ${r.blown && r.dmg >= 60 ? '' : r.dbg}`);

// 4. a convoy
r = await step('convoy', () => {
  const g = R.game, S = BS2.SPACE; T.space();
  const e = S.B.find((q) => q.id === 'earth');
  S.x = e.x + 5000; S.y = e.y; S.vx = e.vx / 60; S.vy = e.vy / 60;
  const cv = BS2.spawnConvoy(); if (!cv) return { spawned: false };
  S.x = cv.c.x + 60; S.y = cv.c.y;
  const u = T.use(); const label = u && u.label; if (u) u.fn(); T.press(/Take the job/);
  const on = cv.state === 'on';
  const w = S.B.find((q) => q.id === cv.to);
  // halfway in: the raiders come
  const mid = (w.r + cv.start) * 0.5, a = Math.atan2(cv.c.y - w.y, cv.c.x - w.x);
  cv.c.x = w.x + Math.cos(a) * mid; cv.c.y = w.y + Math.sin(a) * mid;
  T.ticks(3);
  const raiders = cv.raiders.length;
  for (const q of cv.raiders) { q.dead = true; }
  const cash = g.player.cash;
  cv.c.x = w.x + Math.cos(a) * (w.r + 100); cv.c.y = w.y + Math.sin(a) * (w.r + 100);
  T.ticks(2);
  return { spawned: true, label, on, raiders, paid: g.player.cash - cash, done: BS2.CONVOY.done, pay: cv.pay };
});
check(r.spawned && r.label === 'Escort' && r.on, 'a freighter calls for an escort; USE: take the job');
check(r.raiders >= 2, `raiders jump her on the way in (${r.raiders})`);
check(r.done === 1 && r.paid === r.pay + r.raiders * 150, `she lands safe: ${r.paid} (${r.pay} + a bonus per raider)`);

// 5. a leviathan
r = await step('leviathan', () => {
  const g = R.game, S = BS2.SPACE; T.space();
  BS2.SQ.cargo = [];
  const w = BS2.spawnWhale(250); w.vx = S.vx; w.vy = S.vy;
  const u = T.use(); const label = u && u.label; if (u) u.fn();
  for (let i = 0; i < 60 * 13; i++) { S.x = w.x + w.r + 150; S.y = w.y; S.vx = w.vx; S.vy = w.vy; g.tick(1 / 60); }
  const recorded = w.recorded, songs = BS2.SQ.flags.songs;
  const cash = g.player.cash;
  BS2.HOOKS.landed.forEach((h) => h(g, 'luna'));
  const sold = g.player.cash - cash;
  // then the harpoon
  let n = 0; while (!w.dead && n++ < 50) BS2.HOOKS.shot.forEach((h) => h(w.x, w.y, 40));
  const angry = w.angry >= 0;
  S.x = w.x; S.y = w.y;
  const hv = T.use(); const hl = hv && hv.label; if (hv) hv.fn();
  const pearls = BS2.SQ.cargo.filter((l) => l.good === 'pearls').reduce((a, l) => a + l.n, 0);
  return { label, recorded, songs, sold, dead: w.dead, angry, hl, pearls };
});
check(r.label === 'Record its song' && r.recorded && r.songs === 1, 'a void whale: hold station alongside and record its song');
check(r.sold === 900, `Radio Free Luna buys the tape (${r.sold})`);
check(r.dead && r.hl === 'Harvest' && r.pearls >= 6, `harpooned; the carcass gives up ${r.pearls} void pearls`);

// 6. the tithe barge
r = await step('tithe', () => {
  const g = R.game, S = BS2.SPACE; T.space();
  const c = BS2.spawnBarge();
  const big = c.maxHull;
  BS2.hitCraft(g, c, 1); T.ticks(2);
  const escorts = S.crafts.filter((q) => q.kind === 'patrol' && !q.dead).length;
  c.shield = 0; while (!c.disabled && !c.dead) BS2.hitCraft(g, c, 20);
  S.x = c.x + 30; S.y = c.y; S.vx = c.vx; S.vy = c.vy;
  const u = T.use(); const label = u && u.label;
  const cash = g.player.cash, bounty = BS2.SQ.bounty;
  if (u) u.fn();
  return { big, escorts, disabled: c.disabled, label, took: g.player.cash - cash, bounty: BS2.SQ.bounty - bounty };
});
check(r.big >= 300 && r.escorts === 2, `a tithe barge (hull ${r.big}): shoot it and two escorts drop out of cruise`);
check(r.disabled && r.label === 'Crack the vault' && r.took >= 4000 && r.bounty === 2500, `crippled, docked, vault cracked: +${r.took}, +${r.bounty} bounty`);

// 7. passengers
r = await step('passengers', () => {
  const g = R.game; T.ground();
  const list = BS2.waiting('earth');
  const f = list[0];
  const ok = BS2.boardFare(f);
  const cash = g.player.cash;
  BS2.HOOKS.landed.forEach((h) => h(g, f.to));
  const paid = g.player.cash - cash;
  // a fugitive and the hunter who wants them
  BS2.fares().push({ id: 999, name: 'Rex Varga', who: 'a nervous accountant', to: 'mars', pay: 600, due: 99999, twist: 'fugitive' });
  T.space();
  for (let i = 0; i < 60 * 26; i++) g.tick(1 / 60);
  const hunted = T.press(/Hand over/);
  return { n: list.length, ok, paid, pay: f.pay, twist: f.twist, hunted, left: BS2.fares().length };
});
check(r.n >= 1 && r.ok && r.paid >= r.pay, `a passenger at the pad, carried, paid ${r.paid} (${r.twist})`);
check(r.hunted && r.left === 0, 'a fugitive aboard: a hunter hails, and you hand them over');

// 8. a riot
r = await step('riot', () => {
  const g = R.game, pl = g.player; T.ground(); T.inCity();
  if (pl.room) g.interiors.exit();
  const riot = BS2.startRiot(); if (!riot) return { started: false };
  for (const a of riot.crowd.slice(0, 3)) { a.hp = a.maxHp = 5000; }
  T.ticks(130);
  const fighting = riot.crowd.filter((a) => a.state === 'fight' && a.target && a.target.riotCop).length;
  const shop = g.world.buildings.find((b) => b && b.cityId === riot.city && ['general', 'bar', 'pawn', 'liquor', 'diner'].includes(b.type));
  const loot = shop && g.ui.interiorOptions(shop).find((o) => o.label === 'Loot the shelves');
  const cash = g.player.cash; if (loot) loot.fn();
  const looted = g.player.cash - cash;
  for (const a of riot.crowd.slice(0, 3)) R.combat.kill(a, pl, 'bullet');
  const kills = riot.killsCrowd;
  BS2.endRiot();
  const jur = g.law.jurAt(pl.x, pl.y);
  return { started: true, crowd: riot.crowd.length, line: riot.line.length, fighting, looted, kills, over: !BS2.RIOT.cur, clean: !g.law.bounty[jur] };
});
check(r.started && r.crowd >= 6 && r.line >= 4 && r.fighting >= 3, `a riot: ${r.crowd} rioters against ${r.line} Peacekeepers (${r.fighting} already at it)`);
check(r.looted > 0, `the shelves are free: +${r.looted}`);
check(r.kills === 3 && r.over && r.clean, `put down three rioters: a commendation, your sheet wiped ${r.kills === 3 && r.over && r.clean ? '' : JSON.stringify(r)}`);

// 9. the curfew
r = await step('curfew', () => {
  const g = R.game, pl = g.player; T.ground(); T.inCity();
  g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 23 * 60;
  BS2.CURFEW.drones.length = 0; BS2.SQ.flags.curfewPass = 0;
  const now = BS2.curfewNow();
  for (let i = 0; i < 60 * 20 && !BS2.CURFEW.drones.length; i++) { if (i % 20 === 0) T.shut(); g.tick(1 / 60); }
  const d = BS2.CURFEW.drones[0]; if (!d) return { now, drone: false, room: !!pl.room, car: !!pl.inCar, city: !!g.world.cityAt((pl.x / 16) | 0, (pl.y / 16) | 0), paused: g.ui.paused(), space: BS2.SPACE.active, hour: g.clock.hour(), earth: BS2.SQ.planet, sheet: !!document.querySelector('.sheet:not([hidden])') };
  const tags0 = BS2.CURFEW.tags;
  for (let i = 0; i < 60 * 3; i++) { if (i % 20 === 0) T.shut(); d.x = pl.x; d.y = pl.y; g.tick(1 / 60); }
  const tagged = BS2.CURFEW.tags - tags0, incident = !!g.law.incident, seen = d.seen, lost = d.lost;
  g.law.incident = null;
  // shoot one down
  BS2.CURFEW.drones.length = 0;
  BS2.CURFEW.drones.push({ x: pl.x + 60, y: pl.y + 26, hp: 30, seen: 0, lost: 0, dead: 0, checked: false });
  for (let k = 0; k < 4; k++) R.combat.ray(pl, pl.x, pl.y, 0, 200, 12);
  const downed = BS2.CURFEW.downed;
  // with a pass, they let you be
  const lounge = g.world.buildings.find((b) => b && b.type === 'social');
  const pass = g.ui.interiorOptions(lounge).find((o) => /curfew pass/i.test(o.label)); if (pass) pass.fn();
  BS2.CURFEW.drones.length = 0;
  BS2.CURFEW.drones.push({ x: pl.x, y: pl.y, hp: 30, seen: 0, lost: 0, dead: 0, checked: false });
  const t0 = BS2.CURFEW.tags;
  for (let i = 0; i < 60 * 3; i++) { if (i % 20 === 0) T.shut(); const q = BS2.CURFEW.drones[0]; if (q && q.lost < 10) { q.x = pl.x; q.y = pl.y; } g.tick(1 / 60); }
  g.law.incident = null;
  return { now, drone: true, tagged, incident, seen, lost, downed, pass: !!pass, passOk: BS2.CURFEW.tags === t0, passDay: BS2.SQ.flags.curfewPass, paused: g.ui.paused() };
});
check(r.now && r.drone, `after 22:00 on foot: a curfew drone comes looking ${r.now && r.drone ? '' : JSON.stringify(r)}`);
check(r.tagged === 1 && r.incident, `caught in its light: Curfew Violation, Peacekeepers called ${r.tagged === 1 && r.incident ? '' : JSON.stringify(r)}`);
check(r.downed === 1, 'shot down in a shower of sparks');
check(r.pass && r.passOk, `with a Syndicate pass the drone scans you and carries on ${r.pass && r.passOk ? '' : JSON.stringify(r)}`);

// 10. the achievements know about all of it
r = await step('feats', () => { const ids = R.feats.list.map((f) => f.id); return { ok: ['convoy', 'tithe', 'song', 'ahab', 'fares', 'crowd'].every((k) => ids.includes(k)) }; });
check(r.ok, 'six new achievements listed');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('extras ok');
