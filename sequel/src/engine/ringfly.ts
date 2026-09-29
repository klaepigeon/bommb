// Flying on a lantern ring. The construct menu (USE with nothing around) gets a TAKE OFF
// button: you go up into orbit with no ship at all, in your corps uniform and domino mask,
// wrapped in your ring's light, as fast as the skiff every pilot starts with. Your ship
// stays where you left it; land anywhere and it's still there, waiting (call it down from
// any pad). Taking off costs WILL.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, launch } from './space';
import { starterShip } from '../ship/ship';

const COST = 40;
const A = R.art as any;
const CP = () => (R as any).corps;
const ringCol = (): string => (R.game && R.game.player && R.game.player.ringColor) || 'yellow';
const glowOf = (col: string): string => (CP() && CP().COL[col] ? CP().COL[col].c : '#f0c020');

export const ringFlying = () => !!SQ.ringFly;

function canTakeOff(g: Game): string | null {
  const pl = g.player;
  if (SPACE.active || SQ.mode === 'space') return 'You are already in space.';
  if (pl.room) return 'Get outside first.';
  if (pl.inCar) return 'Get out of the car first.';
  if ((pl.will || 0) < COST) return `Not enough WILL (${Math.round(pl.will || 0)}/${COST}).`;
  return null;
}

export function takeOff(g: Game): void {
  const why = canTakeOff(g);
  if (why) { g.ui.toast(why, 'warn'); return; }
  const pl = g.player, col = ringCol(), C = CP() && CP().COL[col];
  pl.will -= COST;
  if (g.ui.closeSheet) g.ui.closeSheet();
  SQ.ringFly = { ship: SQ.ship, hull: SQ.hull, style: Object.assign({}, pl.style), shipAt: [SQ.shipAt[0], SQ.shipAt[1]], shipLoc: SQ.shipLoc || { sys: SQ.home, planet: SQ.planet } };
  SQ.shipLoc = SQ.ringFly.shipLoc;
  // the ring gives you the default ship's speed, and none of its guns but your own light
  SQ.ship = starterShip(C ? C.corps : 'Ring');
  SQ.hull = -1;
  // the uniform: the corps' colours (the mask is painted on the flier)
  if (C) { Object.assign(pl.style, { jacket: 'none', shirt: C.shirt, top: 'turtle', pants: C.pants || 'corpsblack', hat: 'none' }); pl.buildLook(); }
  saveSequel();
  launch(g);
  g.audio.sfx('promote');
  g.ui.toast(`${C ? C.name : 'The ring'} lifts you out of the sky and into the dark. No ship. Land anywhere; your ship stays where you left it.`, 'good');
}

// back on the ground: out of uniform, and the ship is wherever it was parked
HOOKS.landed.push((g) => {
  const rf = SQ.ringFly;
  if (!rf) { SQ.shipLoc = { sys: SQ.home, planet: SQ.planet }; return; }
  SQ.ship = rf.ship; SQ.hull = rf.hull; SQ.shipAt = rf.shipAt; SQ.shipLoc = rf.shipLoc;
  const pl = g.player;
  pl.style = Object.assign({}, rf.style); pl.buildLook();
  SQ.ringFly = null;
  saveSequel();
});

// ---------------------------------------------------------------- the take-off button
const U = (R as any).UI.prototype, baseSheet = U.openSheet;
U.openSheet = function (kind: string, html: string, center?: boolean) {
  if (kind !== 'ringlib' || !R.game || SPACE.active) return baseSheet.call(this, kind, html, center);
  const why = canTakeOff(R.game);
  const btn = `<button class="opt ${why ? '' : 'go'}" data-ringfly="1" style="margin:0 0 8px">Take off into space<small>${why || `No ship needed. ${COST} WILL.`}</small></button>`;
  const s = baseSheet.call(this, kind, html.replace('<div class="body">', '<div class="body">' + btn), center);
  const b = s && s.querySelector('[data-ringfly]');
  if (b) b.addEventListener('click', () => takeOff(R.game));
  return s;
};
// rings with their own power instead of the library: USE offers the power or the sky
const Ring = (R as any).ring, baseLib = Ring.openLibrary;
Ring.openLibrary = function (summon?: boolean) {
  const c = ringCol();
  if (!summon || c === 'yellow' || c === 'green' || SPACE.active) return baseLib.apply(this, arguments);
  const g = R.game;
  g.ui.choice(CP().COL[c].name, [
    { label: 'Use its power', small: CP().COL[c].how, fn: () => baseLib.call(this, true) },
    { label: 'Take off into space', small: canTakeOff(g) || `No ship needed. ${COST} WILL.`, fn: () => takeOff(g) },
  ]);
};

