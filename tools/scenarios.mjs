// Scenario playtest: drives the newer systems through the real controls (keys, chips,
// menus), screenshots the moments that matter visually, and times frames in busy scenes.
//   node tools/build.mjs && node tools/scenarios.mjs [outDir]
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { mkdirSync, writeFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require('/opt/node22/lib/node_modules/playwright')); }
const OUT = process.argv[2] || join(dirname(fileURLToPath(import.meta.url)), '..', 'playtest-out', 'scenarios');
mkdirSync(OUT, { recursive: true });
const root = 'file://' + join(dirname(fileURLToPath(import.meta.url)), '..', 'dist', 'index.html');
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 });
const p = await ctx.newPage();
const errors = [], notes = [];
p.on('pageerror', (e) => errors.push(e.message + ' @ ' + (e.stack || '').split('\n')[1]));
p.on('console', (m) => { if (m.type() === 'error' && !/fonts|net::/.test(m.text())) errors.push('console: ' + m.text().slice(0, 240)); });
const note = (s) => { notes.push(s); console.log('•', s); };
const shot = async (name) => { await p.screenshot({ path: join(OUT, name + '.png') }); };
const ev = (fn, arg) => p.evaluate(fn, arg);
const wait = (ms) => p.waitForTimeout(ms);
// hold a direction key for ms
const hold = async (keys, ms) => { for (const k of keys) await p.keyboard.down(k); await wait(ms); for (const k of keys) await p.keyboard.up(k); };
// walk toward a world point with WASD for up to ms
const walkTo = async (tx, ty, ms = 6000) => {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const s = await ev(([x, y]) => { const pl = R.game.player; return { dx: x - pl.x, dy: y - pl.y }; }, [tx, ty]);
    if (Math.hypot(s.dx, s.dy) < 10) return true;
    const keys = [];
    if (s.dx > 4) keys.push('KeyD'); if (s.dx < -4) keys.push('KeyA'); if (s.dy > 4) keys.push('KeyS'); if (s.dy < -4) keys.push('KeyW');
    await hold(keys, 180);
  }
  return false;
};
const clearStory = async () => { for (let i = 0; i < 6; i++) { const vis = await ev(() => { const s = document.querySelector('#story'); return s && s.offsetParent !== null; }); if (!vis) return; await p.click('#story button').catch(() => {}); await wait(250); } };

// ---------------------------------------------------------------- 1. the opening, played
await p.goto(root);
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
await p.click('#btnNew'); await wait(700);
await shot('01_name');
// an NPC tries to talk to you while you're naming yourself: the sheet must survive
const held = await ev(() => { const ui = R.game.ui; ui.openSheet('talk', '<p>hi</p>'); ui.closeSheet(); return ui.sheetOpen === 'name' && !!document.querySelector('#nameGo'); });
note(`Name entry survives NPC talk attempts: ${held}.`);
await p.fill('input[data-k="first"]', 'Vito'); await p.fill('input[data-k="last"]', 'Scalise'); await p.fill('input[data-k="nick"]', 'Sideburns');
await p.click('#nameGo'); await wait(800);
await shot('02_desert_card');
await clearStory(); await wait(600);
await shot('03_desert_crawl');
const road = await ev(() => R.opening.road && { x: R.opening.road.x * 16 + 8, y: R.opening.road.y * 16 + 8 });
const start = await ev(() => ({ x: R.game.player.x, y: R.game.player.y }));
if (road) {
  const d0 = Math.hypot(road.x - start.x, road.y - start.y);
  const t0 = Date.now(); await walkTo(road.x, road.y, 9000);
  const d1 = await ev(([x, y]) => Math.hypot(x - R.game.player.x, y - R.game.player.y), [road.x, road.y]);
  note(`Opening crawl: ${Math.round(d0 / 16)} tiles to the highway; after 9s of crawling ${Math.round(d1 / 16)} tiles left (${((d0 - d1) / 16 / ((Date.now() - t0) / 1000)).toFixed(1)} tiles/s).`);
  if (d1 > 20) { await ev(([x, y]) => R.game.player.place(x, y + 20), [road.x, road.y]); await walkTo(road.x, road.y, 3000); }
  await wait(600); await shot('04_headlights');
}
for (let i = 0; i < 30; i++) {
  const st = await ev(() => ({ cut: !!R.game.cutscene, job: !!R.game.jobs.active, story: (() => { const s = document.querySelector('#story'); return s && s.offsetParent !== null; })() }));
  if (process.env.TRACE) console.log('loop', i, JSON.stringify(st), await ev(() => R.game.ui.sheetOpen));
  if (!st.cut && st.job && !st.story) break;
  if (st.story) { await p.click('#story button').catch(() => {}); await wait(300); continue; }
  const o = await p.$$('#sheet .opt, .sheet .opt'); if (o.length) { await o[i % o.length].click().catch(() => {}); }
  await wait(350);
}
await wait(500); await shot('05_backroom');
const opening = await ev(() => ({ fam: R.game.player.family, room: R.game.player.room && R.game.player.room.b.name, job: R.game.jobs.active && R.game.jobs.active.title }));
note(`Opening result: taken in by the ${opening.fam}s, in ${opening.room}, first job "${opening.job}".`);

