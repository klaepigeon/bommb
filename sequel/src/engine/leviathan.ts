// Leviathans. Out past the belt, in the cold between the giants, things the size of
// dreadnoughts swim on solar wind: void whales, the prospectors call them. Mostly they ignore
// you. Fly alongside one and USE to record its song (hold station near it until the tape's
// done); Radio Free Luna pays well for a new song, and the Choir... listens. Or put a harpoon
// in it: shoot it, and it turns and comes for you, and it is very large. Kill one and its
// carcass is full of void pearls. Nobody who's done it sleeps well.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, burst } from './space';
import { addCargo } from './cargo';
import { fmt } from './bounty';

interface Whale { x: number; y: number; vx: number; vy: number; a: number; hp: number; maxHp: number; r: number; angry: number; dead: boolean; harvested: boolean; ramT: number; song: number; recorded: boolean; seed: number; name: string }
export const WHALES: Whale[] = [];
const AU = 60000;
let nextT = 60;
const NAMES = ['Old Grandmother', 'the Grey Singer', 'Long Tom', 'the Choirmaster', 'Big Blue', 'the Drifter'];
const SONG = 12; // seconds alongside to record

export function spawnWhale(g: Game, dist = 1800): Whale {
  const a = Math.random() * 7;
  const w: Whale = { x: SPACE.x + Math.cos(a) * dist, y: SPACE.y + Math.sin(a) * dist, vx: SPACE.vx, vy: SPACE.vy, a: Math.random() * 7, hp: 900, maxHp: 900, r: 110, angry: 0, dead: false, harvested: false, ramT: 0, song: 0, recorded: false, seed: Math.random() * 100, name: NAMES[Math.floor(Math.random() * NAMES.length)] };
  WHALES.push(w);
  g.ui.toast(`Scanner: something huge and slow, ${Math.round(dist / 10)} km off, warm, moving on the solar wind. A void whale.`, 'good');
  return w;
}
const near = (r: number) => WHALES.find((w) => !w.dead && Math.hypot(w.x - SPACE.x, w.y - SPACE.y) < w.r + r) || null;
const carcass = () => WHALES.find((w) => w.dead && !w.harvested && Math.hypot(w.x - SPACE.x, w.y - SPACE.y) < w.r + 120) || null;

