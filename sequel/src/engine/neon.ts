// Neon. After dark on Earth, the fronts of the cantinas, clubs, arcades, holo-clubs, casinos
// and capsule hotels light up: a tube along the top of the front wall and a pair of uprights
// either side of the door, each place its own colours, humming, cycling, and now and then a
// tube that's on its way out stutters and dies for a moment before it catches again.

import { EARTH } from './earth';
import { SPACE } from './space';
import { inCoastCity } from './dystopia';
import { COAST_NEON } from './coastcity';

const TS = R.TILE;
const TYPES: Record<string, string[]> = {
  bar: ['#ff5ad0', '#5ad0ff'], club: ['#ff3a8a', '#b05aff', '#5ad0ff'], arcade: ['#68f0a0', '#ffe070'], strip: ['#ff5ad0', '#ff9a3a'],
  casino: ['#ffe070', '#ff3a3a'], hotel: ['#5ad0ff', '#e8e8f0'], liquor: ['#ff9a3a'], diner: ['#ff3a3a', '#e8e8f0'], motel: ['#ff3a8a'],
};
const phase = (id: number) => ((id * 2654435761) >>> 0) / 4294967296;
export const NEON = { on: false, lit: 0 };

const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const g = R.game;
  NEON.on = false; NEON.lit = 0;
  if (!g || !g.world || SPACE.active || g.player.room || !EARTH.active) return;
  const h = g.clock.hour();
  if (h > 5.5 && h < 19) return;
  NEON.on = true;
  const t = performance.now() / 1000, cx = g.cam.x, cy = g.cam.y;
  for (const b of g.world.buildings) {
    if (!b || b.destroyed) continue;
    const cols = TYPES[b.type] && (inCoastCity() ? COAST_NEON : TYPES[b.type]);
    if (!cols) continue;
    const x0 = b.x * TS, x1 = (b.x + b.w) * TS, yF = (b.y + b.h) * TS;
    if (x1 < cx - 320 || x0 > cx + 320 || yF < cy - 240 || yF - b.h * TS > cy + 240) continue;
    const ph = phase(b.id);
    // a dying tube: every so often it stutters for a moment
    const s = (t * 0.7 + ph * 13) % 9;
    const dead = s < 0.5 && Math.floor(t * 18) % 3 !== 0;
    const col = cols[Math.floor(t * 0.5 + ph * 7) % cols.length];
    const pulse = 0.75 + Math.sin(t * 2 + ph * 6) * 0.15;
    const y = yF - 26, left = x0 + 4, right = x1 - 4;
    if (dead) { gx.fillStyle = 'rgba(40,30,50,0.8)'; gx.fillRect(left, y, right - left, 1); continue; }
    NEON.lit++;
    gx.globalAlpha = 0.22 * pulse; gx.fillStyle = col; gx.fillRect(left - 1, y - 2, right - left + 2, 5);
    gx.globalAlpha = pulse; gx.fillRect(left, y, right - left, 1);
    gx.globalAlpha = 1; gx.fillStyle = '#ffffff'; gx.fillRect(left + 2, y, Math.max(0, right - left - 4), 1);
    gx.globalAlpha = pulse; gx.fillStyle = col; gx.fillRect(left, y, 2, 1); gx.fillRect(right - 2, y, 2, 1);
    // uprights beside the door, chasing lights running up them
    if (b.out) {
      const dx = b.out.x * TS + 8;
      if (dx > x0 && dx < x1) for (const side of [-12, 11]) {
        gx.globalAlpha = 0.2 * pulse; gx.fillStyle = col; gx.fillRect(dx + side - 1, yF - 22, 3, 18);
        gx.globalAlpha = pulse; gx.fillRect(dx + side, yF - 22, 1, 18);
        const k = Math.floor(t * 10 + ph * 10) % 6;
        gx.globalAlpha = 1; gx.fillStyle = '#ffffff'; gx.fillRect(dx + side, yF - 6 - k * 3, 1, 2);
      }
    }
    gx.globalAlpha = 1;
  }
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { NEON });
