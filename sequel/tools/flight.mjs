// The flight test: the controls a new pilot meets. Hanging next to Earth without falling in,
// the stick flying you where it points, letting go to brake, USE in open space for the
// "Where to?" menu, and the autopilot flying all the way to Luna, to Mars and to a station,
// then landing and docking.
//   node tools/flight.mjs [screenshot-dir]
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
const shot = async (name) => { if (SHOTS) await p.screenshot({ path: join(SHOTS, `flight_${name}.png`) }); };
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
const closeAll = () => run(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet && R.game.ui.closeSheet(); });

await p.click('#btnNew');
await p.waitForTimeout(900);
await closeAll();
await run(() => { BS2.SQ.flags.clamp = 0; BS2.launch(R.game); for (let i = 0; i < 10; i++) R.game.tick(1 / 60); });
await closeAll();

// hands off, next to Earth: the drive holds you there
const hover = await run(() => {
  const g = R.game, S = BS2.SPACE, e = () => BS2.SPACE.B.find((q) => q.id === 'earth');
  const alt0 = Math.hypot(S.x - e().x, S.y - e().y) - e().r;
  for (let i = 0; i < 600; i++) g.tick(1 / 60);
  const alt1 = Math.hypot(S.x - e().x, S.y - e().y) - e().r;
  return { alt0: Math.round(alt0), alt1: Math.round(alt1), rel: Math.round(Math.hypot(S.vx - e().vx / 60, S.vy - e().vy / 60)) };
});
check(hover.alt1 > 30 && Math.abs(hover.alt1 - hover.alt0) < 60 && hover.rel < 20, `hands off over Earth, the ship holds: altitude ${hover.alt0} → ${hover.alt1}, drift ${hover.rel}`);

// push the stick: you go where it points; let go: you stop
const stick = await run(() => {
  const g = R.game, S = BS2.SPACE, e = () => BS2.SPACE.B.find((q) => q.id === 'earth');
  const out = Math.atan2(S.y - e().y, S.x - e().x);
  g.input.touchStick = { r: 1, ox: 0, oy: 0, x: Math.cos(out), y: Math.sin(out) };
  const x0 = S.x, y0 = S.y;
  for (let i = 0; i < 120; i++) g.tick(1 / 60);
  const moved = Math.hypot(S.x - x0, S.y - y0), heading = Math.cos(Math.atan2(S.y - y0, S.x - x0) - out);
  const fast = Math.round(Math.hypot(S.vx - e().vx / 60, S.vy - e().vy / 60));
  g.input.touchStick = null;
  for (let i = 0; i < 150; i++) g.tick(1 / 60);
  return { moved: Math.round(moved), heading: +heading.toFixed(2), fast, after: Math.round(Math.hypot(S.vx - e().vx / 60, S.vy - e().vy / 60)) };
});
check(stick.moved > 300 && stick.heading > 0.95 && stick.fast > 300, `the stick flies you where it points: ${stick.moved} units in 2 s at ${stick.fast}`);
check(stick.after < 15, `let go and the ship brakes to a stop (${stick.after})`);

// USE in open space: where to?
const menu = await run(() => {
  const g = R.game, S = BS2.SPACE, e = BS2.SPACE.B.find((q) => q.id === 'earth');
  const a = Math.atan2(S.y - e.y, S.x - e.x); S.x = e.x + Math.cos(a) * (e.r + 900); S.y = e.y + Math.sin(a) * (e.r + 900);
  g.input.pressed = ((base) => { let once = true; return (k) => (k === 'use' && once ? ((once = false), true) : base.call(g.input, k)); })(g.input.pressed);
  g.tick(1 / 60);
  const opts = [...document.querySelectorAll('.sheet button')].map((x) => x.textContent);
  return { title: (document.querySelector('.sheet') || {}).textContent || '', opts: opts.slice(0, 6) };
});
check(/Where to\?/.test(menu.title) && menu.opts.some((o) => /Luna/.test(o)), `USE in open space: "Where to?" (${menu.opts.slice(0, 4).join(' | ')})`);
await shot('whereto');

const fly = async (label, secs) => run(({ label, secs }) => {
  const g = R.game, S = BS2.SPACE;
  g.ui.closeSheet();
  const t = BS2.navTargets().find((n) => n.name === label || n.id === label);
  BS2.autopilot(g, t);
  let n = 0;
  for (; n < secs * 60 && S.auto; n++) g.tick(1 / 60);
  const q = t.pos();
  return { arrived: !S.auto, secs: Math.round(n / 60), d: Math.round(Math.hypot(q.x - S.x, q.y - S.y) - t.r), near: BS2.nearPlanetId && BS2.nearPlanetId() };
}, { label, secs });
const luna = await fly('luna', 120);
check(luna.arrived && luna.near === 'luna', `autopilot to Luna: arrived in ${luna.secs} s, holding ${luna.d} out`);
await shot('luna');
const mars = await fly('mars', 400);
check(mars.arrived && mars.near === 'mars', `autopilot to Mars across 0.5+ AU: arrived in ${mars.secs} s, holding ${mars.d} out`);
await shot('mars');
const land = await run(() => {
  const g = R.game;
  g.input.pressed = ((base) => { let once = true; return (k) => (k === 'use' && once ? ((once = false), true) : base.call(g.input, k)); })(g.input.pressed);
  g.tick(1 / 60);
  return { space: BS2.SPACE.active, planet: BS2.SQ.planet };
});
check(!land.space && land.planet === 'mars', 'and USE lands on Mars');
await closeAll();
const dock = await run(() => {
  const g = R.game, S = BS2.SPACE;
  BS2.launch(g); for (let i = 0; i < 5; i++) g.tick(1 / 60);
  g.ui.closeSheet();
  const t = BS2.navTargets().find((n) => n.kind === 'station' && /Red Velvet/.test(n.name));
  BS2.autopilot(g, t);
  let n = 0;
  for (; n < 120 * 60 && S.auto; n++) g.tick(1 / 60);
  const q = t.pos();
  return { arrived: !S.auto, secs: Math.round(n / 60), d: Math.round(Math.hypot(q.x - S.x, q.y - S.y)) };
});
check(dock.arrived && dock.d < 90, `autopilot to the Red Velvet Orbital: ${dock.secs} s, ${dock.d} from the hub (in docking range)`);
await shot('station');
// taking the stick cancels it
const over = await run(() => {
  const g = R.game, S = BS2.SPACE;
  BS2.autopilot(g, BS2.navTargets().find((n) => n.id === 'venus'));
  for (let i = 0; i < 30; i++) g.tick(1 / 60);
  g.input.touchStick = { r: 1, ox: 0, oy: 0, x: 1, y: 0 }; g.tick(1 / 60); g.input.touchStick = null;
  return { auto: !!S.auto };
});
check(!over.auto, 'touching the stick hands control back');

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('flight ok');