// ---------------------------------------------------------------- helpers in the page
await ev(() => {
  const g = R.game; window.PT = {};
  PT.tp = (x, y) => { const pl = g.player; if (pl.room) g.interiors.exit(); pl.place(x, y); g.cam.x = x; g.cam.y = y; };
  PT.at = (type, city) => g.world.buildings.find((b) => b && b.type === type && !b.destroyed && (!city || b.city.id === city));
  PT.time = (h) => { g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 1440 + h * 60; };
  PT.street = (c) => { const w = g.world, cc = c || w.cities[1]; return w.findNear(cc.cx, cc.cy, 0, 20, (x, y) => R.data.roadTile[w.t(x, y)] && !w.solidPed(x, y)) || { x: cc.cx, y: cc.cy }; };
});

// ---------------------------------------------------------------- 2. downtown at night: look + frame time
await ev(() => { const g = R.game; if (g.player.room) g.interiors.exit(); PT.time(22); const s = PT.street(); PT.tp(s.x * 16 + 8, s.y * 16 + 8); });
await wait(4000);
await shot('06_downtown_night');
const perf = await ev(async () => { const ms = []; let last = performance.now(); await new Promise((res) => { let n = 0; const f = (t) => { ms.push(t - last); last = t; if (++n < 120) requestAnimationFrame(f); else res(); }; requestAnimationFrame(f); }); ms.sort((a, b) => a - b); return { med: ms[60].toFixed(1), p95: ms[114].toFixed(1), actors: R.game.actors.list.length, cars: R.game.traffic.list.length }; });
note(`Downtown New Avalon at 10 PM: frame median ${perf.med} ms, p95 ${perf.p95} ms with ${perf.actors} actors and ${perf.cars} cars (headless Chromium, software GL).`);
const crowd = await ev(() => ({ workers: R.night.workers.length, barBound: R.game.actors.list.filter((a) => a.goal && a.goal.opts && a.goal.opts.enter).length, curfew: R.game.world.cities.some((c) => c.curfew) }));
note(`Night street: ${crowd.workers} street workers, ${crowd.barBound} people heading into bars.`);

// ---------------------------------------------------------------- 3. interiors: strip club, costume shop, a busy bar
for (const [type, name] of [['strip', '07_strip_club'], ['costume', '08_costume_shop'], ['bar', '09_bar']]) {
  await ev((t) => { const b = PT.at(t, 'avalon') || PT.at(t); PT.time(t === 'costume' ? 14 : 22); PT.tp(b.out.x * 16 + 8, (b.out.y + 1) * 16 + 8); R.game.interiors.enter(b); }, type);
  await wait(1500); await shot(name);
  const n = await ev(() => R.game.actors.list.filter((a) => a.room === R.game.player.room && !a.dead).length);
  note(`${type} interior: ${n} people inside.`);
}
await ev(() => R.game.interiors.exit());

