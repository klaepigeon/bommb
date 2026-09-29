// The way back to your ship. Once the Fear Man's clamp is off, a marker hangs over the ship on its
// pad; off screen, an arrow on the edge of the view points to it with the distance. On
// Earth, if you've walked sectors away, the arrow points toward the sector the ship is
// sitting in (or tells you to call it from any pad). Releasing the clamp also sets a
// waypoint, so the route line and the minimap lead you there too.

import { SQ } from './state';
import { SPACE } from './space';
import { shipHere, nearShip } from './travel';

const TS = R.TILE;
const on = () => !SQ.flags.clamp && !SPACE.active && R.game && R.game.world && R.game.player && !R.game.player.room && !!R.game.world.pad;

function view(g: CanvasRenderingContext2D) {
  const m = g.getTransform();
  return { left: -m.e / m.a, top: -m.f / m.d, vw: g.canvas.width / m.a, vh: g.canvas.height / m.d };
}

// an arrow clamped to the edge of the view, pointing at (tx, ty)
function edgeArrow(g: CanvasRenderingContext2D, tx: number, ty: number, label: string, t: number): void {
  const v = view(g), cx = v.left + v.vw / 2, cy = v.top + v.vh / 2;
  const a = Math.atan2(ty - cy, tx - cx), pad = 18;
  const k = Math.min((v.vw / 2 - pad) / Math.abs(Math.cos(a) || 1e-3), (v.vh / 2 - pad - 14) / Math.abs(Math.sin(a) || 1e-3));
  const pulse = 1 + Math.sin(t * 5) * 0.12;
  const x = cx + Math.cos(a) * k, y = cy + Math.sin(a) * k;
  g.fillStyle = '#3af0ff'; g.strokeStyle = '#07051a'; g.lineWidth = 1;
  g.beginPath();
  g.moveTo(x + Math.cos(a) * 7 * pulse, y + Math.sin(a) * 7 * pulse);
  g.lineTo(x + Math.cos(a + 2.5) * 6 * pulse, y + Math.sin(a + 2.5) * 6 * pulse);
  g.lineTo(x + Math.cos(a - 2.5) * 6 * pulse, y + Math.sin(a - 2.5) * 6 * pulse);
  g.closePath(); g.fill(); g.stroke();
  const lx = Math.max(v.left + 40, Math.min(v.left + v.vw - 40, x - Math.cos(a) * 16)), ly = Math.max(v.top + 8, Math.min(v.top + v.vh - 14, y - Math.sin(a) * 12 - 3));
  R.art.ptext(g, label, Math.round(lx), Math.round(ly), { align: 'center', scale: 1, color: '#3af0ff', shadow: '#07051a' });
}

export function drawShipMarker(g: CanvasRenderingContext2D): void {
  if (!on()) return;
  const gm = R.game, pl = gm.player, w = gm.world, t = performance.now() / 1000;
  if (nearShip(pl)) return;
  if (shipHere()) {
    const x = w.pad.sx, y = w.pad.sy, v = view(g);
    const inView = x > v.left + 10 && x < v.left + v.vw - 10 && y > v.top + 10 && y < v.top + v.vh - 10;
    if (inView) {
      const bob = Math.sin(t * 4) * 2, top = y - 34 + bob;
      g.fillStyle = '#3af0ff'; g.strokeStyle = '#07051a'; g.lineWidth = 1;
      g.beginPath(); g.moveTo(x, top + 8); g.lineTo(x - 5, top); g.lineTo(x + 5, top); g.closePath(); g.fill(); g.stroke();
      R.art.ptext(g, SQ.ship.name.toUpperCase(), Math.round(x), Math.round(top - 10), { align: 'center', scale: 1, color: '#3af0ff', shadow: '#07051a' });
    } else {
      const d = Math.round(Math.hypot(x - pl.x, y - pl.y) / TS);
      edgeArrow(g, x, y, `SHIP ${d}M`, t);
    }
    return;
  }
  // on another world entirely: the pad's context button calls it down
  if (SQ.shipLoc && (SQ.shipLoc.sys !== SQ.home || SQ.shipLoc.planet !== SQ.planet)) return;
  if (SQ.planet !== 'earth') return;
  // Earth: the ship is sectors away. Point that way (the short way round the globe).
  let dx = SQ.shipAt[0] - SQ.sector[0];
  if (dx > 36) dx -= 72; if (dx < -36) dx += 72;
  const dy = SQ.shipAt[1] - SQ.sector[1], n = Math.max(Math.abs(dx), Math.abs(dy));
  const far = 1e5;
  edgeArrow(g, pl.x + Math.sign(dx) * far * (Math.abs(dx) / n), pl.y + Math.sign(dy) * far * (Math.abs(dy) / n), `SHIP ${n} SECTOR${n > 1 ? 'S' : ''} · OR CALL IT FROM A PAD`, t);
}

const baseDraw = R.ring.draw;
R.ring.draw = function (this: unknown, g: CanvasRenderingContext2D) {
  baseDraw.call(this, g);
  try { drawShipMarker(g); } catch (e) { /* a marker must never break the frame */ }
};

// the route and the minimap: point the waypoint at the pad (only if nothing else is set)
export function waypointToShip(gm: Game): void {
  const w = gm.world;
  if (!w || !w.pad || gm.waypoint || !shipHere()) return;
  gm.waypoint = { x: w.pad.sx, y: w.pad.sy };
}
// and clear it once you're there
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  const wp = this.waypoint, w = this.world;
  if (wp && w && w.pad && wp.x === w.pad.sx && wp.y === w.pad.sy && this.player && nearShip(this.player)) this.waypoint = null;
  return r;
};
