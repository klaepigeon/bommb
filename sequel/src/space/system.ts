// The solar system: where every body is on a given day (real periods; moons around their
// planets), the gravity they exert on a ship, and hand-painted art for each (Gen 4 shading:
// banded light, a soft terminator, an atmosphere rim; gas giants get bands, Saturn its rings).

import { BODIES, BODY, AU, type BodyId } from '../engine/planets';
import { Px } from '../gfx/px';
import { rampOf, mix } from '../gfx/pal';
import { hash2 } from '../core/math';
import { SQ } from '../engine/state';
import { landValue, climate, NX, NY } from '../engine/earth';

export interface Body { id: BodyId; x: number; y: number; r: number; vx: number; vy: number }

// a fixed starting phase per body, so the planets aren't lined up at day 0 (Sol keeps the
// phases it always had; other systems hash theirs from the system and body names)
const strHash = (s: string) => { let h = 2166136261; for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619); return (h >>> 0) / 4294967296; };
const phase = (id: BodyId) => (SQ.system === 'sol' ? hash2(BODIES.findIndex((b) => b.id === id), 7, 3) : strHash(SQ.system + ':' + id)) * Math.PI * 2;

const orbitR = (id: BodyId) => { const b = BODY[id]; return b.parent === 'sun' ? b.au * AU : b.parent ? b.au * BODY[b.parent].radius : 0; };

// positions (and orbital velocities, units per game minute) at a game time in minutes
export function bodies(minutes: number): Body[] {
  const days = minutes / 1440, out: Body[] = [], at: Record<string, Body> = {};
  for (const b of BODIES) {
    if (!b.parent) { const s = { id: b.id, x: 0, y: 0, r: b.radius, vx: 0, vy: 0 }; out.push(s); at[b.id] = s; continue; }
    const p = at[b.parent], R = orbitR(b.id), w = (Math.PI * 2) / (b.days * 1440);
    const a = phase(b.id) + days * ((Math.PI * 2) / b.days);
    const o = { id: b.id, x: p.x + Math.cos(a) * R, y: p.y + Math.sin(a) * R, r: b.radius, vx: p.vx - Math.sin(a) * R * w, vy: p.vy + Math.cos(a) * R * w };
    out.push(o); at[b.id] = o;
  }
  return out;
}
export const bodyAt = (minutes: number, id: BodyId) => bodies(minutes).find((b) => b.id === id) as Body;
export const orbitRadius = orbitR;

// gravity: every body pulls (GM = surface gravity × radius²); returns the acceleration, the
// body whose pull dominates (for orbit readouts) and the altitude over the nearest surface
export function gravity(B: Body[], x: number, y: number): { ax: number; ay: number; dom: Body; alt: number; near: Body } {
  let ax = 0, ay = 0, dom = B[0], best = -1, alt = Infinity, near = B[0];
  for (const b of B) {
    const dx = b.x - x, dy = b.y - y, d2 = dx * dx + dy * dy, d = Math.sqrt(d2) || 1;
    const a = (BODY[b.id].gs * b.r * b.r) / Math.max(d2, b.r * b.r);
    ax += (dx / d) * a; ay += (dy / d) * a;
    if (a > best) { best = a; dom = b; }
    if (d - b.r < alt) { alt = d - b.r; near = b; }
  }
  return { ax, ay, dom, alt, near };
}
// the speed of a circular orbit at distance d from a body
export const orbitalSpeed = (b: Body, d: number) => Math.sqrt((BODY[b.id].gs * b.r * b.r) / Math.max(d, b.r));