HOOKS.update.push((g, dt) => {
  if (!SPACE.active) return;
  // out in the deep: past three and a half AU from the star
  if (!WHALES.some((w) => !w.dead) && !SPACE.cruise && Math.hypot(SPACE.x, SPACE.y) > AU * 3.5) {
    nextT -= dt;
    if (nextT <= 0) { nextT = 150 + Math.random() * 150; if (Math.random() < 0.45) spawnWhale(g); }
  }
  for (const w of WHALES) {
    if (w.dead) { w.a += dt * 0.05; w.x += w.vx * dt; w.y += w.vy * dt; continue; }
    const d = Math.hypot(SPACE.x - w.x, SPACE.y - w.y);
    let want = w.a + Math.sin(performance.now() / 4000 + w.seed) * 0.3, sp = 40;
    if (w.angry > 0) { w.angry -= dt; want = Math.atan2(SPACE.y - w.y, SPACE.x - w.x); sp = 300; }
    let da = want - w.a; da = Math.atan2(Math.sin(da), Math.cos(da));
    w.a += Math.max(-0.8 * dt, Math.min(0.8 * dt, da));
    w.vx += (Math.cos(w.a) * sp + SPACE.vx * (w.angry > 0 ? 0 : 0.0) - w.vx) * Math.min(1, dt * 0.8);
    w.vy += (Math.sin(w.a) * sp - w.vy) * Math.min(1, dt * 0.8);
    w.x += w.vx * dt; w.y += w.vy * dt;
    // the ram
    w.ramT -= dt;
    if (w.angry > 0 && d < w.r * 0.9 && w.ramT <= 0) {
      w.ramT = 1.5;
      if (SPACE.shield > 0) SPACE.shield = Math.max(0, SPACE.shield - 40); else SQ.hull -= 30;
      const k = Math.atan2(SPACE.y - w.y, SPACE.x - w.x); SPACE.vx += Math.cos(k) * 380; SPACE.vy += Math.sin(k) * 380;
      burst(SPACE.x, SPACE.y, 16, ['#a8e8ff', '#ffffff'], SPACE.vx, SPACE.vy); g.audio.sfx('crash');
      g.ui.toast('The leviathan slams into you. Everything aboard that isn\'t bolted down isn\'t anymore.', 'bad');
    }
    // the song: hold station alongside, peacefully
    if (w.song > 0 && !w.recorded) {
      if (d < w.r + 400 && w.angry <= 0) {
        w.song += dt;
        if (w.song >= SONG) {
          w.recorded = true;
          SQ.flags.songs = (SQ.flags.songs || 0) + 1; saveSequel();
          g.player.rep.honor = (g.player.rep.honor || 0) + 2;
          g.ui.toast(`Got it: ${w.name}'s song, twelve seconds that go on forever. Radio Free Luna will pay for this.`, 'good');
          g.audio.sfx('accept');
        }
      } else { w.song = 0; g.ui.toast('Too far: the recording\'s lost. Stay alongside.', 'warn'); }
    }
  }
  for (let i = WHALES.length - 1; i >= 0; i--) if (Math.hypot(WHALES[i].x - SPACE.x, WHALES[i].y - SPACE.y) > 40000) WHALES.splice(i, 1);
});
// harpoons: your bolts hit it
HOOKS.shot.push((x, y, dmg) => {
  const w = WHALES.find((q) => !q.dead && Math.hypot(q.x - x, q.y - y) < q.r * 0.75);
  if (!w) return false;
  const g = R.game;
  w.hp -= dmg; w.song = 0;
  burst(x, y, 4, ['#6ad0ff', '#c8f0ff'], w.vx, w.vy);
  if (w.angry <= 0) { g.ui.toast(`${w.name} turns, slow as a continent, and comes for you.`, 'bad'); g.player.rep.honor = (g.player.rep.honor || 0) - 2; }
  w.angry = 20;
  if (w.hp <= 0) {
    w.dead = true; w.angry = 0;
    burst(w.x, w.y, 60, ['#6ad0ff', '#ffffff', '#a878c8'], w.vx, w.vy); g.audio.sfx('boom');
    g.player.rep.infamy = (g.player.rep.infamy || 0) + 3; g.player.rep.honor = (g.player.rep.honor || 0) - 5;
    SQ.achieved = SQ.achieved || {}; SQ.achieved.whales = (SQ.achieved.whales || 0) + 1; saveSequel();
    g.ui.toast(`${w.name} goes still. The song everyone out here could hear stops. Fly into the carcass and USE to harvest it.`, 'bad');
  }
  return true;
});
HOOKS.use.push((g) => {
  const c = carcass();
  if (c) return { label: 'Harvest', fn: () => {
    c.harvested = true;
    const n = 6 + Math.floor(Math.random() * 6), put = addCargo('pearls', n, false);
    saveSequel(); g.audio.sfx('cash');
    g.ui.toast(put ? `${put} void pearls, cut out of the dark. ${put < n ? 'No room for the rest.' : ''}` : 'No room in the holds for a single pearl.', put ? 'good' : 'warn');
  } };
  const w = near(300);
  if (w && !w.recorded && w.song <= 0 && w.angry <= 0) return { label: 'Record its song', fn: () => { w.song = 0.01; g.ui.toast(`Recording. Hold station alongside ${w.name} for ${SONG} seconds.`, 'good'); } };
  return null;
});
// Radio Free Luna buys the tapes
HOOKS.landed.push((g, id) => {
  const n = SQ.flags.songs || 0;
  if (id !== 'luna' || !n) return;
  const pay = n * 900;
  SQ.flags.songs = 0; SQ.flags.songsSold = (SQ.flags.songsSold || 0) + n; saveSequel();
  g.player.cash += pay;
  setTimeout(() => g.ui.story('Radio Free Luna', `The DJ plays the first eight seconds of your tape and doesn't talk for a full minute after.\n\n"Where did you... never mind. Never mind. ${fmt(pay)}. And you're on the air tonight, friend, whether you like it or not."`), 400);
});
HOOKS.draw.push((v) => {
  const g = v.g, t = performance.now() / 1000;
  for (const w of WHALES) {
    const x = v.sx(w.x), y = v.sy(w.y), L = Math.max(4, w.r * v.Z);
    if (x < -L * 2 || y < -L * 2 || x > v.W + L * 2 || y > v.H + L * 2) { if (!w.dead) v.mark(w.x, w.y, w.angry > 0 ? '#ff5a5a' : '#6ad0ff', 'LEVIATHAN'); continue; }
    g.save(); g.translate(x, y); g.rotate(w.a);
    const sw = Math.sin(t * 1.6 + w.seed) * 0.18;
    // body: a long tapering hull of hide, belly lighter
    g.fillStyle = w.dead ? '#2a2a3a' : '#1c2a5a';
    g.beginPath(); g.ellipse(0, 0, L, L * 0.34, 0, 0, 7); g.fill();
    g.fillStyle = w.dead ? '#3a3a48' : '#2c4a8a';
    g.beginPath(); g.ellipse(L * 0.1, L * 0.08, L * 0.8, L * 0.18, 0, 0, 7); g.fill();
    // flukes
    g.fillStyle = w.dead ? '#2a2a3a' : '#1c2a5a';
    g.beginPath(); g.moveTo(-L * 0.9, 0); g.lineTo(-L * 1.35, -L * (0.35 + sw)); g.lineTo(-L * 1.15, 0); g.lineTo(-L * 1.35, L * (0.35 - sw)); g.fill();
    // fins
    g.beginPath(); g.moveTo(L * 0.2, L * 0.25); g.lineTo(-L * 0.1, L * (0.6 + sw)); g.lineTo(-L * 0.05, L * 0.25); g.fill();
    g.beginPath(); g.moveTo(L * 0.2, -L * 0.25); g.lineTo(-L * 0.1, -L * (0.6 - sw)); g.lineTo(-L * 0.05, -L * 0.25); g.fill();
    // lights along the flank, pulsing (red when it's angry, out when it's dead)
    if (!w.dead) for (let k = 0; k < 7; k++) {
      const p = 0.5 + 0.5 * Math.sin(t * 2 + k * 0.9 + w.seed);
      g.fillStyle = w.angry > 0 ? `rgba(255,80,80,${0.4 + p * 0.6})` : `rgba(120,240,255,${0.3 + p * 0.7})`;
      g.fillRect(Math.round(L * (0.7 - k * 0.22)), Math.round(-L * 0.12), Math.max(1, Math.round(L * 0.04)), Math.max(1, Math.round(L * 0.04)));
    }
    // the eye
    g.fillStyle = w.dead ? '#1a1a22' : '#e8f8ff'; g.fillRect(Math.round(L * 0.78), Math.round(-L * 0.06), Math.max(1, Math.round(L * 0.05)), Math.max(1, Math.round(L * 0.05)));
    g.restore();
    if (!w.dead && w.hp < w.maxHp) { g.fillStyle = '#1c1828'; g.fillRect(x - 20, y + L * 0.5 + 4, 40, 3); g.fillStyle = '#6ad0ff'; g.fillRect(x - 20, y + L * 0.5 + 4, 40 * (w.hp / w.maxHp), 3); }
    if (w.song > 0 && !w.recorded) { g.fillStyle = '#1c1828'; g.fillRect(x - 20, y - L * 0.5 - 8, 40, 3); g.fillStyle = '#68f0a0'; g.fillRect(x - 20, y - L * 0.5 - 8, 40 * Math.min(1, w.song / SONG), 3); }
  }
});
HOOKS.hud.push(() => {
  const w = WHALES.find((q) => q.song > 0 && !q.recorded);
  return w ? `RECORDING ${w.name.toUpperCase()} · ${Math.ceil(SONG - w.song)}S · STAY ALONGSIDE` : null;
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { WHALES, spawnWhale: (d?: number) => spawnWhale(R.game, d) });
