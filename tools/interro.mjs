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
  R.interro.knockOut(h);
  let a = pl.contextAction();
  out.koLabel = a && a.label;
  if (a) a.fn();
  const pick = [...document.querySelectorAll('.sheet button')].find((x) => /Pick them up/.test(x.textContent)); if (pick) pick.click();
  out.carrying = !!pl.carrying;
  R.bodies.putDown();
  out.stillOut = h.down > 10;
  // out for a day: an hour later still out; wake them yourself
  g.clock.t += 60; for (let i = 0; i < 70; i++) g.tick(1 / 60);
  out.hourLater = h.down > 10 && !!h.koUntil;
  clear(); h = spawn((q) => { R.interro.knockOut(q); q.hp = 1; q.state = 'down'; });
  a = pl.contextAction(); if (a) a.fn();
  const wk = [...document.querySelectorAll('.sheet button')].find((x) => /Wake them up/.test(x.textContent)); if (wk) wk.click();
  for (let i = 0; i < 5; i++) g.tick(1 / 60);
  out.woken = !h.koUntil && !(h.down > 1);
  // a day later they come round on their own
  clear(); h = spawn((q) => { R.interro.knockOut(q); q.hp = 1; q.state = 'down'; });
  pl.place(pl.x + 400, pl.y); g.clock.t += 1441; for (let i = 0; i < 70; i++) g.tick(1 / 60);
  out.dayLater = !h.koUntil;
  // a passer-by who finds them wakes them
  clear(); h = spawn((q) => { R.interro.knockOut(q); q.hp = 1; q.state = 'down'; });
  const hx = h.x, hy = h.y;
  pl.place(pl.x + 300, pl.y);
  const q2 = g.actors.makeHuman(hx + 10, hy, {}); q2.hostile = false; q2.state = 'idle'; q2.stay = true; q2.timer = 99;
  for (let i = 0; i < 60 * 6; i++) { q2.x = hx + 10; q2.y = hy; g.tick(1 / 60); }
  out.passerby = !h.koUntil;
  pl.place(pl.x - 700, pl.y);
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
check(r.koLabel === 'Out cold' && r.carrying, `someone out cold: "${r.koLabel}" → Pick them up, over the shoulder`);
check(r.stillOut && r.hourLater, 'put down, they stay out (still out an hour later)');
check(r.woken, '"Wake them up" brings them round');
check(r.dayLater, 'left alone, they come round a day later');
check(r.passerby, 'a passer-by who finds them wakes them up');
check(/Interrogate|[A-Z]/.test(r.surrLabel || '') && r.koWorked, `hands up: "${r.surrLabel}" (interrogate, or knock them out)`);
check(r.sheet && r.tiedLabel, `a tied captive: "${r.tiedLabel}" opens the interrogation (resolve ${r.resolve0})`);
check(r.broken && !r.dead, `threats and pain break them (hp ${r.hp}): they'll answer ${r.questions ? r.questions.length : 0} questions`);
check(r.cashGot > 0, `"Where's your money?" (+$${r.cashGot}) · ${r.line}`);
check(r.freed, 'and you can let them go');
const det = await run(() => {
  const g = R.game, pl = g.player, CS = R.cases, s = CS.state();
  s.list.push({ id: 991, status: 'open', type: 'murder', name: 'Murder', where: 'Downtown', jur: g.law.jurAt(pl.x, pl.y), det: 'Det. Frank Mullane', progress: 80, bounty: 200, witnesses: [{ name: 'Joe', gone: false }], day: g.pop.day, lastT: g.clock.t, evidence: [] });
  const h = g.actors.makeHuman(pl.x + 20, pl.y, { cop: true }); h.detectiveFor = 991; h.strangerName = 'Det. Frank Mullane';
  R.combat.kill(h, pl, 'bullet');
  const c = s.list.find((k) => k.id === 991);
  return { progress: c.progress, det: c.det, stalled: c.stalledUntil > g.clock.t, witness: c.witnesses[0].gone };
});
check(det.progress < 40 && det.det !== 'Det. Frank Mullane' && det.stalled && det.witness, `killing the detective wrecks the case: progress 80 → ${det.progress}, stalled, a witness gone, ${det.det} takes over`);
await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('interro ok (' + (sequel ? 'XX8X' : 'game 1') + ')');