// ---------------------------------------------------------------- art (capped resolution; big bodies draw chunkier)
function vnoise(x: number, y: number, s: number): number {
  const xi = Math.floor(x), yi = Math.floor(y), fx = x - xi, fy = y - yi;
  const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
  const a = hash2(xi, yi, s), b = hash2(xi + 1, yi, s), c = hash2(xi, yi + 1, s), d = hash2(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export const ART_R = 96; // painted radius of every body's art
const art = new Map<string, HTMLCanvasElement>();
export function planetArt(id: BodyId): HTMLCanvasElement {
  const key = SQ.system + ':' + id;
  let c = art.get(key);
  if (c) return c;
  const d = BODY[id], R = ART_R, pad = d.rings ? R : 4, p = new Px(R * 2 + pad * 2, R * 2 + pad * 2), C = R + pad;
  const base = rampOf(d.color), sea = d.sea ? rampOf(d.sea) : null;
  const seed = SQ.system === 'sol' ? BODIES.findIndex((b) => b.id === id) * 13 + 1 : Math.floor(strHash(key) * 9999);
  const ring = (front: boolean) => p.oval(C, C, R * 1.95, R * 0.55, (nx, ny, x, y) => {
    const k = Math.hypot(nx, ny);
    if (k < 0.62 || k > 0.98 || Math.floor(k * 30) % 5 === 0) return null;
    if (front && (ny < 0.05 || Math.hypot(x - C, y - C) <= R)) return null;
    return k < 0.8 ? (front ? '#e8d0a0' : '#d8c090') : front ? '#c8b080' : '#b8a070';
  });
  if (d.rings) ring(false);
  if (id === 'sun') {
    // the star: its own colour, white-hot at the core, granulated, a darker limb
    const c0 = d.color;
    p.oval(C, C, R, R, (nx, ny, x, y) => { const k = Math.hypot(nx, ny), f = hash2(Math.floor(x / 4), Math.floor(y / 4), 5); return k > 0.94 ? mix(c0, '#a03010', 0.35) : k > 0.8 ? (f > 0.5 ? mix(c0, '#ffffff', 0.15) : mix(c0, '#e08020', 0.15)) : f > 0.8 ? mix(c0, '#ffffff', 0.7) : k < 0.5 ? mix(c0, '#ffffff', 0.85) : mix(c0, '#ffffff', 0.4); });
  } else if (id === 'earth' && SQ.system === 'sol') {
    // the real continents, as seen from over the Pacific: smog-brown land, a sick green sea,
    // the sprawls lit up on the night side
    const LON0 = -115 * Math.PI / 180;
    const land: Record<string, string[]> = { ice: ['#8a96a0', '#aab4bc', '#c8d0d8', '#dde4ea', '#f0f4f6'], tundra: ['#3a4238', '#4e5848', '#66705a', '#7e8870', '#98a288'], desert: ['#5a4428', '#7a5e38', '#9a7a4c', '#b89660', '#d0b078'], jungle: ['#1a3020', '#28442c', '#3a5a38', '#4e7048', '#648656'], temperate: ['#2e3424', '#444a30', '#5c6040', '#747850', '#8e9064'] };
    const sea = ['#0e1a20', '#16282e', '#1e3a3c', '#2a4c48', '#3a605a'];
    p.oval(C, C, R, R, (nx, ny, x, y) => {
      const lat = -Math.asin(Math.max(-1, Math.min(1, ny))), cl = Math.cos(lat) || 1e-6;
      const lon = LON0 + Math.asin(Math.max(-1, Math.min(1, nx / cl)));
      const u = ((((lon * 180) / Math.PI + 180) / 360) * NX + NX) % NX, v = ((90 - (lat * 180) / Math.PI) / 180) * NY;
      const l = -nx * 0.55 - ny * 0.55 + (1 - Math.hypot(nx, ny)) * 0.4;
      const k = l > 0.55 ? 4 : l > 0.2 ? 3 : l > -0.25 ? 2 : l > -0.6 ? 1 : 0;
      const lv = landValue(u, v);
      let col = lv < 0.5 ? sea[k] : land[climate((lon * 180) / Math.PI, (lat * 180) / Math.PI)][k];
      // city lights and burning refineries on the dark side
      if (lv >= 0.5 && k <= 1 && hash2(x, y, 77) > 0.9) col = hash2(x, y, 78) > 0.5 ? '#ffb040' : '#ff5ad0';
      // smog streaks
      if (vnoise(x / 14, y / 5, 31) > 0.72) col = mix(col, '#b89a70', 0.35);
      return col;
    });
  } else p.oval(C, C, R, R, (nx, ny, x, y) => {
    const n = vnoise(x / 11, y / 11, seed) * 0.6 + vnoise(x / 27, y / 27, seed + 1) * 0.4;
    const l = -nx * 0.55 - ny * 0.55 + (1 - Math.hypot(nx, ny)) * 0.4;
    let r: string[] = base;
    const wet = !!sea && n < 0.52;
    if (wet) r = sea as string[];
    if (d.bands) { const band = Math.sin(ny * 14 + vnoise(x / 18, y / 6, seed) * 3); r = band > 0.4 ? rampOf(mix(d.color, '#ffffff', 0.25)) : band < -0.5 ? rampOf(mix(d.color, '#6a3a1a', 0.3)) : base; }
    let col = l > 0.55 ? r[4] : l > 0.2 ? r[3] : l > -0.25 ? r[2] : l > -0.6 ? r[1] : r[0];
    if (id === 'jupiter' && Math.hypot(nx - 0.3, (ny - 0.35) * 2.2) < 0.14) col = '#c8583a'; // the Great Red Spot
    if ((id === 'earth' && Math.abs(ny) > 0.88) || (id === 'mars' && Math.abs(ny) > 0.9)) col = mix(col, '#ffffff', 0.72);
    if (id === 'mars' && !wet && vnoise(x / 9, y / 9, seed + 5) > 0.6) col = mix(col, '#5aa050', 0.65); // terraformed green
    if ((id === 'luna' || id === 'mercury' || id === 'callisto') && vnoise(x / 5, y / 5, seed + 9) > 0.72) col = r[0]; // craters
    if (id === 'venus' && vnoise(x / 6, y / 6, seed + 3) > 0.7) col = mix(col, '#fff8e0', 0.5); // cloud cities catching the light
    if (id === 'io' && vnoise(x / 7, y / 7, seed + 2) > 0.7) col = '#c84820';
    if (id === 'europa' && vnoise(x / 4, y / 20, seed + 4) > 0.75) col = '#a86040'; // cracks in the ice
    return col;
  });
  if (d.rings) ring(true);
  // atmosphere rim on the worlds that have air
  if (d.air ?? ['earth', 'venus', 'mars', 'titan', 'jupiter', 'saturn', 'uranus', 'neptune'].includes(id))
    for (let a = 0; a < 360; a += 0.5) {
      const t = (a * Math.PI) / 180, x = Math.round(C + Math.cos(t) * (R + 1)), y = Math.round(C + Math.sin(t) * (R + 1));
      if (!p.has(x, y)) p.set(x, y, id === 'earth' ? (Math.cos(t) + Math.sin(t) < 0 ? '#d8b070' : '#5a3a2a') : Math.cos(t) + Math.sin(t) < 0 ? mix(d.color, '#e0f4ff', 0.6) : mix(d.color, '#1a2a5a', 0.6));
    }
  c = p.canvas();
  art.set(key, c);
  return c;
}
