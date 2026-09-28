// Long-haul playtest bot: plays N in-game days through the real controls (stick +
// buttons) with A* navigation, doing jobs, shopping, fighting, driving, gambling,
// burglary, drugs, hiring and legend hunting. Logs daily metrics, toasts, crimes and
// page errors to a JSON report, and takes a screenshot every few days.
//   node tools/build.mjs && node tools/playtest.mjs [days] [outDir]
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { mkdirSync, writeFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require('/opt/node22/lib/node_modules/playwright')); }
const DAYS = +(process.argv[2] || 100);
const OUT = process.argv[3] || join(dirname(fileURLToPath(import.meta.url)), '..', 'playtest-out');
// playstyle: shark (loans and the ponies), fixer (cops, captains, rats), hijacker (trucks), all, or none
const STYLE = process.argv[4] || 'all';
mkdirSync(OUT, { recursive: true });
const page = 'file://' + join(dirname(fileURLToPath(import.meta.url)), '..', 'dist', 'index.html') + '?quick';
const browser = await chromium.launch();
const p = await (await browser.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 1, hasTouch: true })).newPage();
const errors = [];
p.on('pageerror', (e) => errors.push({ msg: e.message, stack: (e.stack || '').split('\n').slice(0, 4).join(' | ') }));
p.on('console', (m) => { if (m.type() === 'error' && !/fonts|CERT|net::/.test(m.text())) errors.push({ msg: 'console: ' + m.text().slice(0, 300) }); });
await p.goto(page);
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
await p.click('#btnNew');
await p.waitForTimeout(300);
await p.click('#story button');
await p.waitForTimeout(500);

