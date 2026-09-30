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
const step = async (name, fn) => { try { const r = await p.evaluate(fn); await closeAll(); return r || {}; } catch (e) { errs.push(name + ': ' + e.message.split('\n').slice(0, 4).join(' | ')); await closeAll().catch(() => {}); return {}; } };

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

// 0. the opening, in scenes, run at speed: the street, the hologram, Pad 3, the landing, the clamp
let r = await p.evaluate(async () => {
  const g = R.game; T.shut(); window.BS2_ANIM = 1;
  if (BS2.SPACE.active) { BS2.SPACE.active = false; BS2.SQ.mode = 'planet'; }
  BS2.SQ.flags.rayner = 0; BS2.SQ.flags.clamp = 1;
  let done = false, holo = false, landed = false, cast = 0;
  BS2.runOpening(() => { BS2.giveRaynerJob(); done = true; });
  const t0 = performance.now();
  for (let i = 0; !done && performance.now() - t0 < 150000; i++) {
    g.tick(1 / 60);
    if (BS2.OPN.holo) holo = true;
    if (BS2.LAND.mode === 'land') landed = true;
    cast = Math.max(cast, g.actors.list.filter((a) => a.scripted && !a.dead).length);
    if (i % 20 === 0) {
      const go = document.querySelector('#nameGo'); if (go && go.offsetParent) go.click();
      const opt = [...document.querySelectorAll('.sheet button')].find((q) => q.offsetParent && /said hello/.test(q.textContent)); if (opt) opt.click();
      await new Promise((res) => setTimeout(res, 8));
    }
  }
  await new Promise((res) => setTimeout(res, 1200));
  const s = document.querySelector('#story'); const story = s && getComputedStyle(s).display !== 'none' ? s.textContent : '';
  T.shut(); window.BS2_ANIM = 0;
  return { stage: BS2.OPN.stage, done, holo, landed, cast, clamp: BS2.SQ.flags.clamp, job: BS2.SQ.flags.rayner, lock: !!R.opening.lock, hidden: !!g.player.hidden, cine: !!R.opening.cineOn, story: story.slice(0, 40) };
});
check(r.done && r.holo && r.landed && r.cast >= 3, `the opening plays in scenes: the Fear Man's hologram, the ship landing, ${r.cast} Syndicate cast on the pad`);
check(r.done && r.clamp === 1 && r.job === 1 && !r.lock && !r.hidden && !r.cine, `it ends clamped, with the Rayner job, controls back ${JSON.stringify(r)}`);
// 1. game 1's systems, in the future's words
r = await step('retheme', () => {
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
  let fighting = 0;
  for (let i = 0; i < 180; i++) { T.ticks(1); fighting = Math.max(fighting, riot.crowd.filter((a) => a.state === 'fight' && a.target && a.target.riotCop).length); }
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

// 10. the lanterns: Kyle Rayner (the Fear Man's job) and Parallax
r = await step('rayner', () => {
  const g = R.game, pl = g.player; T.ground(); T.inCity();
  BS2.SQ.flags.clamp = 1; BS2.SQ.flags.rayner = 0;
  BS2.giveRaynerJob(); T.shut();
  const job = BS2.SQ.flags.rayner;
  pl.inv.tools.ring = 0;
  // Los Angeles: one sector south of the Brass Coast. He turns up on his own.
  BS2.landAt(g, [12, 11], () => BS2.travelTo(g, 'earth', true)); T.shut();
  const city = g.world.cities[0].name;
  T.inCity(); T.ticks(30);
  const k = BS2.LANTERNS.kyle;
  if (!k) return { job, city, spawned: false };
  k.x = pl.x + 40; k.y = pl.y; k.met = true; k.warnT = 0;
  T.ticks(90);
  const fought = k.hostile && BS2.LANTERNS.bolts.length + (pl.hp < pl.maxHp ? 1 : 0) > 0;
  k.shielded = 0; R.combat.kill(k, pl, 'bullet');
  const flying = !!BS2.LANTERNS.ring;
  T.ticks(10);
  return { job, city, spawned: true, fought, dead: BS2.SQ.flags.rayner, flying, ring: !!pl.inv.tools.ring };
});
await p.waitForTimeout(3000);
const clampOff = await p.evaluate(() => { T.shut(); return !BS2.SQ.flags.clamp; });
check(r.job === 1 && r.spawned && /Angeles|LA/.test(r.city || ''), `the Fear Man's job: Kyle Rayner, found in ${r.city}`);
check(r.fought, 'he warns you off, then fights with the ring');
check(r.dead === 2 && r.flying && !r.ring, 'killed: his ring flies away into the sky (not to you)');
check(clampOff, 'and the Fear Man takes the clamp off your ship');
const fearWay = await p.evaluate(() => { BS2.SQ.flags.clamp = 1; BS2.SQ.flags.fearDead = 1; T.ticks(2); T.shut(); const ok = !BS2.SQ.flags.clamp; BS2.SQ.flags.fearDead = 0; return ok; });
check(fearWay, 'or kill the Fear Man himself: the clamp comes off either way');
r = await step('parallax', () => {
  const g = R.game, pl = g.player; T.ground(); T.inCity();
  pl.inv.tools.ring = 0; BS2.SQ.flags.parallax = 1;
  BS2.spawnHal();
  const h = BS2.LANTERNS.hal;
  h.x = pl.x + 60; h.y = pl.y; pl.hp = pl.maxHp = 999;
  // he only wakes on Mars, so push the fight along by hand: three phases
  h.hostile = true; g.actors.setFight(h, pl);
  const phases = [];
  for (const hp of [1300, 700, 300]) { h.hp = hp; for (let i = 0; i < 120; i++) { BS2.SQ.planet = 'mars'; g.tick(1 / 60); } phases.push(h.phase); }
  BS2.SQ.planet = 'earth';
  R.combat.kill(h, pl, 'bullet');
  return { hp: h.maxHp, phases, dead: BS2.SQ.flags.parallax };
});
await p.waitForTimeout(2600);
const reward = await p.evaluate(() => { T.shut(); const pl = R.game.player; const hp0 = pl.hp = 100; pl.hurt(30, null, 'melee'); return { ring: !!pl.inv.tools.ring, armour: pl.style.jacket, took: hp0 - pl.hp }; });
check(r.hp >= 1000 && r.phases.join() === '0,1,2' && r.dead === 2, `Parallax: a ${r.hp} hp boss in three phases (${r.phases})`);
check(reward.ring && reward.armour === 'parallax' && reward.took < 25, `his ring and the Parallax armour are yours (a 30 hit does ${Math.round(reward.took)})`);

r = await step('takeoff', () => {
  const g = R.game; window.BS2_ANIM = 1;
  const w = g.world; BS2.SQ.flags.clamp = 0;
  let launched = false, alt = 0;
  BS2.shipTakeOff(() => { launched = true; });
  for (let i = 0; i < 60 * 4 && !launched; i++) { g.tick(1 / 60); alt = Math.max(alt, BS2.shipAlt()); }
  window.BS2_ANIM = 0;
  return { launched, alt: Math.round(alt), pad: !!w.pad };
});
check(r.launched && r.alt > 150, `takeoff: the ship climbs out of sight (${r.alt} up) before the cut to orbit`);

// 12. cameras and the cyberdeck
r = await step('cameras', () => {
  const g = R.game, pl = g.player, C = BS2.CAMS; T.ground(); T.ticks(2);
  const c = C.list.find((q) => !q.dead);
  if (!c) return { cams: 0 };
  // stand in its view
  let seen = false;
  for (let k = 0; k < 40 && !seen; k++) { const a = c.face + (Math.random() - 0.5) * 1.4, d = 20 + Math.random() * 40; pl.place(c.x + Math.cos(a) * d, c.y + Math.sin(a) * d); seen = BS2.camSees(c); }
  const jur = g.law.jurAt(pl.x, pl.y), b0 = g.law.bounty[jur] || 0, t0 = C.tapes; pl.masked = false;
  g.law.crime('assault', pl.x, pl.y, {});
  const taped = C.tapes - t0, bounty = (g.law.bounty[jur] || 0) - b0; g.law.incident = null;
  const pawn = g.world.buildings.find((b) => b && b.type === 'pawn');
  const buy = pawn && g.ui.interiorOptions(pawn).find((o) => o.label === 'Cyberdeck'); pl.cash += 300; if (buy) buy.fn();
  pl.place(c.x + Math.cos(c.face) * 14, c.y + Math.sin(c.face) * 14);
  const a = pl.contextAction(); const label = a && a.label; if (a) a.fn();
  T.press(/Loop the feed/);
  pl.place(c.x + Math.cos(c.face) * 30, c.y + Math.sin(c.face) * 30);
  const looped = !BS2.camSees(c);
  // and one shot out
  const c2 = C.list.find((q) => q !== c && !q.dead);
  if (c2) { pl.place(c2.x, c2.y + 60); R.combat.ray(pl, pl.x, pl.y - 18, Math.atan2(c2.y - 18 - (pl.y - 18), c2.x - pl.x), 200, 12); }
  g.law.incident = null;
  return { cams: C.list.length, seen, taped, bounty, deck: !!pl.inv.tools.deck, label, looped, shot: c2 ? c2.dead : true };
});
check(r.cams > 5 && r.seen && r.taped === 1 && r.bounty > 0, `${r.cams} security cameras; a crime in view is on tape (+${r.bounty} bounty)`);
check(r.deck && r.label === 'Jack into the camera' && r.looped, 'a cyberdeck from the Chop Shop: jack in and loop the feed');
check(r.shot, 'or shoot the camera out');
r = await step('ambient', () => {
  const g = R.game; T.ground(); T.inCity();
  g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 22 * 60; g.env.setWeather('rain'); g.env.weather.rain = 1;
  BS2.AMB.flyT = 0; BS2.AMB.blimpT = 0;
  T.ticks(60 * 5);
  const pl = g.player; return { earth: BS2.EARTH.active, planet: BS2.SQ.planet, blimpT: Math.round(BS2.AMB.blimpT), room: !!pl.room, cam: [Math.round(g.cam.x - pl.x), Math.round(g.cam.y - pl.y)], flyers: BS2.AMB.flyers.length, blimp: BS2.AMB.flyers.some((f) => f.kind === 'blimp'), splashes: BS2.AMB.splashes.length };
});
check(r.flyers >= 2 && r.blimp && r.splashes > 5, JSON.stringify(r) + ' ' + `the city overhead: ${r.flyers} flyers in the sky lanes (a Syndicate blimp among them), rain splashing`);

// 13. the achievements know about all of it
r = await step('feats', () => { const ids = R.feats.list.map((f) => f.id); return { ok: ['convoy', 'tithe', 'song', 'ahab', 'fares', 'crowd', 'rayner', 'parallax'].every((k) => ids.includes(k)) }; });
check(r.ok, 'eight new achievements listed');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('extras ok');
