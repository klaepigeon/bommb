// Things that happen out there. Every couple of minutes in open space (not in cruise):
//   A distress call: a crippled freighter nearby. Fly to her and it's either a rescue (the
//   crew pay you and your honour goes up) or a trap (hunters light up their engines).
//   A derelict: an old hauler drifting dead, holds full of something valuable. Board her.
//   A solar storm: for half a minute your shields bleed away. Ride it out, or get somewhere.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, spawnCraft, type Craft } from './space';
import { npcShip } from '../ship/ship';
import { fmt } from './bounty';

let nextT = 90, storm = 0;
const tracked: { c: Craft; kind: 'sos' | 'trap' | 'derelict'; done?: boolean }[] = [];
const NAMES = ['Lucky Seven', 'Gloria', 'Salt of Titan', 'Wanderer', 'Old Faithful', 'Hope Street', 'Marigold', 'Kestrel'];
const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];

export function trigger(g: Game, kind: 'sos' | 'derelict' | 'storm'): void {
  if (kind === 'storm') { storm = 30; g.ui.toast('SOLAR STORM. Shields are bleeding. Ride it out.', 'bad'); g.audio.sfx('alarm'); return; }
  const c = spawnCraft('freighter', false, 2600);
  c.disabled = true; c.vx = SPACE.vx * 0.5; c.vy = SPACE.vy * 0.5;
  if (kind === 'derelict') {
    c.ship = npcShip('trader', Math.random, 'Derelict', 'hauler'); c.name = 'Derelict ' + pick(['Hauler', 'Barge', 'Tender']);
    c.cargo = [{ good: pick(['plat', 'xeno', 'pearls'] as const), n: 4 + Math.floor(Math.random() * 5) }, { good: 'meds', n: 5 }];
    tracked.push({ c, kind });
    g.ui.toast(`Scanner: a derelict hauler, dark and cold, ${Math.round(2600 / 10)} km off. Holds read full. Board her.`, 'good');
  } else {
    c.name = 'SOS: ' + pick(NAMES);
    tracked.push({ c, kind: Math.random() < 0.4 ? 'trap' : 'sos' });
    g.ui.toast(`Distress call: "${c.name.slice(5)}, engines gone, life support failing. Anyone out there?"`, 'warn');
  }
  g.audio.sfx('click');
}

HOOKS.update.push((g, dt) => {
  // the storm
  if (storm > 0) { storm -= dt; SPACE.shield = Math.max(0, SPACE.shield - 15 * dt); if (Math.random() < dt * 4) SPACE.sparks.push({ x: SPACE.x + (Math.random() - 0.5) * 60, y: SPACE.y + (Math.random() - 0.5) * 60, vx: 0, vy: 0, life: 0.3, col: '#ffe070' }); }
  // what's become of the calls
  for (const t of tracked) {
    if (t.done || t.c.dead) { t.done = true; continue; }
    const d = Math.hypot(t.c.x - SPACE.x, t.c.y - SPACE.y);
    if (t.kind === 'trap' && d < 450) {
      t.done = true;
      for (let k = 0; k < 2; k++) { const h = spawnCraft('hunter', true, 500); h.name = 'Wrecker'; }
      t.c.disabled = false; t.c.hostile = true; t.c.name = 'Wrecker Bait';
      g.ui.toast('It\'s a trap! Engines light up all around you.', 'bad'); g.audio.sfx('alarm');
    } else if (t.kind === 'sos' && d < 140) {
      t.done = true;
      const pay = 400 + Math.floor(Math.random() * 600);
      g.player.cash += pay; g.player.rep.honor = (g.player.rep.honor || 0) + 3; saveSequel();
      g.ui.toast(`You patch their life support and give them a tow. The captain presses ${fmt(pay)} on you. "We owe you."`, 'good');
      SQ.achieved = SQ.achieved || {}; SQ.achieved.rescues = (SQ.achieved.rescues || 0) + 1;
    }
  }
  // the next one
  if (!SPACE.active || SPACE.cruise || SPACE.auto) return;
  nextT -= dt;
  if (nextT <= 0) { nextT = 110 + Math.random() * 90; trigger(g, Math.random() < 0.45 ? 'sos' : Math.random() < 0.55 ? 'derelict' : 'storm'); }
});
HOOKS.hud.push(() => (storm > 0 ? `SOLAR STORM ${Math.ceil(storm)}S · SHIELDS DRAINING` : null));
HOOKS.draw.push((v) => {
  if (storm > 0) { v.g.fillStyle = `rgba(255,200,80,${0.08 + Math.sin(performance.now() / 120) * 0.04})`; v.g.fillRect(0, 0, v.W, v.H); }
  for (const t of tracked) if (!t.done && !t.c.dead) v.mark(t.c.x, t.c.y, t.kind === 'derelict' ? '#a8e8ff' : '#ffe070', t.kind === 'derelict' ? 'DERELICT' : 'SOS');
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { spaceEvent: (k: 'sos' | 'derelict' | 'storm') => trigger(R.game, k), eventsTracked: () => tracked });
