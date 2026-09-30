// Security cameras and the cyberdeck: the immersive-sim layer of the future city.
//   Cameras: every bank, Corp Tower, Peacekeeper post, casino, club and blaster store has a
//   camera over the door, sweeping a cone across the street. Commit a crime inside a working
//   camera's cone and it's on tape: unmasked, they have your face (the bounty goes up and any
//   open case jumps forward); masked, they have a figure in a mask. A red REC light tells you
//   when one is looking at you. Shoot it out (vandalism), or hack it.
//   The cyberdeck (the Chop Shop, 250): jack into a camera within a few metres to loop the
//   feed for ten minutes, wipe tonight's footage (a chunk off the local bounty), or turn it to
//   face the wall for good. It also pops the locks on hover cars.

import { SQ, saveSequel } from './state';
import { SPACE } from './space';

const TS = R.TILE;
interface Cam { bid: number; x: number; y: number; face: number; sweep: number; dead: boolean; loopUntil: number; turned: boolean; seen: number }
export const CAMS = { list: [] as Cam[], world: null as any, tapes: 0 };
const TYPES = new Set(['bank', 'office', 'police', 'casino', 'club', 'gunshop', 'hotel']);
const RANGE = 78, HALF = 0.55;
const dayMin = (g: Game) => g.clock.t;
const deck = (pl: any) => !!(pl.inv.tools && pl.inv.tools.deck);

function build(g: Game): void {
  const w = g.world;
  CAMS.world = w; CAMS.list = [];
  for (const b of w.buildings) {
    if (!b || b.destroyed || !TYPES.has(b.type) || !b.out) continue;
    // over the door, looking out into the street (the door's side of the building)
    const dx = b.out.x - (b.x + b.w / 2), dy = b.out.y - (b.y + b.h / 2);
    const face = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 0 : Math.PI) : dy > 0 ? Math.PI / 2 : -Math.PI / 2;
    CAMS.list.push({ bid: b.id, x: b.out.x * TS + 8 + Math.cos(face + Math.PI / 2) * 10, y: b.out.y * TS + 8 - Math.sin(face) * 4, face, sweep: (b.id % 7) * 0.9, dead: false, loopUntil: 0, turned: false, seen: 0 });
  }
}
const aim = (c: Cam, t: number) => c.face + (c.turned ? Math.PI : Math.sin(t * 0.6 + c.sweep) * 0.7);
export function sees(c: Cam, g: Game, x: number, y: number): boolean {
  if (c.dead || c.turned || dayMin(g) < c.loopUntil) return false;
  const dx = x - c.x, dy = y - c.y, d = Math.hypot(dx, dy);
  if (d > RANGE || d < 4) return false;
  let da = Math.atan2(dy, dx) - aim(c, g.clock.real); da = Math.atan2(Math.sin(da), Math.cos(da));
  return Math.abs(da) < HALF;
}
const near = (pl: any, r: number) => CAMS.list.find((c) => !c.dead && Math.hypot(c.x - pl.x, c.y - pl.y) < r) || null;

