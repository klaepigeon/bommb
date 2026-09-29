// The Earth test: the planet-sized Earth tech demo and the new opening. Plays through the real
// game: Big Tav's opening and the clamp on your ship, a Syndicate job at triple pay, the
// peoples of the future, the real continents, walking across sector borders, the ocean that
// stops you, calling your ship, and choosing a landing zone from orbit.
//   node tools/earth.mjs [screenshot-dir]
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
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `earth_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const tick = (n) => run((n) => { for (let i = 0; i < n; i++) R.game.tick(1 / 60); R.game.renderer.render(); }, n);
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });

await p.click('#btnNew');
await p.waitForTimeout(900);
const intro = await run(() => ({ title: document.querySelector('#story h1').textContent, text: document.querySelector('#story p').textContent }));
check(/Earth/.test(intro.title) && /Fear Man/.test(intro.text) && /clamp/.test(intro.text), `the opening: "${intro.title}" (the Fear Man, the clamp)`);
await shot('intro');
await closeAll();

// ---------------------------------------------------------------- the Syndicate and its people
const start = await run(() => {
  const g = R.game, ps = g.pop.people, by = {};
  for (const q of ps) if (q.look && q.look.xeno) by[q.look.xeno] = (by[q.look.xeno] || 0) + 1;
  const don = ps.find((q) => q.isDon && q.faction === 'Vane');
  const robot = ps.find((q) => q.look && q.look.xeno === 'robot');
  return { city: g.world.cities[0].name, cash: g.player.cash, clamp: BS2.SQ.flags.clamp, don: don && g.pop.name(don), donXeno: don && don.look.xeno, by, robot: robot && g.pop.name(robot), job: g.jobs.active && g.jobs.active.title, weather: g.env.WEATHER_NAMES[g.env.weather.kind] };
});
check(start.city === 'Port Hollow' && start.cash >= 600 && start.clamp === 1, `start on the Brass Coast with ${start.cash} credits and a clamped ship`);
check(start.donXeno === 'fearman', `the boss of Earth is an alien: ${start.don}`);
check(start.by.cyborg > 20 && start.by.robot > 10 && start.by.mutant > 10 && start.by.android > 5, `the people of the future: ${Object.entries(start.by).map(([k, v]) => v + ' ' + k).join(', ')} (a robot: ${start.robot})`);
check(/Acid Rain|Smog|Toxic|Haze|Heat Dome/.test(start.weather), `Earth's sky: ${start.weather}`);
const names = await run(() => ({ gun: R.data.weapons.revolver.name, bar: R.data.btypes.bar.name, car: R.data.vehicles.sedan.name }));
check(names.gun === 'Blaster Pistol' && names.bar === 'Cantina' && /Hover/.test(names.car), `the future's gear: ${names.gun}, ${names.bar}, ${names.car}`);
// the ship won't launch clamped
const clamped = await run(() => {
  const g = R.game, pl = g.player, w = g.world; pl.place(w.pad.sx - 20, w.pad.sy + 30); pl.contextAction().fn();
  return [...document.querySelectorAll('.sheet .opt, .sheet button')].map((x) => x.textContent).find((t) => /Launch/.test(t));
});
check(/clamped/.test(clamped || ''), `the ship menu says "${(clamped || '').slice(0, 16)}"`);
await closeAll();
// one Syndicate job, at triple pay, takes the clamp off
const job = await run(() => {
  const g = R.game, j = g.jobs.active, c0 = g.player.cash, reward = j.reward;
  g.jobs.complete(j);
  return { paid: g.player.cash - c0, reward };
});
await p.waitForTimeout(200);
check(job.paid === job.reward * 3, `the Fear Man's job paid triple: ${job.paid} (base ${job.reward})`);
check(await run(() => BS2.SQ.flags.clamp === 0), 'the job took the clamp off the ship');
await closeAll();
await tick(30);
await shot('home');

