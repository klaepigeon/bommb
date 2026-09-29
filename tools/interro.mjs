// Interrogation and kidnapping, in either game:
//   node tools/interro.mjs            (game 1: dist/rhapsody.html)
//   node tools/interro.mjs sequel     (XX8X: sequel/dist/index.html)
// Knock someone out, pick them up in one tap, put them down, tie them up; hold someone at
// gunpoint and knock them out; interrogate a captive (ask, threaten, hurt) until they
// break, then ask what they know; let one go.
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const sequel = process.argv[2] === 'sequel';
const url = 'file://' + (sequel ? join(ROOT, 'sequel/dist/index.html') : join(ROOT, 'dist/rhapsody.html')) + '?quick';
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 844, height: 390 } })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' | ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
await p.goto(url);
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
const log = [];
const run = (fn, arg) => p.evaluate(fn, arg).catch((e) => { console.log(log.join('\n')); throw e; });
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
await p.click('#btnNew');
await p.waitForTimeout(1200);
// get past any opening: skip cutscenes and stories
await run(() => {
  const g = R.game;
  if (R.opening && R.opening.active && R.opening.skip) R.opening.skip();
  for (let i = 0; i < 8; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } }
  g.ui.closeSheet && g.ui.closeSheet();
  if (g.cutscene) g.cutscene = null;
  if (g.player.room && g.interiors.exit) g.interiors.exit();
  if (R.opening) { R.opening.lock = null; R.opening.active = false; }
});
await p.waitForTimeout(300);
const r = await run(() => {
  const g = R.game, pl = g.player, out = {};
  const clear = () => { for (const q of g.actors.list.slice()) if (q !== pl && q.kind === 'h' && Math.hypot(q.x - pl.x, q.y - pl.y) < 80) g.actors.remove(q); g.ui.closeSheet(); };
  const person = () => g.pop.people.find((q) => q.alive && !q.isDon && q.role !== 'cop' && q.age > 20 && !q.actor && q.faction && q.faction !== 'law') || g.pop.people.find((q) => q.alive && !q.isDon && q.role !== 'cop' && q.age > 20 && !q.actor);
  const spawn = (setup) => { const p = person(); g.life.spawnPerson(p, pl.x + 14, pl.y); const h = p.actor; h.hostile = false; if (setup) setup(h); g.tick(1 / 60); h.x = pl.x + 14; h.y = pl.y; if (setup) setup(h); g.tick(1 / 60); return h; };
  // 1. out cold: one tap picks them up
  clear();
  let h = spawn((q) => { q.down = 30; q.hp = 1; q.state = 'down'; });
  let a = pl.contextAction();
  out.koLabel = a && a.label;
  if (a && a.label === 'Pick them up') a.fn();
  out.carrying = !!pl.carrying;
  R.bodies.putDown();
  out.stillOut = h.down > 10;
  // 2. hands up: knock them out
  clear();
  h = spawn((q) => { q.state = 'surrender'; q.timer = 30; q.stay = true; });
  a = pl.contextAction();
  out.surrLabel = a && a.label;
  R.interro.ko(h);
  out.koWorked = h.down > 30;
  // 3. tie one up and interrogate
  clear();
  h = spawn(); h.down = 0; h.hp = 100; h.maxHp = 100;
  pl.inv.tools.rope = 2; R.bodies.tie(h);
  pl.giveWeapon('knife'); pl.weapon = 'knife';
  a = pl.contextAction();
  out.tiedLabel = a && a.label;
  R.interro.open(h);
  out.sheet = !!document.querySelector('.sheet') && /Interrogating/.test(document.querySelector('.sheet').textContent);
  const s = R.interro.state(h);
  out.resolve0 = s.resolve;
  R.interro.act(h, 'threat');
  let n = 0;
  while (!s.broken && !h.dead && !(h.down > 0) && n++ < 10) R.interro.act(h, h.hp > 40 ? 'hurt' : 'rough');
  out.broken = s.broken; out.dead = h.dead; out.hp = Math.round(h.hp);
  if (s.broken) {
    const qs = R.interro.questions(h);
    out.questions = qs.map((q) => q.label);
    const cash0 = pl.cash;
    const money = qs.find((q) => /money/.test(q.label)); if (money) money.fn();
    out.cashGot = pl.cash - cash0;
    const combo = R.interro.questions(h).find((q) => /combination/.test(q.label)); if (combo) combo.fn();
    out.line = s.line;
  }
  R.interro.release(h);
  out.freed = !h.tied;
  g.ui.closeSheet();
  return out;
});
check(r.koLabel === 'Pick them up' && r.carrying, `someone out cold: "${r.koLabel}" in one tap, over the shoulder`);
check(r.stillOut, 'put down, they stay out a while');
check(/Interrogate|[A-Z]/.test(r.surrLabel || '') && r.koWorked, `hands up: "${r.surrLabel}" (interrogate, or knock them out)`);
check(r.sheet && r.tiedLabel, `a tied captive: "${r.tiedLabel}" opens the interrogation (resolve ${r.resolve0})`);
check(r.broken && !r.dead, `threats and pain break them (hp ${r.hp}): they'll answer ${r.questions ? r.questions.length : 0} questions`);
check(r.cashGot > 0, `"Where's your money?" (+$${r.cashGot}) · ${r.line}`);
check(r.freed, 'and you can let them go');
await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('interro ok (' + (sequel ? 'XX8X' : 'game 1') + ')');