// ---------------------------------------------------------------- crimes on tape
const L = (R as any).Law.prototype, crime = L.crime;
L.crime = function (this: any, type: string, x: number, y: number, opts: any) {
  const g = this.game, pl = g.player;
  const cam = CAMS.world === g.world && !SPACE.active ? CAMS.list.find((c) => sees(c, g, pl.x, pl.y)) : null;
  const r = crime.apply(this, arguments);
  const def = this.CRIMES[type];
  if (cam && def && !def.minor) {
    CAMS.tapes++;
    const jur = this.jurAt(x, y);
    if (!pl.masked) {
      this.bounty[jur] = (this.bounty[jur] || 0) + Math.round(def.bounty * 0.5);
      const cs = (R as any).cases && (R as any).cases.open ? (R as any).cases.open() : [];
      for (const c of cs) c.progress = Math.min(100, (c.progress || 0) + 15);
      g.ui.toast('That was on camera. They have your face.', 'bad');
    } else g.ui.toast('On camera, but all they\'ve got is a mask.', 'warn');
  }
  return r;
};
// ---------------------------------------------------------------- shooting them out
const C = R.combat as any, ray = C.ray;
C.ray = function (att: any, sx: number, sy: number, a: number, range: number, dmg: number) {
  const r = ray.apply(this, arguments);
  const g = R.game;
  if (att === g.player) for (const c of CAMS.list) {
    if (c.dead) continue;
    const cy = c.y - 18, rx = c.x - sx, ry = cy - sy, along = rx * Math.cos(a) + ry * Math.sin(a), across = Math.abs(-rx * Math.sin(a) + ry * Math.cos(a));
    if (along > 0 && along < range && across < 5) {
      c.dead = true; g.fx.sparks(c.x, cy, 6); g.audio.sfx('glass', c.x, c.y);
      (g.law as any).crime('vandalism', c.x, c.y, { minor: true });
      g.ui.toast('The camera pops in a shower of sparks.', 'good');
      break;
    }
  }
  return r;
};
// ---------------------------------------------------------------- the deck
function jack(g: Game, c: Cam): void {
  const pl = g.player;
  g.audio.sfx('click');
  g.ui.choice('Cyberdeck · security camera', [
    { label: 'Loop the feed', small: 'Ten minutes of an empty street, on repeat', fn: () => { c.loopUntil = dayMin(g) + 10; g.ui.toast('Feed looped. For the next ten minutes, nothing happens here.', 'good'); } },
    { label: 'Wipe tonight\'s footage', small: 'Knocks a chunk off the local bounty, once a day per camera', fn: () => {
      const day = Math.floor(dayMin(g) / 1440), key = 'wipe' + c.bid;
      if (SQ.flags[key] === day) return g.ui.toast('Already wiped today. There\'s nothing left on it.', 'warn');
      SQ.flags[key] = day; saveSequel();
      const law = g.law as any, jur = law.jurAt(pl.x, pl.y), b0 = law.bounty[jur] || 0;
      law.bounty[jur] = Math.round(b0 * 0.65);
      g.ui.toast(`Footage gone. Bounty here ${b0} → ${law.bounty[jur]}.`, 'good');
    } },
    { label: 'Turn it to face the wall', small: 'For good. Somebody will notice, eventually', fn: () => { c.turned = true; g.ui.toast('The camera pans slowly round to look at a lovely patch of brick.', 'good'); } },
    { label: 'Jack out', fn: () => {} },
  ]);
}
const PP = R.Player.prototype as any, ctx = PP.contextAction;
PP.contextAction = function (this: any) {
  if (!SPACE.active && !this.inCar && !this.room && deck(this)) {
    const c = near(this, TS * 3);
    if (c && !c.turned) return { label: 'Jack into the camera', fn: () => jack(R.game, c) };
    const g = R.game, v = g.traffic.list.find((q: any) => !q.removed && q.locked && !q.driver && Math.hypot(q.x - this.x, q.y - this.y) < TS * 1.6);
    if (v) return { label: 'Jack the lock', fn: () => { v.locked = false; g.audio.sfx('click'); g.fx.text(v.x, v.y - 14, 'UNLOCKED', '#68f0a0'); } };
  }
  return ctx.call(this);
};
const U = R.UI.prototype as any, io = U.interiorOptions;
U.interiorOptions = function (b: any) {
  const o = io.call(this, b), g = this.game, pl = g.player;
  if (b.type === 'pawn' && !deck(pl)) o.push({ label: 'Cyberdeck', price: '250', small: 'Jack into security cameras (loop, wipe, turn them) and hover-car locks', fn: () => {
    if (pl.cash < 250) return g.ui.toast('250 credits.', 'warn');
    pl.cash -= 250; pl.inv.tools.deck = 1; g.audio.sfx('equip');
    g.ui.toast('A cyberdeck, strapped to your forearm. Walk up to a camera or a locked car and USE.', 'good');
  } });
  return o;
};

// ---------------------------------------------------------------- the loop and the drawing
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = tick.call(this, dt);
  if (!this.world || SPACE.active) return r;
  if (CAMS.world !== this.world) build(this);
  const pl = this.player;
  for (const c of CAMS.list) c.seen = !pl.room && !pl.hidden && sees(c, this, pl.x, pl.y) ? Math.min(1, c.seen + dt * 4) : Math.max(0, c.seen - dt * 2);
  return r;
};
const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const g = R.game;
  if (!g || !g.world || SPACE.active || g.player.room || CAMS.world !== g.world) return;
  const t = g.clock.real, cx = g.cam.x, cy = g.cam.y, looped = (c: Cam) => dayMin(g) < c.loopUntil;
  for (const c of CAMS.list) {
    if (Math.abs(c.x - cx) > 320 || Math.abs(c.y - cy) > 220) continue;
    const a = aim(c, t), y = c.y - 18;
    // the cone on the ground
    if (!c.dead && !c.turned) {
      gx.fillStyle = c.seen > 0.3 ? `rgba(255,60,60,${0.10 + c.seen * 0.12})` : looped(c) ? 'rgba(120,200,255,0.06)' : 'rgba(255,250,210,0.07)';
      gx.beginPath(); gx.moveTo(c.x, c.y); gx.arc(c.x, c.y, RANGE, a - HALF, a + HALF); gx.closePath(); gx.fill();
    }
    // the camera: a box on a bracket, pointing where it's looking
    gx.fillStyle = '#1a1a22'; gx.fillRect(Math.round(c.x) - 1, y, 2, 5);
    gx.save(); gx.translate(Math.round(c.x), y); gx.rotate(c.turned ? a : a);
    gx.fillStyle = c.dead ? '#2a2a2a' : '#5a5a68'; gx.fillRect(-2, -2, 7, 4); gx.fillStyle = '#1a1a22'; gx.fillRect(5, -1, 2, 2);
    gx.restore();
    if (!c.dead) { gx.fillStyle = c.seen > 0.3 ? (Math.floor(t * 4) % 2 ? '#ff2020' : '#801010') : looped(c) ? '#5ad0ff' : '#50ff70'; gx.fillRect(Math.round(c.x) - 3, y - 2, 1, 1); }
    if (c.seen > 0.3 && Math.floor(t * 3) % 2) { gx.fillStyle = '#ff3030'; gx.fillRect(Math.round(c.x) - 11, y - 10, 3, 3); (R.art as any).ptext(gx, 'REC', c.x + 3, y - 12, { align: 'center', scale: 1, color: '#ff3030', shadow: '#10080a' }); }
    if (c.dead && Math.random() < 0.03) g.fx.sparks(c.x, y, 1);
  }
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { CAMS, camSees: (c: Cam) => sees(c, R.game, R.game.player.x, R.game.player.y) });