// ---------------------------------------------------------------- the planet
const planet = await run(() => {
  const f = (x, y) => Math.round(BS2.landFrac(x, y) * 100);
  return { sahara: f(38, 12), pacific: f(0, 17), london: f(35, 7), australia: f(62, 23), atlantic: f(30, 14), home: f(12, 10) };
});
check(planet.sahara > 80 && planet.australia > 60 && planet.pacific < 5 && planet.atlantic < 10, `real continents: Sahara ${planet.sahara}% land, Australia ${planet.australia}%, mid-Pacific ${planet.pacific}%, mid-Atlantic ${planet.atlantic}%`);
// walk east out of the Brass Coast into the next sector
const cross = await run(() => {
  const g = R.game, w = g.world;
  g.player.place((w.W - 2) * 16, g.player.y);
  const t = performance.now();
  g.tick(1 / 60);
  const ms = Math.round(performance.now() - t), pl = R.game.player;
  return { ms, sector: BS2.SQ.sector.join(','), city: R.game.world.cities[0].name, x: Math.round(pl.x / 16), ok: !R.game.world.isWater((pl.x / 16) | 0, (pl.y / 16) | 0) };
});
check(cross.sector === '13,10' && cross.x < 60 && cross.ok, `walked east across the border into sector ${cross.sector} (${cross.city}), built in ${cross.ms}ms`);
await tick(30);
await shot('next_sector');
// the ship is back on the coast; call it
const call = await run(() => {
  const g = R.game, pl = g.player, w = g.world; pl.place(w.pad.sx - 20, w.pad.sy + 30);
  // passers-by near the pad would take the context button: clear them
  for (const q of g.actors.list.slice()) if (q !== pl && Math.hypot(q.x - pl.x, q.y - pl.y) < 120) g.actors.remove(q);
  const a = pl.contextAction(); const label = a && a.label; if (a) a.fn();
  return { label, here: BS2.SQ.shipAt.join(',') === BS2.SQ.sector.join(','), menu: pl.contextAction() && pl.contextAction().label };
});
check(/^Call /.test(call.label || '') && call.here && call.menu === 'Brass Buzzard', `an empty pad offers "${call.label}", and the ship comes`);
// the ocean stops you: find a coast whose next sector east is open sea
const sea = await run(() => {
  let found = null;
  for (let y = 5; y < 30 && !found; y++) for (let x = 0; x < 72 && !found; x++) if (BS2.landFrac(x, y) > 0.5 && BS2.landFrac((x + 1) % 72, y) < 0.02) found = [x, y];
  const g = R.game; BS2.SQ.sector = found; BS2.SQ.arriving = true; g.setup(0, null);
  const w = R.game.world, pl = R.game.player;
  pl.place((w.W - 2) * 16, pl.y);
  R.game.tick(1 / 60);
  return { at: found.join(','), still: BS2.SQ.sector.join(','), x: Math.round(R.game.player.x / 16), W: w.W };
});
check(sea.still === sea.at && sea.x < sea.W - 2, `open ocean east of sector ${sea.at} turns you back`);

// ---------------------------------------------------------------- from orbit
await run(() => { const g = R.game; BS2.SQ.sector = [12, 10]; BS2.SQ.shipAt = [12, 10]; BS2.SQ.arriving = true; g.setup(0, null); BS2.SQ.flags.clamp = 0; });
const orbit = await run(() => { const g = R.game; BS2.launch(g); for (let i = 0; i < 10; i++) g.tick(1 / 60); g.renderer.render(); const e = BS2.SPACE.B.find((b) => b.id === 'earth'); return { r: e.r, active: BS2.SPACE.active }; });
check(orbit.active && orbit.r > 1000, `in orbit over a much bigger Earth (radius ${orbit.r})`);
await shot('orbit');
await run(() => { const S = BS2.SPACE, e = S.B.find((b) => b.id === 'earth'); S.zoom = 0.1; S.x = e.x + 1500; S.y = e.y; R.game.renderer.render(); });
await shot('earth_from_space');
// come down somewhere new: Japan, picked on the planet map
const lz = await run(() => {
  const g = R.game, S = BS2.SPACE, m = S.B.find((b) => b.id === 'earth');
  S.zoom = 1; S.x = m.x + m.r + 60; S.y = m.y; S.vx = m.vx / 60; S.vy = m.vy / 60;
  g.input.pressedA.use = true; g.tick(1 / 60);
  const cv = document.querySelector('.sheet canvas');
  if (!cv) return { sheet: false };
  const r = cv.getBoundingClientRect();
  const x = r.left + ((63 + 0.5) / 72) * r.width, y = r.top + ((10 + 0.5) / 36) * r.height;
  cv.dispatchEvent(new PointerEvent('pointerdown', { clientX: x, clientY: y, bubbles: true }));
  const info = document.querySelector('#lzinfo').textContent;
  document.querySelector('[data-lz="pick"]').click();
  for (let i = 0; i < 20; i++) R.game.tick(1 / 60);
  return { sheet: true, info, sector: BS2.SQ.sector.join(','), city: R.game.world.cities.map((c) => c.name).join(', '), space: BS2.SPACE.active };
});
check(lz.sheet, 'landing on Earth opens the planet map');
check(lz.sector === '63,10' && !lz.space, `picked Japan and came down there: ${lz.info} · ${lz.city}`);
await closeAll();
await tick(40);
await shot('japan');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('earth ok');