// ---------------------------------------------------------------- 4. violence through the real buttons
await ev(() => { const g = R.game, pl = g.player; PT.time(13); R.testRooms.go(g, 'arena'); R.testRooms.active = null; for (const a of g.actors.list.slice()) if (a !== pl) g.actors.remove(a); g.cheats.god = true; g.cheats.noLaw = true; pl.giveWeapon('shotgun'); pl.inv.ammo.shells = 40; pl.clip.shotgun = 5; pl.weapon = 'shotgun'; pl.weaponOut = true; pl.ang = 0; const h = g.actors.makeHuman(pl.x + 22, pl.y, {}); h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; window.PT.target = h; });
await wait(300);
const pre = await ev(() => ({ clip: R.game.player.clip.shotgun, modal: R.game.ui.modalOpen(), sheet: R.game.ui.sheetOpen, paused: R.game.ui.paused(), cut: !!R.game.cutscene, room: !!R.game.player.room }));
await p.keyboard.down('Space'); await wait(120); await p.keyboard.up('Space'); await wait(700);
const post = await ev(() => R.game.player.clip.shotgun);
note(`Before SPACE: ${JSON.stringify(pre)}; clip after ${post}.`);
const burst = await ev(() => ({ dead: PT.target.dead, burst: !!(PT.target.wnd && PT.target.wnd.burst), headless: !!(PT.target.wnd && PT.target.wnd.headless) }));
note(`Shotgun at 1.4 tiles via SPACE: dead=${burst.dead}, head burst=${burst.burst}, headless=${burst.headless}.`);
await shot('10_shotgun');
// knife work with USE
await ev(() => { const g = R.game, pl = g.player; pl.giveWeapon('knife'); pl.weapon = 'knife'; pl.weaponOut = false; const b = PT.target; pl.place(b.x - 10, b.y); b.looted = true; });
await wait(200);
await p.keyboard.press('KeyE'); await wait(300);
let opts = await ev(() => [...document.querySelectorAll('.opt')].filter((o) => o.offsetParent !== null).map((o) => o.textContent));
note(`USE on the body with a knife offers: ${opts.join(' | ').slice(0, 160)}`);
const cut = await p.$('.opt:has-text("Cut up")'); if (cut) { await cut.click(); await wait(300); }
const limbs = await p.$('.opt:has-text("arms and legs")'); if (limbs) { await limbs.click(); await wait(900); }
await shot('11_butchered');
// wagon: pick up and walk
await clearStory();
await p.keyboard.press('KeyE'); await wait(300);
const pick = await p.$('.opt:has-text("Pick up")'); if (pick) { await pick.click(); await wait(300); }
const carrying = await ev(() => !!R.game.player.carrying);
await hold(['KeyD'], 900); await hold(['KeyS'], 700);
await shot('12_wagon');
note(`Carry via USE menu: carrying=${carrying}.`);
await ev(() => { const pl = R.game.player; if (pl.carrying) R.bodies.putDown(); });

// ---------------------------------------------------------------- 5. masks and the flirt chip
await ev(() => { const g = R.game, pl = g.player; const s = PT.street(g.world.cities[0]); PT.time(15); PT.tp(s.x * 16 + 8, s.y * 16 + 8); pl.inv.masks = { clown: 1 }; pl.inv.tools.mask = 1; pl.style.maskKind = 'clown'; pl.weaponOut = false; });
await p.keyboard.press('KeyM'); await wait(200); await hold(['KeyD'], 600); await wait(300);
await shot('13_clown_mask');
await p.keyboard.press('KeyM'); await wait(200);
await ev(() => { const g = R.game, pl = g.player; const h = g.actors.makeHuman(pl.x + 14, pl.y, { arch: 'flirt' }); h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; pl.focus = h; window.PT.date = h; });
await wait(600);
const chips = await ev(() => [...document.querySelectorAll('#ctx .chip')].filter((b) => b.offsetParent !== null).map((b) => b.textContent));
note(`Interaction chips next to someone: ${chips.join(' | ')}`);
const fl = await p.$('#ctx .c-flirt'); if (fl) { await fl.dispatchEvent('pointerdown'); await wait(1200); }
await shot('14_flirt');

// ---------------------------------------------------------------- 6. menus: heat, jobs, map, paper
await ev(() => { const g = R.game; g.cheats.noLaw = false; const h = g.actors.makeHuman(g.player.x + 20, g.player.y, {}); const w = g.actors.makeHuman(g.player.x - 30, g.player.y, {}); h.keep = w.keep = true; g.player.giveWeapon('revolver'); g.player.weapon = 'revolver'; R.combat.kill(h, g.player, 'bullet'); });
await wait(400);
for (const [tab, name] of [['heat', '15_heat'], ['jobs', '16_jobs'], ['map', '17_map'], ['news', '18_paper']]) { await ev((t) => { R.game.ui.closeSheet(); R.game.ui.openMenu(t); }, tab); await wait(500); await shot(name); }
await ev(() => R.game.ui.closeSheet());

// ---------------------------------------------------------------- 7. the landmark art and a story NPC in daylight
await ev(() => { const P = R.salvage.PLACES.find((q) => q.id === 'plane' && q.at) || R.salvage.PLACES.find((q) => q.at); PT.time(11); PT.tp((P.at.x + 1.5) * 16, (P.at.y + 3) * 16); });
await wait(1500); await shot('19_landmark');
await ev(() => { const P = R.stories.PEOPLE.vera, c = R.game.jobs.cityOfFamily(P.city), b = c.buildings.find((x) => x && P.where.includes(x.type)); PT.time(20); R.stories.t = 0; PT.tp(b.out.x * 16 + 8, (b.out.y + 3) * 16 + 8); });
await wait(2500); await shot('20_story_npc');

writeFileSync(join(OUT, 'notes.json'), JSON.stringify({ notes, errors }, null, 1));
console.log(`\n${notes.length} notes, ${errors.length} errors`);
for (const e of errors.slice(0, 12)) console.log('ERR', e);
await browser.close();
