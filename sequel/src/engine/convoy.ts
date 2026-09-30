// Convoys. Now and then a lone freighter inbound to one of the worlds calls for an escort:
// the lanes are thick with raiders and her own guns are a joke. Fly alongside and USE to take
// the job, then see her down: raiders come out of the dark twice on the way in, and they go
// for her, not you. Get her to the world alive and her captain pays, plus a bonus for every
// raider you put down. Lose her and you get nothing but the mayday on the radio.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, spawnCraft, burst, nearPlanet, type Craft } from './space';
import { BODY, landable } from './planets';
import { fmt } from './bounty';

interface Convoy { c: Craft; to: string; pay: number; state: 'offer' | 'on' | 'done' | 'lost'; start: number; waves: number; raiders: Craft[]; hitT: number }
export const CONVOY = { cur: null as Convoy | null, next: 150, done: 0 };
const NAMES = ['Brass Mule', 'Aunt Delphine', 'Halcyon Days', 'Sweet Loretta', 'Iron Pelican', 'Cold Comfort', 'Saturday Night'];
const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];
const body = (id: string) => (SPACE.B || []).find((b) => b.id === id);

export function spawnConvoy(g: Game): Convoy | null {
  const worlds = landable().map((id) => body(id)).filter(Boolean) as NonNullable<ReturnType<typeof body>>[];
  if (!worlds.length) return null;
  const w = worlds.sort((a, b) => Math.hypot(a.x - SPACE.x, a.y - SPACE.y) - Math.hypot(b.x - SPACE.x, b.y - SPACE.y))[0];
  const c = spawnCraft('freighter', false, 380);
  // head her in from out here: far enough out to be a trip, not so far it's a chore
  const d = Math.hypot(w.x - SPACE.x, w.y - SPACE.y);
  if (d > 9000) { const a = Math.atan2(SPACE.y - w.y, SPACE.x - w.x); c.x = w.x + Math.cos(a) * 6000; c.y = w.y + Math.sin(a) * 6000; }
  c.vx = w.vx / 60; c.vy = w.vy / 60;
  c.name = pick(NAMES); c.target = w.id as any; c.flag = 'solari'; (c as any).noHail = true;
  const cv: Convoy = { c, to: w.id, pay: 600 + Math.floor(Math.random() * 7) * 100, state: 'offer', start: Math.hypot(w.x - c.x, w.y - c.y), waves: 0, raiders: [], hitT: 0 };
  CONVOY.cur = cv;
  g.ui.toast(`${c.name}, inbound for ${BODY[w.id].name}: "Any ship on this band, we need an escort. Raiders on the lane. We pay." (Fly alongside, USE.)`, 'warn');
  g.audio.sfx('click');
  return cv;
}
function raid(g: Game, cv: Convoy): void {
  cv.waves++;
  for (let k = 0; k < 2; k++) {
    const r = spawnCraft('hunter', true, 0);
    const a = Math.random() * 7; r.x = cv.c.x + Math.cos(a) * 500; r.y = cv.c.y + Math.sin(a) * 500; r.vx = cv.c.vx; r.vy = cv.c.vy;
    r.name = 'Raider'; (r as any).raider = true; cv.raiders.push(r);
  }
  g.ui.toast(`${cv.c.name}: "Raiders! Two of them, coming in on us!"`, 'bad');
  g.audio.sfx('alarm');
}