// ---------------------------------------------------------------- the flier
// Seen from above, flying head first: one fist out in front with the ring blazing, the
// other arm at the side, legs trailing and kicking, a domino mask, the corps uniform.
const cache = new Map<string, HTMLCanvasElement[]>();
function flierFrames(look: any, col: string): HTMLCanvasElement[] {
  const key = (look.seedStr || 'p') + col + JSON.stringify(look.oldOverride && look.oldOverride.shirt);
  let fr = cache.get(key);
  if (fr) return fr;
  fr = [];
  const glow = glowOf(col);
  for (let f = 0; f < 4; f++) {
    const cv = document.createElement('canvas'); cv.width = 32; cv.height = 48;
    const g = cv.getContext('2d') as CanvasRenderingContext2D;
    g.imageSmoothingEnabled = false;
    const X = 16, Y = 42;
    // body facing the camera, legs mid-stride (the kick)
    A.drawPerson(g, X, Y, 1, [0, 3, 6, 3][f], look, { ang: Math.PI / 2 });
    // the domino mask across the eyes
    g.fillStyle = '#101018'; g.fillRect(X - 5, Y - 15, 11, 3); g.fillRect(X - 6, Y - 14, 1, 1); g.fillRect(X + 6, Y - 14, 1, 1);
    g.fillStyle = '#ffffff'; g.fillRect(X - 3, Y - 14, 2, 1); g.fillRect(X + 2, Y - 14, 2, 1);
    // the ring arm, thrust out from the shoulder past the head, the fist blazing
    const sleeve = (look.oldOverride && look.oldOverride.shirt && look.oldOverride.shirt[2]) || '#303048';
    g.fillStyle = '#1b1410'; g.fillRect(X + 5, Y - 33, 5, 21);
    g.fillStyle = sleeve; g.fillRect(X + 6, Y - 30, 3, 18);
    g.fillStyle = (look.oldOverride && look.oldOverride.shirt && look.oldOverride.shirt[3]) || '#48486a'; g.fillRect(X + 6, Y - 30, 1, 18);
    g.fillStyle = (look.oldOverride && look.oldOverride.skin && look.oldOverride.skin[2]) || look.skin || '#e0ac7e'; g.fillRect(X + 5, Y - 35, 5, 5);
    g.fillStyle = glow; g.fillRect(X + 5, Y - 33, 5, 1);
    g.fillStyle = '#ffffff'; g.fillRect(X + 8, Y - 33, 1, 1);
    fr.push(cv);
  }
  cache.set(key, fr);
  return fr;
}

HOOKS.self.push((g, x, y, a, k) => {
  if (!SQ.ringFly || !R.game) return false;
  const pl = R.game.player, col = ringCol(), glow = glowOf(col), t = performance.now() / 1000;
  const moving = SPACE.cruise || Math.hypot(R.game.input.stick.x, R.game.input.stick.y) > 0.2;
  const frames = flierFrames(pl.look, col), spr = frames[moving ? Math.floor(t * 8) % 4 : 0];
  const bob = Math.sin(t * 3) * 1.5, s = Math.max(0.7, k);
  // the aura
  const aura = g.createRadialGradient(x, y, 2, x, y, 22 * s);
  aura.addColorStop(0, 'rgba(255,255,255,0.18)'); aura.addColorStop(0.5, glow + '44'); aura.addColorStop(1, glow + '00');
  g.fillStyle = aura; g.fillRect(x - 24 * s, y - 24 * s, 48 * s, 48 * s);
  g.save();
  g.translate(Math.round(x), Math.round(y + bob));
  g.rotate(a + Math.PI / 2);
  g.drawImage(spr, Math.round(-spr.width / 2 * s), Math.round(-spr.height * 0.55 * s), Math.round(spr.width * s), Math.round(spr.height * s));
  // the fist's glow, out ahead
  const fx = 8 * s, fy = (9 - 48 * 0.55) * s; // the fist, in the sprite's frame
  const fg = g.createRadialGradient(fx, fy, 0, fx, fy, 6 * s);
  fg.addColorStop(0, '#ffffff'); fg.addColorStop(0.4, glow); fg.addColorStop(1, glow + '00');
  g.fillStyle = fg; g.fillRect(fx - 7 * s, fy - 7 * s, 14 * s, 14 * s);
  g.restore();
  return true;
});

// a streak of the ring's light behind you
let trailT = 0;
HOOKS.update.push((g, dt) => {
  if (!SQ.ringFly) return;
  const moving = SPACE.cruise || Math.hypot(g.input.stick.x, g.input.stick.y) > 0.2;
  trailT -= dt;
  if (moving && trailT <= 0) {
    trailT = 0.03;
    const glow = glowOf(ringCol());
    SPACE.sparks.push({ x: SPACE.x - Math.cos(SPACE.a) * 12 + (Math.random() - 0.5) * 4, y: SPACE.y - Math.sin(SPACE.a) * 12 + (Math.random() - 0.5) * 4, vx: SPACE.vx - Math.cos(SPACE.a) * 40, vy: SPACE.vy - Math.sin(SPACE.a) * 40, life: 0.5, col: Math.random() < 0.3 ? '#ffffff' : glow });
  }
});
HOOKS.hud.push(() => (SQ.ringFly ? `RING FLIGHT · ${(CP() && CP().COL[ringCol()] ? CP().COL[ringCol()].name : 'RING').toUpperCase()}` : null));