// ---------------------------------------------------------------- the bot, installed in the page
await p.evaluate(() => {
  const g = R.game, pl = g.player, TS = R.TILE, D = R.data, T = D.T;
  const B = (window.BOT = { log: [], toasts: [], crimes: [], stories: [], day: [], acts: {}, tickMs: [], stuck: 0, lastAct: '' });
  const origToast = g.ui.toast.bind(g.ui);
  g.ui.toast = (m, k) => { B.toasts.push([g.clock.day(), g.clock.label(), k || '', String(m).slice(0, 160)]); if (B.toasts.length > 6000) B.toasts.shift(); return origToast(m, k); };
  const origStory = g.ui.story.bind(g.ui);
  g.ui.story = (t, body, cb) => { B.stories.push([g.clock.day(), t, String(body).slice(0, 200)]); if (cb) setTimeout(cb, 0); return undefined; };
  const origCrime = g.law.crime.bind(g.law);
  g.law.crime = (type, x, y, o) => { B.crimes.push([g.clock.day(), g.clock.label(), type, B.lastAct, Math.round(Math.hypot(x - pl.x, y - pl.y))]); return origCrime(type, x, y, o); };
  const origHurt = pl.hurt.bind(pl);
  B.hurts = [];
  pl.hurt = (amt, src, kind) => { B.hurts.push([g.clock.day(), g.clock.label(), Math.round(amt), kind || '', src ? (src.kind === 'v' ? 'car:' + (src.modelId || '') + (src.driver === pl ? ':self' : '') : src.kind === 'a' ? 'animal:' + src.type : src.kind === 'h' ? 'human:' + (src.tag || '') + ':' + (src.state || '') + (src.cop ? ':cop' : '') : '?') : 'none', B.lastAct]); if (B.hurts.length > 3000) B.hurts.shift(); return origHurt(amt, src, kind); };
  const act = (k) => { B.acts[k] = (B.acts[k] || 0) + 1; B.lastAct = k; };
  B.act = act;
  const inp = g.input;
  const stick = (dx, dy, run) => { const m = run ? 1.4 : 1; inp.touchStick = dx || dy ? { id: 99, ox: 0, oy: 0, r: 1, x: dx * m, y: dy * m } : null; };
  const press = (a) => { inp.down(a); B._release = B._release || []; B._release.push(a); };
  B.tick = (n) => {
    for (let i = 0; i < n; i++) {
      const t0 = performance.now();
      g.tick(1 / 30);
      if (B._release) { for (const a of B._release) inp.up(a); B._release = null; }
      const ms = performance.now() - t0;
      B.tickMs.push(ms);
      if (B.tickMs.length > 3000) B.tickMs.shift();
      if (g.ui.sheetOpen && !B.keepSheet) g.ui.closeSheet();
      if (document.getElementById('story').style.display === 'flex') g.ui.closeStory && g.ui.closeStory();
      if (pl.dead) { act('died'); const btn = g.ui.el.death.querySelector('button'); if (btn) btn.click(); }
      if (document.getElementById('arrest') && document.getElementById('arrest').style.display === 'flex') { act('arrested'); document.getElementById(Math.random() < 0.7 ? 'surrender' : 'resist').click(); }
    }
  };
  // walk to a world point with A*; returns true on arrival
  B.goto = function (tx, ty, maxTicks, run) {
    if (pl.room) g.interiors.exit();
    if (pl.inCar) pl.exitCar();
    const path = R.path.find((pl.x / TS) | 0, (pl.y / TS) | 0, tx, ty, 80000);
    if (!path) B.noPath = (B.noPath || 0) + 1;
    let i = 0, still = 0, lx = pl.x, ly = pl.y;
    for (let k = 0; k < (maxTicks || 900); k++) {
      if (Math.hypot(pl.x - (tx * TS + 8), pl.y - (ty * TS + 8)) < 14) { stick(0, 0); return true; }
      let gx = tx * TS + 8, gy = ty * TS + 8;
      if (path && path.length) {
        while (i < path.length - 1 && Math.hypot(pl.x - (path[i].x * TS + 8), pl.y - (path[i].y * TS + 8)) < 9) i++;
        gx = path[i].x * TS + 8; gy = path[i].y * TS + 8;
      }
      const dx = gx - pl.x, dy = gy - pl.y, d = Math.hypot(dx, dy) || 1;
      stick(dx / d, dy / d, run);
      B.tick(1);
      if (Math.hypot(pl.x - lx, pl.y - ly) < 0.3) still++; else still = 0;
      lx = pl.x; ly = pl.y;
      if (still > 45) { B.stuck++; const a = Math.random() * 6.28; stick(Math.cos(a), Math.sin(a)); B.tick(10); still = 0; if (i < (path ? path.length - 1 : 0)) i++; }
    }
    stick(0, 0);
    return false;
  };
  B.near = (tx, ty) => { const w = g.world; return w.findNear(tx, ty, 0, 6, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y)) || { x: tx, y: ty }; };
  B.city = () => g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0) || g.world.cities[0];
  B.teleport = (tx, ty) => { if (pl.room) g.interiors.exit(); if (pl.inCar) pl.exitCar(); const s = B.near(tx, ty); pl.place(s.x * TS + 8, s.y * TS + 8); g.cam.x = pl.x; g.cam.y = pl.y; };
  B.taxiTo = (c) => { act('taxi'); const b = c.buildings.find((q) => q.type === 'hotel') || c.buildings[0]; if (pl.cash >= 25) { pl.cash -= 25; B.teleport(b.out.x, b.out.y + 1); g.clock.skip(30); } };
  B.use = () => { press('use'); B.tick(2); };
  B.hit = (n) => { for (let i = 0; i < (n || 1); i++) { press('attack'); B.tick(8); } };
  B.nearestNPC = (r, pred) => g.actors.near(pl.x, pl.y, r || TS * 10).filter((a) => a.kind === 'h' && !a.dead && !a.inCar && (!pred || pred(a))).sort((a, b) => Math.hypot(a.x - pl.x, a.y - pl.y) - Math.hypot(b.x - pl.x, b.y - pl.y))[0];
  B.approach = (h) => { for (let k = 0; k < 240 && h && !h.dead; k++) { const dx = h.x - pl.x, dy = h.y - pl.y, d = Math.hypot(dx, dy); if (d < 16) { stick(0, 0); pl.ang = Math.atan2(dy, dx); return true; } stick(dx / d, dy / d, d > 60); B.tick(1); } stick(0, 0); return false; };
  B.enter = (b) => { if (!b) return false; B.goto(b.out.x, b.out.y, 1200); if (Math.hypot(pl.x / TS - b.out.x, pl.y / TS - b.out.y) > 3) return false; g.interiors.enter(b, g.ui.isOpen(b) || b.playerOwned ? 'normal' : 'guest'); B.tick(5); return !!pl.room; };
  B.snapshot = () => {
    const alive = g.pop.people.filter((q) => q.alive);
    const ms = B.tickMs.slice().sort((a, b) => a - b);
    return {
      day: g.clock.day() + 1, cash: pl.cash, hp: Math.round(pl.hp), rank: g.jobs.rankName(), rep: Math.round(g.jobs.rep), infamy: Math.round(pl.rep.infamy), honor: Math.round(pl.rep.honor),
      bounty: Object.values(g.law.bounty).reduce((a, b) => a + b, 0), jobsDone: pl.stats.jobs, crimes: pl.stats.crimes, kills: pl.stats.kills, arrests: pl.stats.arrests, deaths: pl.stats.deaths,
      people: alive.length, kids: alive.filter((q) => q.age < 18).length, avgAge: Math.round(alive.reduce((a, q) => a + q.age, 0) / alive.length), families: new Set(alive.map((q) => q.home)).size,
      buildings: g.world.buildings.filter((b) => b && !b.destroyed).length, projects: g.pop.projects.length, news: g.pop.news.length,
      actors: g.actors.list.length, cars: g.traffic.list.length, loose: R.props.loose.length, decals: g.fx.decals.length, particles: g.fx.p.length,
      tickP50: +(ms[Math.floor(ms.length * 0.5)] || 0).toFixed(2), tickP95: +(ms[Math.floor(ms.length * 0.95)] || 0).toFixed(2), stuck: B.stuck, noPath: B.noPath || 0,
      found: R.poi.found.size, pins: R.poi.pins.length, errands: (pl.errands || []).length, will: pl.will == null ? null : Math.round(pl.will), ring: !!pl.inv.tools.ring,
      style: Object.values(pl.style).join('/'), cities: g.world.cities.map((c) => `${c.id}:${Math.round(c.prosperity)}/${Math.round(c.fear)}/${Math.round(c.heat)}`).join(' '),
    };
  };
});