HOOKS.use.push((g) => {
  const cv = CONVOY.cur;
  // low over a world, USE means land: take the job out here instead
  if (!cv || cv.state !== 'offer' || cv.c.dead || nearPlanet() || Math.hypot(cv.c.x - SPACE.x, cv.c.y - SPACE.y) > 260) return null;
  return { label: 'Escort', fn: () => g.ui.choice(`${cv.c.name} · escort to ${BODY[cv.to].name}`, [
    { label: `Take the job (${fmt(cv.pay)})`, small: '+ 150 for each raider you put down. Keep her alive.', fn: () => { cv.state = 'on'; g.ui.toast(`Escorting ${cv.c.name} in to ${BODY[cv.to].name}. Stay close.`, 'good'); } },
    { label: 'Not my problem', fn: () => { cv.state = 'done'; CONVOY.cur = null; } },
  ]) };
});
HOOKS.update.push((g, dt) => {
  const cv = CONVOY.cur;
  if (!SPACE.active) return;
  if (!cv) {
    if (SPACE.cruise || SPACE.auto || SQ.system !== 'sol') return;
    CONVOY.next -= dt;
    if (CONVOY.next <= 0) { CONVOY.next = 240 + Math.random() * 200; if (Math.random() < 0.5) spawnConvoy(g); }
    return;
  }
  const c = cv.c, w = body(cv.to);
  if (!w || (cv.state === 'offer' && Math.hypot(c.x - SPACE.x, c.y - SPACE.y) > 20000)) { CONVOY.cur = null; return; }
  if (cv.state !== 'on') return;
  // she doesn't stop for anyone, and she can't be talked into firing back
  c.hostile = false;
  if (c.dead || c.disabled) {
    cv.state = 'lost'; CONVOY.cur = null;
    g.ui.toast(`${c.name} goes silent. The mayday cuts off mid-word.`, 'bad');
    return;
  }
  const d = Math.hypot(w.x - c.x, w.y - c.y), prog = 1 - (d - w.r) / Math.max(1, cv.start - w.r);
  if ((cv.waves === 0 && prog > 0.25) || (cv.waves === 1 && prog > 0.6)) raid(g, cv);
  // the raiders shoot at her when they're close
  cv.hitT -= dt;
  if (cv.hitT <= 0) {
    cv.hitT = 1.2;
    for (const r of cv.raiders) if (!r.dead && Math.hypot(r.x - c.x, r.y - c.y) < 380) {
      if (c.shield > 0) c.shield = Math.max(0, c.shield - 7); else c.hull -= 7;
      burst(c.x, c.y, 3, ['#78ff98', '#ffffff'], c.vx, c.vy);
    }
  }
  if (d < w.r + 300) {
    const kills = cv.raiders.filter((r) => r.dead).length, pay = cv.pay + kills * 150;
    g.player.cash += pay; g.player.rep.honor = (g.player.rep.honor || 0) + 2;
    cv.state = 'done'; CONVOY.cur = null; CONVOY.done++;
    SQ.achieved = SQ.achieved || {}; SQ.achieved.convoys = (SQ.achieved.convoys || 0) + 1; saveSequel();
    g.audio.sfx('cash');
    g.ui.toast(`${c.name} is down safe at ${BODY[cv.to].name}. Her captain wires ${fmt(pay)}${kills ? ` (${kills} raider${kills > 1 ? 's' : ''} down)` : ''}.`, 'good');
  }
});
HOOKS.draw.push((v) => {
  const cv = CONVOY.cur;
  if (!cv || cv.c.dead) return;
  v.mark(cv.c.x, cv.c.y, '#68f0a0', cv.state === 'offer' ? 'ESCORT?' : 'CONVOY');
  if (cv.state === 'on') { const x = v.sx(cv.c.x), y = v.sy(cv.c.y); v.g.strokeStyle = 'rgba(104,240,160,0.45)'; v.g.setLineDash([2, 2]); v.g.beginPath(); v.g.arc(x, y, 18, 0, 7); v.g.stroke(); v.g.setLineDash([]); }
});
HOOKS.hud.push(() => {
  const cv = CONVOY.cur;
  if (!cv || cv.state !== 'on') return null;
  const w = body(cv.to), d = w ? Math.hypot(w.x - cv.c.x, w.y - cv.c.y) - w.r : 0;
  return `ESCORT ${cv.c.name.toUpperCase()} · HULL ${Math.max(0, Math.round((cv.c.hull / cv.c.maxHull) * 100))}% · ${Math.round(d / 10)} KM TO ${BODY[cv.to].name.toUpperCase()}`;
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { CONVOY, spawnConvoy: () => spawnConvoy(R.game) });
