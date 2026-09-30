// Mines. A crate of proximity mines from the pad chandler: drop one from the nav menu (USE
// in open space), or set them to drop themselves whenever something hostile is on your
// tail. A mine arms after a second and a half, drifts where you left it for two minutes,
// and goes off on the first hull that comes within forty metres (yours included: don't
// turn around).

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, hitCraft, burst } from './space';
import { SHIP_MENU } from './travel';
import { fmt } from './bounty';

interface Mine { x: number; y: number; vx: number; vy: number; arm: number; life: number }
export const MINES: Mine[] = [];
const PRICE = 300, PACK = 4, BLAST = 40;
let autoT = 0;
const count = () => SQ.flags.mines || 0;

export function dropMine(g: Game, quiet = false): boolean {
  if (count() <= 0) { if (!quiet) g.ui.toast('No mines aboard. The pad chandler sells them.', 'warn'); return false; }
  SQ.flags.mines = count() - 1; saveSequel();
  // out the back, drifting a little slower than you
  MINES.push({ x: SPACE.x - Math.cos(SPACE.a) * 22, y: SPACE.y - Math.sin(SPACE.a) * 22, vx: SPACE.vx * 0.6, vy: SPACE.vy * 0.6, arm: 1.5, life: 120 });
  g.audio.sfx('click');
  if (!quiet) g.ui.toast(`Mine away. ${count()} left.`);
  return true;
}
function blow(g: Game, m: Mine): void {
  m.life = 0;
  burst(m.x, m.y, 30, ['#ff5a3a', '#ffd060', '#ffffff'], m.vx, m.vy);
  g.audio.sfx('boom');
  // a blast goes through a shield: what the shield can't soak goes into the hull
  for (const c of SPACE.crafts) if (!c.dead && Math.hypot(c.x - m.x, c.y - m.y) < BLAST * 1.8) { const over = Math.max(0, 70 - c.shield); c.shield = Math.max(0, c.shield - 70); hitCraft(g, c, over); }
  if (Math.hypot(SPACE.x - m.x, SPACE.y - m.y) < BLAST * 1.8) {
    if (SPACE.shield > 0) SPACE.shield = Math.max(0, SPACE.shield - 50); else SQ.hull -= 35;
    g.ui.toast('Caught in your own mine!', 'bad');
  }
}

HOOKS.update.push((g, dt) => {
  if (!SPACE.active) return;
  for (const m of MINES) {
    m.x += m.vx * dt; m.y += m.vy * dt; m.vx *= 1 - dt * 0.8; m.vy *= 1 - dt * 0.8;
    m.life -= dt; m.arm -= dt;
    if (m.arm > 0 || m.life <= 0) continue;
    const hit = SPACE.crafts.some((c) => !c.dead && Math.hypot(c.x - m.x, c.y - m.y) < BLAST) || Math.hypot(SPACE.x - m.x, SPACE.y - m.y) < BLAST * 0.6;
    if (hit) blow(g, m);
  }
  for (let i = MINES.length - 1; i >= 0; i--) if (MINES[i].life <= 0) MINES.splice(i, 1);
  // automatic: something hostile behind you, within range
  autoT -= dt;
  if (SQ.flags.mineAuto && autoT <= 0 && count() > 0 && !SPACE.cruise) {
    const tail = SPACE.crafts.find((c) => !c.dead && c.hostile && !c.disabled && Math.hypot(c.x - SPACE.x, c.y - SPACE.y) < 320 &&
      Math.cos(Math.atan2(c.y - SPACE.y, c.x - SPACE.x) - SPACE.a) < -0.4);
    if (tail) { autoT = 2.5; dropMine(g, true); g.ui.toast(`Mine away behind you. ${count()} left.`); }
  }
});
HOOKS.draw.push((v) => {
  const blink = Math.floor(performance.now() / 250) % 2;
  for (const m of MINES) {
    const x = v.sx(m.x), y = v.sy(m.y);
    if (x < -10 || y < -10 || x > v.W + 10 || y > v.H + 10) continue;
    v.g.fillStyle = '#3a3a48'; v.g.fillRect(Math.round(x) - 2, Math.round(y) - 2, 4, 4);
    v.g.fillStyle = m.arm > 0 ? '#ffd060' : blink ? '#ff3a3a' : '#6a1a1a'; v.g.fillRect(Math.round(x) - 1, Math.round(y) - 1, 2, 2);
    if (m.arm <= 0 && blink) { v.g.strokeStyle = 'rgba(255,60,60,0.25)'; v.g.beginPath(); v.g.arc(x, y, BLAST * v.Z, 0, 7); v.g.stroke(); }
  }
});
HOOKS.navExtra.push((g) => {
  if (!count()) return null;
  return { label: `Drop a mine (${count()} left)`, small: SQ.flags.mineAuto ? 'Auto-drop is on: they fall when something\'s on your tail' : 'Arms in 1.5 s. Or turn on auto-drop from the ship menu', fn: () => { dropMine(g); } };
});
SHIP_MENU.push((g) => ({
  label: `Proximity mines (${count()} aboard)`, small: `${PACK} for ${fmt(PRICE)} · auto-drop ${SQ.flags.mineAuto ? 'ON' : 'off'}`, fn: () => g.ui.choice('Proximity mines', [
    { label: `Buy ${PACK} mines`, small: fmt(PRICE), fn: () => { if (g.player.cash < PRICE) return g.ui.toast('Not enough credits.', 'warn'); g.player.cash -= PRICE; SQ.flags.mines = count() + PACK; saveSequel(); g.audio.sfx('cash'); g.ui.toast(`${count()} mines racked in the tail. Drop them from the nav menu (USE in open space).`, 'good'); } },
    { label: `Auto-drop: ${SQ.flags.mineAuto ? 'ON' : 'off'}`, small: 'Drop one whenever something hostile is on your tail', fn: () => { SQ.flags.mineAuto = SQ.flags.mineAuto ? 0 : 1; saveSequel(); g.ui.toast(`Auto-drop ${SQ.flags.mineAuto ? 'on' : 'off'}.`); } },
    { label: 'Close', fn: () => {} },
  ]),
}));

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { MINES, dropMine: () => dropMine(R.game) });