// ---------------------------------------------------------------- daily routine
const routine = async (day) => p.evaluate(({ day, style }) => {
  const g = R.game, pl = g.player, B = window.BOT, TS = R.TILE, D = R.data, w = g.world;
  const r = Math.random;
  const pick = (a) => a[Math.floor(r() * a.length)];
  const setTime = (h) => { const cur = g.clock.t % 1440; const target = h * 60; g.clock.skip(((target - cur) + 1440) % 1440); };
  const out = [];
  const note = (s) => out.push(s);
  if (pl.cash < 40) { pl.cash += 60; note('topped up $60 (broke)'); }

  // ---- morning: family work
  setTime(9);
  const city = B.city();
  if (!g.jobs.active) {
    const offers = g.jobs.offersFor(pl.family);
    const j = offers.find((o) => ['collect', 'scare', 'rob', 'steal'].includes(o.kind)) || offers[0];
    if (j) { g.jobs.accept(j); B.act('job:' + j.kind); note('took job ' + j.title); }
  }
  const j = g.jobs.active;
  if (j) {
    // sometimes hand it to someone who likes us
    const friend = g.pop.people.find((q) => q.alive && q.opinion >= 30 && q.age > 20 && q.role !== 'don' && !(pl.errands || []).some((e) => e.pid === q.id));
    if (friend && r() < 0.2 && ['collect', 'scare', 'rob'].includes(j.kind)) {
      const h = g.life.spawnPerson(friend, pl.x + 20, pl.y) || friend.actor;
      if (h) { B.keepSheet = true; R.goods.openHire(h); const b = document.querySelector('.opt'); if (b) b.click(); B.keepSheet = false; g.ui.closeSheet(); B.act('hire:job'); note('delegated job to ' + friend.first); }
    } else {
      const m = g.jobs.marker();
      if (m) {
        const tx = (m.x / TS) | 0, ty = (m.y / TS) | 0;
        if (Math.hypot(tx - pl.x / TS, ty - pl.y / TS) > 90) { const c2 = w.cityAt(tx, ty); if (c2) B.taxiTo(c2); }
        const ok = B.goto(tx, ty, 2400, true);
        B.act(ok ? 'job:reached' : 'job:notReached');
        if (ok && j.person !== undefined) {
          const p = g.pop.people[j.person];
          const h = p.actor || B.nearestNPC(TS * 6, (a) => a.person === p);
          if (h) {
            B.approach(h);
            if (j.kind === 'collect' || j.kind === 'scare') {
              for (let k = 0; k < 4 && g.jobs.active === j; k++) { R.dialog.antagonize(h); B.tick(20); }
              B.keepSheet = true; pl.talk(h); const o = [...document.querySelectorAll('.opt')].find((b) => /wants his|Don /.test(b.textContent)); if (o) o.click(); B.keepSheet = false; g.ui.closeSheet(); B.tick(20);
              if (g.jobs.active === j && j.kind === 'collect') { B.hit(3); B.keepSheet = true; pl.talk(h); const o2 = [...document.querySelectorAll('.opt')].find((b) => /wants his/.test(b.textContent)); if (o2) o2.click(); B.keepSheet = false; g.ui.closeSheet(); }
            } else if (j.kind === 'hit') { pl.weapon = 'revolver'; pl.weaponOut = true; for (let k = 0; k < 20 && !h.dead; k++) { pl.ang = Math.atan2(h.y - pl.y, h.x - pl.x); B.hit(1); } }
          } else note('job target not found on arrival');
        }
        if (ok && j.kind === 'rob') { const b = w.buildings[j.building]; if (B.enter(b)) { pl.weapon = 'revolver'; pl.weaponOut = true; const reg = g.interiors.furnitureAhead && null; const room = pl.room; const clerk = g.actors.list.find((a) => a.room === room && a.staff); if (clerk) { B.approach(clerk); } B.use(); B.tick(60); g.interiors.exit(); } }
        if (ok && j.kind === 'steal') { const v = g.traffic.list.find((q) => q.parked && Math.hypot(q.x - pl.x, q.y - pl.y) < TS * 12); if (v) { v.hotwired = true; pl.enterCar(v, true); B.act('steal:car'); B.tick(30); pl.exitCar(); } }
      }
      if (g.jobs.active === j && r() < 0.15) { g.jobs.abandon(); B.act('job:abandon'); }
    }
  }
  B.tick(60);

  // ---- midday: shops, style, errands
  setTime(13);
  const shops = B.city().buildings.filter((b) => b && !b.destroyed && ['general', 'gunshop', 'tailor', 'barber', 'pawn', 'diner', 'pharmacy', 'liquor', 'butcher'].includes(b.type));
  const shop = pick(shops);
  if (shop && B.enter(shop)) {
    B.act('shop:' + shop.type);
    if (shop.type === 'tailor' && pl.cash > 200) { B.keepSheet = true; R.openWardrobe('tailor'); const it = [...document.querySelectorAll('.wi')]; if (it.length) it[Math.floor(r() * it.length)].click(); const buy = document.querySelector('[data-a="buy"]'); if (buy) buy.click(); B.keepSheet = false; g.ui.closeSheet(); B.act('wardrobe'); }
    else if (shop.type === 'barber') { B.keepSheet = true; R.openWardrobe('barber'); const it = [...document.querySelectorAll('.wi')]; if (it.length) it[Math.floor(r() * it.length)].click(); const buy = document.querySelector('[data-a="buy"]'); if (buy) buy.click(); B.keepSheet = false; g.ui.closeSheet(); B.act('barber'); }
    else { B.keepSheet = true; g.ui.openCounter(shop); const opts = [...document.querySelectorAll('.opt')].filter((b) => /\$/.test(b.textContent)); if (opts.length) { opts[Math.floor(r() * opts.length)].click(); B.act('bought'); } B.keepSheet = false; g.ui.closeSheet(); }
    // grab something in the room
    const gr = R.props.loose.find((q) => q.y > w.H * TS && Math.hypot(q.x - pl.x, q.y - pl.y) < TS * 8);
    if (gr && r() < 0.3) { R.props.pickUp(pl, { p: gr }); B.act('prop:grab'); }
    g.interiors.exit();
  }
  // talk to people, ask for spots, maybe hire
  for (let k = 0; k < 4; k++) {
    const h = B.nearestNPC(TS * 14, (a) => a.person && !a.cop && a.state !== 'fight');
    if (!h) break;
    B.approach(h);
    R.dialog.greet(h); B.tick(20); R.dialog.greet(h); B.tick(20); B.act('greet');
    if (r() < 0.4) { B.keepSheet = true; pl.talk(h); const o = [...document.querySelectorAll('.opt')].find((b) => /good spots|strange stories|Heard anything/.test(b.textContent)); if (o) { o.click(); B.act('ask'); } B.keepSheet = false; g.ui.closeSheet(); }
    if (r() < 0.15 && R.goods.canHire(h)) { B.keepSheet = true; R.goods.openHire(h); const o = [...document.querySelectorAll('.opt')].filter((b) => !/Never/.test(b.textContent)); if (o.length) { o[Math.floor(r() * o.length)].click(); B.act('hire'); } B.keepSheet = false; g.ui.closeSheet(); }
    B.tick(30);
  }
  // wander the block with a prop or fists; pick fights sometimes
  const bx = (pl.x / TS) | 0, by = (pl.y / TS) | 0;
  const wp = w.findNear(bx, by, 10, 30, (x, y) => w.t(x, y) === D.T.WALK);
  if (wp) B.act(B.goto(wp.x, wp.y, 900) ? 'wander' : 'wander:stuck');
  const gp = R.props.grabbable(pl);
  if (gp && r() < 0.4) { R.props.pickUp(pl, gp); B.act('prop:street'); }
  if (r() < 0.35) {
    const tough = B.nearestNPC(TS * 10, (a) => !a.cop && a.person && a.tr.brave > 0.6);
    if (tough) { B.approach(tough); for (let k = 0; k < 3; k++) { R.dialog.antagonize(tough); B.tick(25); } if (tough.state === 'fight') { for (let k = 0; k < 12 && !tough.dead && tough.down <= 0; k++) { pl.ang = Math.atan2(tough.y - pl.y, tough.x - pl.x); if (pl.held) R.props.swing(pl); else B.hit(1); B.tick(6); } B.act('brawl'); } }
  }
  if (pl.held && r() < 0.5) { R.props.throwHeld(pl); B.act('prop:throw'); B.tick(30); }

  // ---- afternoon: trouble, hunting or property
  setTime(16);
  const roll = r();
  if (roll < 0.2) {
    const tgt = pick(B.city().buildings.filter((b) => b && !b.destroyed && D.btypes[b.type].rob && g.ui.isOpen(b)));
    if (tgt && B.enter(tgt)) {
      pl.weapon = 'revolver'; pl.weaponOut = true; pl.inv.weapons.revolver = 1;
      const clerk = g.actors.list.find((a) => a.room === pl.room && a.staff && !a.dead);
      if (clerk) { B.approach(clerk); const fa = g.interiors.furnitureAhead(); const reg = pl.room.furniture ? null : null; }
      // stand at the register
      let robbed = false;
      for (let yy = pl.room.y0; yy < pl.room.y0 + pl.room.h && !robbed; yy++) for (let xx = pl.room.x0; xx < pl.room.x0 + pl.room.w && !robbed; xx++) if (w.o(xx, yy) === D.O.REGISTER) { pl.place(xx * TS + 8, (yy + 1) * TS + 8); pl.ang = -Math.PI / 2; pl.dir = 0; const fa = g.interiors.furnitureAhead(); if (fa) { const a = g.interiors.furnitureAction(fa); if (a) { a.fn(); robbed = true; B.act('rob:' + a.label); } } }
      B.tick(90);
      g.interiors.exit();
      // run for it
      const far = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 30, 50, (x, y) => w.t(x, y) === D.T.WALK);
      if (far) B.act(B.goto(far.x, far.y, 1500, true) ? 'flee:ok' : 'flee:stuck');
    }
  } else if (roll < 0.35) {
    const c = B.city();
    const s = w.findNear(c.cx, c.cy, c.nbx * 13 + 25, c.nbx * 13 + 60, (x, y) => ['forest', 'grass', 'field', 'marsh', 'desert', 'snow'].includes(w.biomeAt(x, y)) && !w.solidPed(x, y));
    if (s) {
      B.teleport(s.x, s.y); B.act('hunt:go'); pl.inv.weapons.rifle = 1; pl.inv.ammo.rifle = 20; pl.clip.rifle = pl.clip.rifle || 5; pl.weapon = 'rifle'; pl.weaponOut = true;
      for (let k = 0; k < 40; k++) g.actors.manage && g.actors.manage();
      B.tick(120);
      const an = g.actors.list.filter((a) => a.kind === 'a' && !a.dead).sort((a, b) => Math.hypot(a.x - pl.x, a.y - pl.y) - Math.hypot(b.x - pl.x, b.y - pl.y))[0];
      if (an) { B.approach(an); for (let k = 0; k < 15 && !an.dead; k++) { pl.ang = Math.atan2(an.y - pl.y, an.x - pl.x); B.hit(1); } if (an.dead) { B.act('hunt:kill:' + an.type); B.approach(an); B.use(); } else B.act('hunt:miss'); }
      else B.act('hunt:noAnimals');
      B.taxiTo(c);
    }
  } else if (roll < 0.42 && pl.cash > 1800) {
    const home = B.city().buildings.find((b) => b && (b.type === 'house' || b.type === 'cabin') && !b.residents.length && !b.playerOwned);
    if (home) { B.goto(home.out.x, home.out.y, 1500); B.keepSheet = true; g.interiors.doorPrompt(home); const o = [...document.querySelectorAll('.opt')].find((x) => /Buy this place/.test(x.textContent)); if (o) { o.click(); B.act('property:buy'); } B.keepSheet = false; g.ui.closeSheet(); if (pl.room) g.interiors.exit(); }
  }
  if (g.law.incident) { B.act('incident:' + g.law.incident.state); const far = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 40, 70, (x, y) => w.t(x, y) === D.T.WALK); if (far) B.goto(far.x, far.y, 1800, true); B.act(g.law.incident ? 'incident:stillActive' : 'incident:escaped'); }

  // ---- evening: drive somewhere
  setTime(18);
  const v = g.traffic.list.find((q) => !q.wrecked && (q.parked || q.owner === 'player') && Math.hypot(q.x - pl.x, q.y - pl.y) < TS * 20);
  if (v && r() < 0.7) {
    B.goto((v.x / TS) | 0, ((v.y + 12) / TS) | 0, 600);
    v.hotwired = v.hotwired || r() < 0.5;
    if (v.locked) { pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + 1; v.locked = false; }
    pl.enterCar(v, v.hotwired);
    if (pl.inCar) {
      B.act('drive');
      for (let k = 0; k < 450; k++) { const t = (k / 60) | 0; g.input.touchStick = { id: 99, ox: 0, oy: 0, r: 1, x: Math.cos(t * 1.3 + day), y: Math.sin(t * 0.9 + day) }; B.tick(1); if (!pl.inCar) break; if (pl.inCar.burning > 0) { B.act('drive:bail'); break; } }
      g.input.touchStick = null;
      pl.exitCar(); B.tick(10);
    }
  }

  // ---- night: bar, club or casino; minigames, dealers; burglary; legends
  setTime(22);
  const night = pick(['bar', 'club', 'casino', 'burgle', 'legend', 'bar', 'casino']);
  const venues = B.city().buildings.filter((b) => b && !b.destroyed && b.type === (night === 'casino' ? 'casino' : night === 'club' ? 'club' : 'bar'));
  if ((night === 'bar' || night === 'club' || night === 'casino') && venues.length) {
    const b = pick(venues);
    if (B.enter(b)) {
      B.act('night:' + b.type);
      const dealer = g.actors.list.find((a) => a.room === pl.room && a.dealer);
      if (dealer && r() < 0.6) { B.keepSheet = true; R.goods.openDealer(dealer); const o = [...document.querySelectorAll('.opt')].filter((x) => /\$/.test(x.textContent) && !/Sell/.test(x.textContent)); if (o.length) { o[Math.floor(r() * o.length)].click(); B.act('drugs:buy'); } B.keepSheet = false; g.ui.closeSheet(); const k = Object.keys(pl.inv.drugs || {}).find((q) => pl.inv.drugs[q] > 0); if (k && r() < 0.6) { R.goods.take(k); B.act('drugs:take:' + k); B.tick(90); } }
      if (r() < 0.5) { R.mini.darts({ stake: 10 }); B.act('mini:darts'); g.ui.closeSheet(); }
      if (b.type === 'casino' && r() < 0.8) { R.mini.blackjack({}); B.act('mini:blackjack'); g.ui.closeSheet(); }
      // wash dirty cash through the chips
      if (b.type === 'casino' && R.money && R.money.dirty() > 150) { const o = g.ui.interiorOptions(b).find((x) => /chips/.test(x.label)); if (o) { o.fn(); B.act('launder'); } }
      // and flirt with somebody at the bar
      const date = g.actors.list.find((a) => a.room === pl.room && a.kind === 'h' && !a.dead && !a.staff && R.charm && R.charm.canFlirt(a));
      if (date && r() < 0.5) { for (let k = 0; k < 3; k++) { R.charm.flirt(date); B.tick(40); } B.act(date.flirted >= 2 ? 'flirt:won' : 'flirt:tried'); }
      B.tick(120);
      g.interiors.exit();
    }
  } else if (night === 'burgle') {
    const houses = B.city().buildings.filter((b) => b && !b.destroyed && b.type === 'house' && !b.playerOwned);
    const h = pick(houses);
    if (h) { B.goto(h.out.x, h.out.y, 1200); g.interiors.breakIn(h, r() < 0.5 && pl.inv.tools.lockpick ? 'force' : 'force'); B.act('burgle'); if (pl.room) { const room = pl.room; for (const s of room.extra.slice(0, 3)) { pl.place(s.x * TS + 8, s.y * TS + 8); const fa = g.interiors.furnitureAhead(); if (fa) { const a = g.interiors.furnitureAction(fa); if (a && /Search|Rifle|Raid|Check|Force|Pry/.test(a.label)) { a.fn(); B.act('search'); } } B.tick(20); } g.interiors.exit(); } }
  } else if (night === 'legend') {
    const which = pick(['fear', 'pier', 'ufo', 'forest', 'cross']);
    B.act('legend:' + which);
    if (which === 'fear' && !pl.inv.tools.ring) { setTime(2); const s = R.ring.fearSpot; B.teleport(s.x, s.y + 4); B.tick(60); const fm = R.ring.fearMan; if (fm) { B.approach(fm); B.keepSheet = true; pl.talk(fm); for (let k = 0; k < 2; k++) { const o = [...document.querySelectorAll('.opt')]; const pickO = o.find((x) => /Who are you/.test(x.textContent)); if (pickO) pickO.click(); } pl.talk(fm); const give = [...document.querySelectorAll('.opt')].find((x) => /ring|thing like/.test(x.textContent)); if (give) give.click(); B.keepSheet = false; g.ui.closeSheet(); B.act(pl.inv.tools.ring ? 'ring:got' : 'ring:failed'); } else B.act('fear:absent'); }
    if (which === 'pier') { setTime(1); const s = w.spots.find((q) => q.kind === 'pier'); B.teleport(s.x + 4, s.y); R.legends.t = 0; B.tick(200); if (R.legends.active.ghost) { B.approach(R.legends.active.ghost); B.tick(30); B.act('ghost:met'); } }
    if (which === 'ufo') { setTime(2.5); const c = w.cities.find((q) => q.id === 'dust'); const s = w.findNear(c.cx + 60, c.cy, 0, 30, (x, y) => w.biomeAt(x, y) === 'desert'); if (s) { B.teleport(s.x, s.y); for (let k = 0; k < 20 && !R.legends.ufo; k++) { R.legends.t = 0; B.tick(10); } if (R.legends.ufo) { const u = R.legends.ufo; pl.place(u.x, u.y); B.tick(80); B.act('ufo:seen'); } } }
    if (which === 'forest') { setTime(19); const c = w.cities.find((q) => q.id === 'pine'); const s = w.findNear(c.cx, c.y0 - 30, 0, 25, (x, y) => w.t(x, y) === D.T.FOREST); if (s) { B.teleport(s.x, s.y); for (let k = 0; k < 20 && !R.legends.active.squatch; k++) { R.legends.t = 0; B.tick(10); } if (R.legends.active.squatch) B.act('squatch:seen'); B.tick(120); } }
    if (which === 'cross') { setTime(0.1); const it = w.inters.find((i) => !w.inCityRect(Math.round(i.cx), Math.round(i.cy), 4)); if (it) { B.teleport(Math.round(it.cx) + 3, Math.round(it.cy) + 6); R.legends.t = 0; B.tick(40); if (R.legends.active.cross) B.act('cross:met'); } }
    // back to a city
    B.taxiTo(pick(w.cities));
  }
  // ---- playstyles: work a trade every day through its real menus
  const want = (s) => style === 'all' || style === s;
  const autopick = (re) => { const ch = g.ui.choice; g.ui.choice = function (t, o) { g.ui.choice = ch; const x = o.find((q) => re.test(q.label)); if (x) { if (x.fn) x.fn(); return; } return ch.call(this, t, o); }; };
  const optOf = (h, re) => { const t = R.dialog.tree(h); return t && t.options ? t.options.find((o) => re.test(o.label)) : null; };
  if (want('shark') && R.shark) {
    setTime(14);
    // collect from anyone late: go to their door
    for (const l of R.shark.open().filter((q) => q.late > 0).slice(0, 2)) {
      const p = g.pop.people[l.pid], b = p && w.buildings[p.home];
      if (!b) continue;
      B.goto(b.out.x, b.out.y + 1, 1500);
      const h = p.actor && !p.actor.dead ? p.actor : g.life.spawnPerson(p, pl.x + 12, pl.y);
      const o = h && optOf(h, /money you owe/);
      if (o) { const c0 = pl.cash; autopick(r() < 0.25 ? /favour|Take something|Break a finger|All of it|Just the juice/ : /All of it|Just the juice|Break a finger/); o.fn(); B.act('shark:collect'); note(`shark: ${l.name} +$${pl.cash - c0}`); }
    }
    // lend to the broke on this block
    for (const h of g.actors.near(pl.x, pl.y, TS * 14).filter((a) => a.kind === 'h' && !a.dead && a.person && !a.inCar).slice(0, 5)) {
      const o = optOf(h, /Short on cash/);
      if (o && R.shark.open().length < 6 && pl.cash > 400) { autopick(r() < 0.5 ? /Lend \$250/ : /Lend \$100/); o.fn(); B.act('shark:lend'); }
    }
    if (R.shark.state().fixed) { const bar = B.city().buildings.find((b) => b && b.type === 'bar'); const o = bar && g.ui.interiorOptions(bar).find((x) => /bookie/.test(x.label)); if (o) { autopick(/12–1/); o.fn(); B.act('ponies:fixed'); } }
  }
  if (want('fixer') && R.payroll) {
    setTime(15);
    const cop = g.actors.near(pl.x, pl.y, TS * 20).find((a) => a.cop && !a.hostile && !a.detectiveFor && !a.onPayroll);
    if (cop && !g.law.incident) { B.approach(cop); const o = optOf(cop, /coffee/); if (o) { o.fn(); B.act(cop.onPayroll ? 'fixer:beat' : 'fixer:refused'); } }
    const j = g.law.jurAt(pl.x, pl.y), r0 = R.payroll.jur(j);
    if (r0.beats.length >= 2 && r0.captain == null && pl.cash > 400) { const ps = w.buildings.find((b) => b && b.type === 'police' && b.cityId === j); const o = ps && g.ui.interiorOptions(ps).find((x) => /captain/.test(x.label)); if (o) { autopick(/envelope/); o.fn(); B.act(r0.captain != null ? 'fixer:captain' : 'fixer:captainFailed'); } }
    if (R.rat && R.rat.active() && r0.captain != null) { const ps = w.buildings.find((b) => b && b.type === 'police' && b.cityId === j); const o = ps && g.ui.interiorOptions(ps).find((x) => /word with/.test(x.label)); if (o) { autopick(/feds/); o.fn(); B.act('fixer:ratTip'); } }
    // deal with a named rat
    const rat = R.rat && R.rat.active();
    if (rat && rat.named) { const p = g.pop.people[rat.pid], b = p && w.buildings[p.home]; if (b) { B.goto(b.out.x, b.out.y + 1, 1500); const h = p.actor && !p.actor.dead ? p.actor : g.life.spawnPerson(p, pl.x + 12, pl.y); const o = h && optOf(h, /take a ride/); if (o) { pl.weaponOut = true; autopick(r() < 0.5 ? /Keep talking/ : /Get out of town/); o.fn(); pl.weaponOut = false; B.act('rat:' + rat.status); } } }
  }
  if (want('hijacker') && R.hijack) {
    setTime(20);
    const bar = B.city().buildings.find((b) => b && (b.type === 'bar' || b.type === 'diner'));
    const s = R.hijack.state();
    if (bar && !(s.tip && g.pop.day <= s.tip.until)) { const o = g.ui.interiorOptions(bar).find((x) => /trucks/.test(x.label)); if (o) { o.fn(); B.act('hijack:tip'); } }
    const tb = s.tip && w.buildings[s.tip.bid];
    if (tb && g.pop.day <= s.tip.until) {
      B.teleport(tb.out.x, tb.out.y + 3); B.tick(20);
      const truck = g.traffic.list.find((v2) => v2.tipped && !v2.removed && v2.cargo);
      if (truck) {
        truck.hotwired = true; pl.place(truck.x + 20, truck.y); pl.enterCar(truck, true); B.tick(30);
        const pawn = w.buildings.filter((b) => b && b.type === 'pawn').sort((a, b2) => Math.hypot(a.out.x - tb.out.x, a.out.y - tb.out.y) - Math.hypot(b2.out.x - tb.out.x, b2.out.y - tb.out.y))[0];
        if (pl.inCar === truck && pawn) { truck.x = pawn.out.x * TS + 8; truck.y = pawn.out.y * TS + 30; autopick(/Sell/); const c0 = pl.cash; pl.exitCar(); B.tick(20); B.act(pl.cash > c0 ? 'hijack:fenced' : 'hijack:unsold'); note(`hijack: +$${pl.cash - c0}`); }
        if (g.law.incident) { B.act('hijack:heat'); }
      }
    }
  }

  // ring practice
  if (pl.inv.tools.ring) { for (const k of ['anvil', 'cage', 'rocket', 'fish']) { R.ring.selected = k; pl.will = 100; R.ring.conjure(); B.tick(30); } B.act('ring:use'); }

  // ---- sleep: hotel or owned place, else just skip
  const hotel = B.city().buildings.find((b) => b && (b.type === 'hotel' || b.type === 'motel'));
  if (hotel && r() < 0.6 && B.enter(hotel)) { pl.cash = Math.max(pl.cash, 20); const bed = pl.room.beds[0]; if (bed) { g.interiors.sleep(pl.room); B.act('sleep:hotel'); } g.interiors.exit(); }
  else { setTime(8); B.act('sleep:skip'); }
  if (g.law.active() && r() < 0.5) { const jur = g.law.jurAt(pl.x, pl.y); g.law.payBounty(jur); B.act('bounty:paid'); }
  B.tick(30);
  return out;
}, { day, style: STYLE });

const report = { days: [], notes: {}, errors };
const t0 = Date.now();
const startDay = await p.evaluate(() => R.game.clock.day());
let lastShot = -1;
for (let d = 1; ; d++) {
  let notes = [];
  try { notes = await routine(d); } catch (e) { errors.push({ msg: 'routine: ' + e.message, day: d, stack: (e.stack || '').slice(0, 300) }); }
  const snap = await p.evaluate(() => window.BOT.snapshot());
  snap.gameDay = (await p.evaluate(() => R.game.clock.day())) - startDay + 1;
  snap.notes = notes;
  // the newer systems, summarised
  snap.sys = await p.evaluate(() => {
    const g = R.game, pl = g.player, cs = pl.cases ? pl.cases.list : [], m = pl.money || {}, t = pl.turf || {}, v = pl.vend ? pl.vend.list : [], k = pl.killer || {};
    return {
      cases: cs.map((c) => `${c.type}:${c.status}:${Math.round(c.progress)}`).join(' '),
      dirty: Math.round(R.money ? R.money.dirty() : 0), susp: Math.round(m.susp || 0), audits: m.audits || 0,
      wars: (t.wars || []).map((w) => w.a + '-' + w.b).join(' '), grudge: JSON.stringify(t.grudge || {}), lost: Object.keys(t.lost || {}).length,
      avengers: v.filter((x) => x.knows && !x.done).map((x) => x.mode).join(','), suspecting: v.filter((x) => !x.knows && !x.done).length,
      killer: k.profile ? `${k.profile.name}:${k.profile.phase}:${Math.round(k.profile.heat)}` : '', unsolved: (k.unsolved || []).length, poi: Math.round(k.poi || 0),
      family: pl.family, honor: Math.round(pl.rep.honor), infamy: Math.round(pl.rep.infamy),
      name: R.honor ? R.honor.title() : '',
      loans: R.shark ? R.shark.open().length : 0, juice: R.shark ? Math.round(R.shark.state().juice) : 0,
      payroll: R.payroll ? `${R.payroll.weekly()}/wk looked:${R.payroll.state().looked} ia:${R.payroll.state().sweeps}` : '',
      rat: R.rat && R.rat.state().cur ? `${R.rat.state().cur.status}:${Math.round(R.rat.state().cur.progress)}` : '',
      swag: R.hijack ? `${R.hijack.state().trucks}/$${R.hijack.state().earned}` : '',
      desert: R.desert && R.desert.state().shooters ? `${(R.desert.state().done || []).length}/2${R.desert.state().knowsWho ? ' who' : ''}` : '',
    };
  });
  report.days.push(snap);
  if (snap.gameDay >= DAYS) break;
  if (d === 1 || Math.floor(snap.gameDay / 10) !== lastShot) {
    lastShot = Math.floor(snap.gameDay / 10);
    await p.evaluate(() => { const g = R.game; g.ui.closeSheet(); });
    await p.waitForTimeout(200);
    await p.screenshot({ path: join(OUT, `day${String(snap.gameDay).padStart(3, '0')}.png`) });
  }
  if (d % 5 === 0) process.stdout.write(`pass ${d} · game day ${snap.gameDay} · ${((Date.now() - t0) / 1000).toFixed(0)}s · cash ${snap.cash} · people ${snap.people} · p95 ${snap.tickP95}ms · errors ${errors.length}\n`);
}
const bot = await p.evaluate(() => ({ hurts: window.BOT.hurts, acts: window.BOT.acts, crimes: window.BOT.crimes, toasts: window.BOT.toasts, stories: window.BOT.stories, news: R.game.pop.news.slice(0, 80) }));
Object.assign(report, bot);
writeFileSync(join(OUT, 'report.json'), JSON.stringify(report, null, 1));
await browser.close();
console.log(`done: ${DAYS} days in ${((Date.now() - t0) / 1000).toFixed(0)}s, ${errors.length} errors → ${join(OUT, 'report.json')}`);
