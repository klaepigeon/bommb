// What each room's walls, floor and ceiling look like after the family left and the
// water came in. Every face is painted to order: stains run from the leaks, mould gathers
// in the cold corners by the outer walls, paper lifts where it's damp, pale squares show
// where pictures hung.
import {
  Surface, wallpaperTile, underPlaster, underBrick, underConcrete, rgba, blobPath, noiseCanvas,
} from './textures.js';
import { H } from './plan.js';

const PPM = 128;
let seedN = 100;

function wallpaper(s, kind, a, b, seed, repeatM = 0.53) {
  s.fill(a).pattern(wallpaperTile(kind, a, b, seed), 1, (repeatM * s.ppm) / 128);
  // strip seams, some lifting
  const g = s.g;
  for (let x = s.r() * 20; x < s.W; x += 0.53 * s.ppm) {
    g.fillStyle = 'rgba(40,30,20,0.18)'; g.fillRect(x, 0, 1.5, s.H);
    if (s.r() < 0.35) { // lifted seam: a light lip and a shadow, over part of the height
      const y0 = s.r() * s.H * 0.6, y1 = y0 + s.H * (0.1 + s.r() * 0.3);
      g.fillStyle = 'rgba(255,245,215,0.18)'; g.fillRect(x - 4, y0, 4, y1 - y0);
      g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(x + 1, y0, 3, y1 - y0);
      s.hg.fillStyle = '#c8c8c8'; s.hg.fillRect(x - 4, y0, 5, y1 - y0);
    }
  }
  // age: yellowing, uneven fading
  s.noise(0.35, 1.8, 'multiply', 10, seed + 1).noise(0.2, 0.7, 'overlay', 5, seed + 2).grain(0.05);
  s.noise(0.25, 0.9, 'soft-light', 6, seed + 3, 'h');
}
function plasterWall(s, col, seed) {
  s.fill(col).noise(0.28, 1.2, 'multiply', 8, seed).noise(0.18, 0.5, 'overlay', 4, seed + 1).grain(0.07);
  s.noise(0.5, 0.6, 'source-over', 4, seed + 2, 'h');
}
function oilPaintDado(s, col, top = 1.5, line = '#3b4a3a') { // Soviet kitchen/stair: gloss paint to shoulder height
  const g = s.g, y = s.Y(top);
  g.fillStyle = col; g.fillRect(0, y, s.W, s.H - y);
  g.fillStyle = line; g.fillRect(0, y - 3, s.W, 4);
  // chipped gloss
  for (let i = 0; i < 40; i++) {
    const k = s.ppm / 128, p = blobPath(s.r() * s.W, y + s.r() * (s.H - y), (3 + s.r() * 12) * k, (2 + s.r() * 7) * k, s.r, 0.6, 14);
    g.fillStyle = 'rgba(190,180,160,0.7)'; g.fill(p); s.hg.fillStyle = '#606060'; s.hg.fill(p);
  }
  if (s.rc) { s.rg.fillStyle = '#606060'; s.rg.fillRect(0, y, s.W, s.H - y); }
}
function tilesWall(s, top, tile = 0.15, col = '#d9dcd6', grout = '#8c8a80', seed = 1) {
  const g = s.g, r = s.r, t = tile * s.ppm, y0 = s.Y(top);
  g.fillStyle = grout; g.fillRect(0, y0, s.W, s.H - y0);
  if (!s.rc) s.rough(0.85);
  for (let y = s.H - t; y > y0 - t; y -= t) for (let x = 0; x < s.W; x += t) {
    const yy = Math.max(y, y0), hh = y + t - yy; if (hh <= 2) continue;
    const missing = r() < 0.035;
    if (missing) { // tile gone: grey adhesive with comb lines
      g.fillStyle = '#7b776c'; g.fillRect(x + 1, yy + 1, t - 2, hh - 2);
      g.strokeStyle = 'rgba(0,0,0,0.25)'; for (let k = 3; k < t; k += 4) { g.beginPath(); g.moveTo(x + 2, yy + k); g.lineTo(x + t - 2, yy + k); g.stroke(); }
      s.hg.fillStyle = '#404040'; s.hg.fillRect(x + 1, yy + 1, t - 2, hh - 2);
      continue;
    }
    const k = 0.9 + r() * 0.12;
    const c = col.match(/\w\w/g).map((h) => parseInt(h, 16) * k);
    g.fillStyle = rgba(c[0], c[1], c[2]); g.fillRect(x + 0.8, yy + 0.8, t - 1.6, hh - 1.6);
    s.rg.fillStyle = '#383838'; s.rg.fillRect(x + 0.8, yy + 0.8, t - 1.6, hh - 1.6);
    s.hg.fillStyle = '#9a9a9a'; s.hg.fillRect(x + 0.8, yy + 0.8, t - 1.6, hh - 1.6);
    if (r() < 0.08) { // cracked tile
      g.strokeStyle = 'rgba(30,30,25,0.7)'; g.lineWidth = 1; g.beginPath();
      g.moveTo(x + r() * t, yy); g.lineTo(x + r() * t, yy + hh * 0.5); g.lineTo(x + r() * t, yy + hh); g.stroke();
    }
  }
  // grime in the grout, worst low down
  s.rising(0.6, [60, 55, 35], 0.35);
}

function floorPlanks(s, col, w = 0.14, rot = false, seed = 1) {
  const g = s.g, r = s.r, pw = w * s.ppm;
  s.fill(col);
  const n = rot ? s.H : s.W;
  for (let a = 0; a < n; a += pw) {
    const k = 0.82 + r() * 0.3;
    g.fillStyle = `rgba(${k > 1 ? '255,230,200' : '0,0,0'},${Math.abs(1 - k) * 0.5})`;
    if (rot) g.fillRect(0, a, s.W, pw); else g.fillRect(a, 0, pw, s.H);
    // board ends
    for (let b = r() * 300; b < (rot ? s.W : s.H); b += 140 + r() * 260) {
      g.fillStyle = 'rgba(20,12,6,0.55)'; if (rot) g.fillRect(b, a, 2, pw); else g.fillRect(a, b, pw, 2);
    }
    g.fillStyle = 'rgba(15,8,3,0.6)'; if (rot) g.fillRect(0, a, s.W, 2); else g.fillRect(a, 0, 2, s.H);
    s.hg.fillStyle = '#303030'; if (rot) s.hg.fillRect(0, a, s.W, 2); else s.hg.fillRect(a, 0, 2, s.H);
  }
  // grain
  for (let i = 0; i < s.W * s.H / 900; i++) {
    const x = r() * s.W, y = r() * s.H; g.fillStyle = `rgba(30,18,8,${0.05 + r() * 0.1})`;
    if (rot) g.fillRect(x, y, 10 + r() * 40, 1); else g.fillRect(x, y, 1, 10 + r() * 40);
  }
  s.noise(0.3, 1.5, 'multiply', 8, seed).grain(0.06);
}
function parquet(s, seed) { // herringbone oak, the pride of the flat once
  const g = s.g, r = s.r, L = 0.36 * s.ppm, W = 0.072 * s.ppm;
  s.fill('#3a2616');
  g.save(); g.translate(s.W / 2, s.H / 2); g.rotate(Math.PI / 4);
  const R = Math.hypot(s.W, s.H) / 2 + L, n = Math.ceil(R / W) + 2, m = Math.ceil(R / L) + 2;
  const plank = (x, y, w, h) => {
    const k = 0.72 + r() * 0.42;
    g.fillStyle = `rgb(${112 * k | 0},${76 * k | 0},${45 * k | 0})`; g.fillRect(x, y, w, h);
    g.fillStyle = `rgba(30,18,8,${0.08 + r() * 0.1})`; for (let i = 0; i < 3; i++) (w > h ? g.fillRect(x, y + r() * h, w, 1) : g.fillRect(x + r() * w, y, 1, h));
    g.strokeStyle = 'rgba(18,10,4,0.6)'; g.lineWidth = 1.2; g.strokeRect(x, y, w, h);
  };
  for (let c = -m; c <= m; c++) for (let t = -n; t <= n; t++) {
    const ox = c * L + t * W, oy = -c * L + t * W;
    if (Math.abs(ox - oy) > R * 2.2 || Math.abs(ox + oy) > R * 2.2) continue;
    plank(ox, oy, L, W); plank(ox, oy + W, W, L);
  }
  g.restore();
  s.noise(0.35, 1.4, 'multiply', 8, seed).noise(0.2, 0.4, 'overlay', 4, seed + 1).grain(0.07);
  s.noise(0.4, 0.5, 'source-over', 3, seed + 2, 'h');
}
function lino(s, a, b, tile = 0.3, seed) {
  const g = s.g, t = tile * s.ppm;
  s.fill(a);
  g.fillStyle = b;
  for (let y = 0; y < s.H; y += t) for (let x = 0; x < s.W; x += t) if (((x / t | 0) + (y / t | 0)) % 2) g.fillRect(x, y, t, t);
  s.noise(0.3, 1.2, 'multiply', 8, seed).grain(0.05).rough(0.6);
  s.rising(0, [0, 0, 0], 0);
}
// worn traffic path (darkened, scuffed) along a polyline of [x,y] metres (canvas coords)
function worn(s, pts, wm, a = 0.25) {
  const g = s.g; g.save(); g.strokeStyle = `rgba(30,22,14,${a})`; g.lineWidth = s.px(wm); g.lineCap = 'round'; g.lineJoin = 'round';
  g.filter = `blur(${s.px(wm) * 0.3}px)`;
  g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(s.px(x), s.px(y)) : g.moveTo(s.px(x), s.px(y)))); g.stroke(); g.restore();
}
// floor-space blob at metres (canvas coords from the room's NW corner)
function puddle(s, x, y, rx, ry, col = [40, 32, 22], a = 0.45, wet = true) {
  const p = blobPath(s.px(x), s.px(y), s.px(rx), s.px(ry), s.r, 0.3, 30);
  s.g.fillStyle = rgba(...col, a); s.g.fill(p);
  if (wet && s.rc) { s.rg.fillStyle = '#1a1a1a'; s.rg.fill(p); }
  s.g.strokeStyle = rgba(col[0] * 0.7, col[1] * 0.7, col[2] * 0.6, a * 0.8); s.g.lineWidth = 2; s.g.stroke(p);
}
function debrisDust(s, x, y, r, a = 0.5) { // plaster dust fan on a floor
  const g = s.g;
  for (let i = 0; i < 300; i++) {
    const ang = s.r() * 6.283, d = Math.pow(s.r(), 0.7) * s.px(r);
    g.fillStyle = `rgba(${170 + s.r() * 40},${160 + s.r() * 35},${140 + s.r() * 30},${a * (1 - d / s.px(r))})`;
    g.fillRect(s.px(x) + Math.cos(ang) * d, s.px(y) + Math.sin(ang) * d, 1 + s.r() * 4, 1 + s.r() * 3);
  }
  const grd = g.createRadialGradient(s.px(x), s.px(y), 0, s.px(x), s.px(y), s.px(r));
  grd.addColorStop(0, `rgba(185,175,155,${a * 0.6})`); grd.addColorStop(1, 'rgba(185,175,155,0)');
  g.fillStyle = grd; g.fillRect(s.px(x - r), s.px(y - r), s.px(r * 2), s.px(r * 2));
}

// common damage applied to any wall face given its openings
function windowDamage(s, face) {
  for (const h of face.holes) {
    if (h.kind === 'window' || h.kind === 'balcony') {
      // water has run down from the window sill for years
      s.waterStain((h.u0 + h.u1) / 2, h.y0 - 0.15, (h.u1 - h.u0) * 0.9, 0.35, 1.2);
      s.mould(h.u0 - 0.05, h.y1 + 0.1, 0.35, 0.5, 0.8);
      s.mould(h.u1 + 0.05, h.y1 + 0.1, 0.3, 0.4, 0.6);
      s.crack(h.u1, h.y1, 0.9, -Math.PI / 4 - 0.3);
      s.crack(h.u0, h.y1, 0.7, -Math.PI * 3 / 4);
    }
    if (h.kind === 'door' || h.kind === 'entry') {
      s.crack(h.u1 + 0.02, h.y1 + 0.02, 0.6, -Math.PI / 3);
      // hand grime beside the handle side
      const g = s.g, grd = g.createRadialGradient(s.px(h.u1 + 0.12), s.Y(1.05), 0, s.px(h.u1 + 0.12), s.Y(1.05), s.px(0.25));
      grd.addColorStop(0, 'rgba(40,30,20,0.25)'); grd.addColorStop(1, 'rgba(40,30,20,0)');
      g.fillStyle = grd; g.fillRect(s.px(h.u1 - 0.2), s.Y(1.4), s.px(0.6), s.px(0.7));
    }
  }
}

// --------------------------------------------------------------------- walls
export function paintWall(room, side, face) {
  const s = new Surface(face.W, H, PPM, seedN++);
  const ext = face.ext, W = face.W, r = s.r;
  switch (room) {
    case 'living': {
      wallpaper(s, 'damask', '#9fa18a', '#5d6450', 11);
      s.falling(0.35, [70, 60, 40], 0.3).rising(0.4, [50, 40, 30], 0.3);
      if (side === 'n') { // the wet wall: the flat above leaked here through two winters
        s.waterStain(1.2, H - 0.1, 2.4, 1.2, 1.4).waterStain(3.8, H - 0.1, 1.2, 0.8, 1);
        s.peel(0.35, 1.0, 0.6, 1.2, underPlaster()).peel(4.0, 0.55, 0.6, 0.5, underBrick(PPM));
        s.mould(0.1, 2.5, 0.5, 1.2, 1.2).mould(0.15, 0.2, 0.4, 0.6, 1);
      }
      if (side === 'w') { // above the sofa: the family wall. most frames are still here; two are not
        s.ghost(1.2, 1.75, 0.42, 0.32).ghost(3.3, 1.9, 0.28, 0.36);
        s.waterStain(0.2, H - 0.05, 0.5, 1.6, 1).mould(0.0, 2.4, 0.3, 0.9, 1.1);
        s.peel(4.6, 2.2, 0.8, 0.7, underPlaster()).crack(2.6, H, 1.2, Math.PI / 2 + 0.2);
      }
      if (side === 's') { // the box-room wall. someone sprayed this after the family left
        s.peel(0.5, 1.6, 0.5, 0.9, underPlaster());
        s.spray('14 IS EMPTY', 1.05, 1.75, 0.3, '#22201e', -0.05);
        // struck through, hard
        const g = s.g; g.save(); g.strokeStyle = 'rgba(25,22,20,0.9)'; g.lineWidth = 9; g.beginPath(); g.moveTo(s.px(0.12), s.Y(1.7)); g.lineTo(s.px(1.98), s.Y(1.85)); g.stroke(); g.restore();
        s.spray("no it isn't", 1.25, 1.3, 0.12, '#5e1a14', 0.04, '"Segoe Print","Bradley Hand",cursive');
        s.mould(4.3, 2.6, 0.5, 0.4, 0.7).crack(1.1, H, 1.4, Math.PI / 2);
        s.peel(4.0, 0.6, 0.45, 0.6, underBrick(PPM));
      }
      if (side === 'e') {
        s.ghost(2.1, 2.3, 1.6, 0.06, false); // the shadow line of the wall unit's cornice
        s.crack(1.0, H, 1.0, Math.PI / 2 - 0.2).peel(0.3, 2.3, 0.4, 0.4, underPlaster());
      }
      break;
    }
    case 'bedroom': {
      wallpaper(s, 'stripe-floral', '#bba897', '#7d5d54', 21);
      s.falling(0.3, [60, 50, 40], 0.25).rising(0.3, [50, 40, 30], 0.25).corners(0.3);
      if (side === 'w') { s.ghost(1.0 + 0.5, 1.55, 0.6, 0.45); s.ghost(2.75, 1.4, 0.18, 0.24); s.crack(0.4, H, 1.3, Math.PI / 2 + 0.3); }
      if (side === 'n') { s.mould(W - 0.1, 2.4, 0.6, 1.3, 1.3).mould(W - 0.1, 0.25, 0.4, 0.5, 1).waterStain(W - 0.4, H - 0.05, 0.7, 0.9, 1); s.peel(0.3, 1.9, 0.4, 0.8, underPlaster()); }
      if (side === 'e') { s.peel(2.9, 1.4, 0.5, 0.7, underBrick(PPM)); s.scrawl(['М + И', '1981'], 3.3, 0.55, 0.045, 'rgba(60,40,30,0.55)', -0.1); }
      if (side === 's') { s.crack(W * 0.4, H, 0.9, Math.PI / 2); }
      break;
    }
    case 'kitchen': {
      plasterWall(s, '#cfc9b8', 31); s.rough(0.9);
      oilPaintDado(s, '#7f9a86', 1.5, '#3d4d40');
      s.falling(0.9, [35, 28, 20], 0.55); // decades of cooking
      if (side === 'e') { // counter wall: tiled splashback over the worktop
        tilesWall(s, 1.5, 0.15, '#c4c2b2', '#5c5a50', 3);
        s.noise(0.4, 1.0, 'multiply', 8, 34).falling(1.2, [50, 40, 25], 0.35);
        for (let i = 0; i < 5; i++) s.waterStain(0.3 + s.r() * (W - 0.6), 1.45, 0.3, 0.3, 0.8);
        const g = s.g; g.fillStyle = 'rgba(30,20,10,0.35)'; g.fillRect(s.px(2.3), s.Y(1.5), s.px(0.6), s.px(0.6)); // grease behind the stove
      }
      if (side === 'n') { s.waterStain(0.4, H - 0.1, 0.5, 1.4, 1.2).mould(0.1, 2.5, 0.4, 0.8, 1.2).mould(W - 0.1, 2.4, 0.5, 0.9, 1.4); }
      if (side === 'w') { s.ghost(1.6, 1.9, 0.32, 0.32); s.crack(2.8, H, 1.4, Math.PI / 2 + 0.2); s.peel(3.3, 0.9, 0.5, 0.5, underBrick(PPM)); }
      if (side === 's') { s.peel(0.5, 2.3, 0.5, 0.4, underPlaster()); }
      break;
    }
    case 'hall': {
      wallpaper(s, 'geometric', '#a89a80', '#6f604c', 41);
      s.rising(1.1, [45, 35, 25], 0.35).corners(0.25);
      // shoulder rub along the whole corridor
      { const g = s.g, grd = g.createLinearGradient(0, s.Y(1.5), 0, s.Y(1.1)); grd.addColorStop(0, 'rgba(50,40,30,0)'); grd.addColorStop(0.5, 'rgba(50,40,30,0.12)'); grd.addColorStop(1, 'rgba(50,40,30,0)'); g.fillStyle = grd; g.fillRect(0, s.Y(1.5), s.W, s.px(0.4)); }
      if (side === 'n') { s.peel(W - 0.6, 1.9, 0.5, 0.8, underPlaster()).crack(3.2, H, 1.1, Math.PI / 2); }
      if (side === 's') { s.peel(1.8, 0.5, 0.5, 0.5, underBrick(PPM)); s.ghost(W - 0.35, 1.7, 0.36, 0.5, false); }
      if (side === 'e') { s.crack(0.1, 2.1, 0.5, -Math.PI / 2 - 0.4); }
      if (side === 'w') { s.waterStain(0.6, H - 0.05, 0.6, 0.7, 0.8); }
      break;
    }
    case 'child': {
      wallpaper(s, 'kids', '#a9bccb', '#e6ecef', 51, 0.4);
      s.noise(0.15, 1, 'multiply', 10, 52).rising(0.35, [50, 45, 40], 0.25).corners(0.25);
      if (side === 's') { s.mould(0.1, 2.5, 0.4, 1, 1).mould(W - 0.1, 2.5, 0.4, 1, 1); }
      if (side === 'w') { // crayon, low down, at a child's reach
        const g = s.g; g.save(); g.lineWidth = 3; g.lineCap = 'round';
        const cols = ['rgba(200,40,30,0.7)', 'rgba(40,90,190,0.7)', 'rgba(230,180,30,0.75)', 'rgba(30,130,50,0.7)'];
        for (let i = 0; i < 9; i++) { g.strokeStyle = cols[i % 4]; g.beginPath(); let x = s.px(0.3 + i * 0.25), y = s.Y(0.4 + r() * 0.5); g.moveTo(x, y); for (let k = 0; k < 6; k++) { x += (r() - 0.3) * 18; y += (r() - 0.5) * 18; g.lineTo(x, y); } g.stroke(); }
        // a house with all its windows coloured in black
        g.strokeStyle = 'rgba(30,30,30,0.75)'; g.lineWidth = 2.5; const hx = s.px(2.0), hy = s.Y(0.95);
        g.strokeRect(hx, hy, 60, 80); g.fillStyle = 'rgba(20,20,20,0.85)';
        for (let a = 0; a < 3; a++) for (let b = 0; b < 4; b++) g.fillRect(hx + 6 + a * 18, hy + 6 + b * 18, 11, 11);
        g.restore();
      }
      if (side === 'e') { s.ghost(1.3, 1.5, 0.3, 0.4, true); s.peel(2.2, 2.3, 0.4, 0.4, underPlaster()); }
      break;
    }
    case 'bath': {
      plasterWall(s, '#b9bcb0', 61); s.rough(0.85);
      tilesWall(s, 1.65, 0.15, side === 'n' || side === 's' ? '#b4bcb2' : '#b8c0b4', '#5b5a50', 62);
      s.noise(0.45, 1.2, 'multiply', 8, 64).noise(0.25, 0.4, 'multiply', 3, 65);
      s.falling(0.6, [40, 45, 35], 0.45).rising(0.9, [55, 50, 30], 0.45);
      for (let i = 0; i < 6; i++) s.mould(s.r() * W, 0.2 + s.r() * 1.3, 0.2 + s.r() * 0.4, 0.15 + s.r() * 0.3, 0.8);
      s.mould(0.15, 2.3, 0.6, 1.4, 1.6).mould(W - 0.15, 2.3, 0.6, 1.4, 1.6).mould(W * 0.5, H - 0.1, W * 0.7, 0.5, 1.1);
      s.waterStain(W * 0.4, H - 0.05, 1.4, 1.6, 1.5);
      if (side === 's') { s.mould(1.1, 0.7, 1.5, 0.4, 1.6); } // tide line above where the tub sits
      if (side === 'e') { s.crack(1.2, 1.65, 1.0, Math.PI / 2 - 0.1, 3); }
      break;
    }
    case 'storage': {
      plasterWall(s, '#b5ab98', 71);
      s.peel(W * 0.5, 1.4, W * 0.9, 1.6, underBrick(PPM, false), false); // the plaster's mostly gone in here
      s.rising(0.5, [40, 35, 30], 0.4).falling(0.5, [30, 28, 25], 0.4).corners(0.4);
      if (side === 'e') { // his count: the days, scratched with a nail, in rows
        s.tally(0.35, 1.75, 43, 0.13, 'rgba(235,225,205,0.75)');
        s.scrawl(['three, then three'], 0.6, 0.95, 0.06, 'rgba(230,220,200,0.6)', -0.04);
      }
      if (side === 'w') s.mould(0.1, 2.4, 0.5, 1.2, 1);
      if (side === 's') s.mould(W - 0.1, 0.3, 0.6, 0.5, 1).waterStain(W * 0.3, H, 0.8, 1, 0.8);
      break;
    }
  }
  if (ext) s.corners(0.35, 0.35);
  windowDamage(s, face);
  return s;
}

// --------------------------------------------------------------------- floors
// s covers the room's inner rect; canvas x = metres east of x0, canvas y = metres south of z0
export function paintFloor(room, W, D) {
  const s = new Surface(W, D, PPM, seedN++);
  switch (room) {
    case 'living':
      parquet(s, 12); s.rough(0.75);
      // water damage: the boards near the balcony door cupped, grey and lifted
      puddle(s, 3.6, 0.5, 1.0, 0.6, [70, 66, 56], 0.5, false);
      puddle(s, 1.6, 0.35, 1.4, 0.35, [60, 56, 48], 0.4, false);
      s.noise(0.35, 0.4, 'source-over', 2, 13, 'h');
      worn(s, [[4.3, 4.7], [4.0, 3.5], [3.5, 3.0], [3.5, 1.4], [3.2, 0.2]], 0.6, 0.18);
      debrisDust(s, 2.6, 3.9, 1.3, 0.55);
      s.g.fillStyle = 'rgba(40,30,20,0.4)'; s.g.fill(blobPath(s.px(2.5), s.px(1.9), s.px(0.2), s.px(0.12), s.r)); // something spilled off the table
      break;
    case 'bedroom':
      floorPlanks(s, '#5e3e2a', 0.16, false, 22); s.rough(0.7);
      worn(s, [[2.6, 3.8], [2.4, 3.0], [1.5, 2.9]], 0.5, 0.15);
      puddle(s, W - 0.4, 0.2, 0.5, 0.25, [40, 36, 30], 0.35);
      break;
    case 'kitchen':
      lino(s, '#a79c84', '#5c5b4e', 0.3, 32);
      worn(s, [[1.0, 3.8], [1.4, 2.2], [1.9, 1.3]], 0.7, 0.2);
      // torn linoleum by the sink showing the screed
      s.peel(1.95, D - 1.3, 0.5, 0.4, underConcrete(), false);
      puddle(s, 2.0, 0.35, 0.35, 0.2, [30, 30, 28], 0.4); // under the leaking riser
      break;
    case 'hall':
      lino(s, '#76604a', '#6c5743', 0.5, 42); s.noise(0.3, 0.5, 'multiply', 4, 43);
      worn(s, [[W, 0.65], [3.0, 0.7], [0.2, 0.6]], 0.7, 0.3);
      // dried muddy footprints from the front door going in, and not coming back out
      { const g = s.g; for (let i = 0; i < 9; i++) { const x = W - 0.4 - i * 0.55, y = 0.55 + (i % 2) * 0.18; g.save(); g.translate(s.px(x), s.px(y)); g.rotate(Math.PI / 2); g.fillStyle = `rgba(45,35,22,${0.5 - i * 0.04})`; g.beginPath(); g.ellipse(0, 0, s.px(0.045), s.px(0.11), 0, 0, 6.283); g.fill(); g.restore(); } }
      break;
    case 'child':
      floorPlanks(s, '#6a4a32', 0.14, true, 52); s.rough(0.75);
      break;
    case 'bath': {
      const g = s.g, t = 0.1 * s.ppm; s.fill('#5a5850').rough(0.5);
      for (let y = 0; y < s.H; y += t) for (let x = 0; x < s.W; x += t) {
        if (s.r() < 0.04) continue;
        const k = 0.85 + s.r() * 0.15; g.fillStyle = (((x / t | 0) + (y / t | 0)) % 2) ? `rgb(${190 * k | 0},${186 * k | 0},${172 * k | 0})` : `rgb(${120 * k | 0},${128 * k | 0},${126 * k | 0})`;
        g.fillRect(x + 1, y + 1, t - 2, t - 2); s.rg.fillStyle = '#303030'; s.rg.fillRect(x + 1, y + 1, t - 2, t - 2);
      }
      s.noise(0.4, 0.8, 'multiply', 6, 63);
      puddle(s, 1.4, 1.0, 1.0, 0.7, [30, 34, 28], 0.55); // the ceiling's still letting water in
      debrisDust(s, 1.2, 0.95, 1.1, 0.6);
      break;
    }
    case 'storage':
      s.fill('#6f6b62').noise(0.45, 0.6, 'multiply', 5, 72).noise(0.25, 1.5, 'overlay', 10, 73).grain(0.1).rough(0.9);
      s.noise(0.6, 0.5, 'source-over', 3, 74, 'h');
      worn(s, [[1.8, 0], [1.6, 1.2], [1.0, 2.1]], 0.6, 0.25);
      break;
  }
  return s;
}

// --------------------------------------------------------------------- ceilings
export function paintCeiling(room, W, D) {
  const s = new Surface(W, D, 64, seedN++);
  s.fill(room === 'kitchen' ? '#bdb6a2' : room === 'bath' ? '#a9aa9c' : '#c6c0ae');
  s.noise(0.3, 1.5, 'multiply', 10, seedN).noise(0.15, 0.5, 'overlay', 4, seedN + 1).grain(0.05);
  const g = s.g;
  // fine craquelure everywhere
  for (let i = 0; i < 7; i++) s.crack(s.r() * W, s.r() * D, 0.3 + s.r() * 0.7, s.r() * 6.28, 2, 0.6);
  const stain = (x, y, rx, ry, k = 1) => { // ceiling coords: x east, y south (metres)
    for (let ring = 0; ring < 5; ring++) {
      const p = blobPath(s.px(x), s.px(y), s.px(rx) * (1 - ring * 0.17), s.px(ry) * (1 - ring * 0.17), s.r, 0.2, 40);
      g.fillStyle = rgba(118 - ring * 10, 90 - ring * 9, 50, 0.1 * k); g.fill(p);
      g.strokeStyle = rgba(90, 62, 30, 0.25 * k); g.lineWidth = 2; g.stroke(p);
    }
  };
  const mouldC = (x, y, rx, ry) => { const n = 220; for (let i = 0; i < n; i++) { const a = s.r() * 6.28, d = Math.pow(s.r(), 0.6); g.fillStyle = rgba(30, 35, 25, (1 - d) * 0.4 + 0.05); g.beginPath(); g.arc(s.px(x + Math.cos(a) * rx * d), s.px(y + Math.sin(a) * ry * d), 1 + (1 - d) * 3, 0, 6.28); g.fill(); } };
  if (room === 'living') { stain(2.5, 3.85, 1.5, 1.1, 1.4); stain(1.6, 0.6, 1.4, 0.6, 1.2); mouldC(0.3, 0.2, 0.8, 0.4); }
  if (room === 'bedroom') { stain(W - 0.5, 0.5, 0.8, 0.6, 1); mouldC(W - 0.2, 0.15, 0.6, 0.3); }
  if (room === 'kitchen') { // soot over the stove
    const grd = g.createRadialGradient(s.px(W - 0.3), s.px(2.6), 0, s.px(W - 0.3), s.px(2.6), s.px(1.3));
    grd.addColorStop(0, 'rgba(25,20,15,0.55)'); grd.addColorStop(1, 'rgba(25,20,15,0)'); g.fillStyle = grd; g.fillRect(0, 0, s.W, s.H);
    stain(W - 0.4, 0.4, 0.6, 0.5, 1.2); mouldC(W - 0.15, 0.15, 0.5, 0.4);
  }
  if (room === 'bath') { stain(1.2, 0.95, 1.6, 1.2, 1.8); mouldC(0.3, D - 0.3, 1, 0.5); mouldC(W - 0.3, 0.3, 0.8, 0.6); }
  if (room === 'hall') { stain(4.0, 0.7, 0.9, 0.5, 0.8); }
  if (room === 'storage') { stain(1.0, 1.4, 1.2, 1.0, 1.2); mouldC(0.2, D - 0.2, 0.9, 0.6); }
  if (room === 'child') { stain(0.8, D - 0.4, 0.8, 0.4, 0.8); }
  // a rose / light fitting ring left in the plaster
  return s;
}

void noiseCanvas;

// --------------------------------------------------------------------- Flat 51: the echo
// The same flat as 47, the same paper on the walls, but nobody has ever lived in it. Pale
// squares where 47's furniture stands; dust so even it looks like felt.
const ECHO = {
  living: ['damask', '#a9aa96', '#6c7360'], bedroom: ['stripe-floral', '#c4b4a6', '#8c6c63'], hall: ['geometric', '#b4a88e', '#7c6e5a'],
  child: ['kids', '#b6c6d2', '#e6ecef'], kitchen: null, bath: null, storage: null,
};
export function paintEcho(room, side, face) {
  const s = new Surface(face.W, H, 96, seedN++);
  const e = ECHO[room];
  if (e) wallpaper(s, e[0], e[1], e[2], 900 + seedN, room === 'child' ? 0.4 : 0.53);
  else if (room === 'bath') { plasterWall(s, '#c4c6bc', 901); tilesWall(s, 1.65, 0.15, '#cfd8d4', '#9a9a90', 902); }
  else if (room === 'kitchen') { plasterWall(s, '#d4cfc0', 903); oilPaintDado(s, '#8aa592', 1.5, '#4d5d50'); }
  else plasterWall(s, '#c4bcaa', 904);
  // dust over everything, evenly, like a fall of snow
  s.g.fillStyle = 'rgba(200,196,186,0.28)'; s.g.fillRect(0, 0, s.W, s.H);
  s.noise(0.2, 1.4, 'soft-light', 9, seedN);
  // pale ghosts of furniture that was never here
  for (let i = 0; i < 2; i++) if (s.r() < 0.7) { const w = 0.5 + s.r() * 1.5, h = 0.6 + s.r() * 1.2; s.ghost(0.3 + s.r() * Math.max(0.1, face.W - 0.6), h / 2 + 0.05, w, h, false); }
  if (s.r() < 0.5) s.ghost(0.4 + s.r() * Math.max(0.1, face.W - 0.8), 1.7, 0.35, 0.45);
  return s;
}
export function paintEchoFloor(room, W, D) {
  const s = new Surface(W, D, 64, seedN++);
  if (room === 'living') parquet(s, 950);
  else if (room === 'kitchen') lino(s, '#a79c84', '#5c5b4e', 0.3, 951);
  else if (room === 'hall') lino(s, '#76604a', '#6c5743', 0.5, 952);
  else if (room === 'bath') { s.fill('#8a8a80'); for (let y = 0; y < s.H; y += 6.4) for (let x = 0; x < s.W; x += 6.4) { s.g.fillStyle = ((x + y) / 6.4) % 2 ? '#bab6aa' : '#8a928e'; s.g.fillRect(x + 0.5, y + 0.5, 5.4, 5.4); } }
  else if (room === 'storage') s.fill('#6f6b62').noise(0.4, 0.6, 'multiply', 5, 953);
  else floorPlanks(s, '#6a4a32', 0.15, room === 'child', 954);
  s.g.fillStyle = 'rgba(190,186,176,0.55)'; s.g.fillRect(0, 0, s.W, s.H); // a felt of dust, unbroken
  s.noise(0.25, 0.8, 'soft-light', 6, seedN);
  return s;
}

// --------------------------------------------------------------------- Flat 48: the draft
// Not decayed: unfinished. Bare skim plaster, pencil setting-out lines, words where
// things should be.
export function paintDraft(room, side, face, label) {
  const s = new Surface(face.W, H, 64, seedN++).fill('#cfcdc6').noise(0.08, 2, 'multiply', 12, seedN);
  const g = s.g;
  g.strokeStyle = 'rgba(70,70,80,0.35)'; g.lineWidth = 1;
  // setting-out: a datum line, verticals, dimension arrows
  g.beginPath(); g.moveTo(0, s.Y(1.0)); g.lineTo(s.W, s.Y(1.0)); g.stroke();
  for (let x = 0.6; x < face.W; x += 0.6 + s.r() * 0.8) { g.beginPath(); g.moveTo(s.px(x), s.Y(0.05)); g.lineTo(s.px(x), s.Y(0.4 + s.r() * 0.3)); g.stroke(); }
  g.font = `${s.px(0.07)}px "Segoe Print","Bradley Hand",cursive`; g.fillStyle = 'rgba(60,60,70,0.55)';
  g.fillText(`${face.W.toFixed(2)}`, s.px(face.W / 2) - 20, s.Y(1.04));
  if (label && s.r() < 0.8) { g.font = `${s.px(0.11)}px "Segoe Print","Bradley Hand",cursive`; g.fillText(label, s.px(0.3 + s.r() * Math.max(0, face.W - 1.5)), s.Y(1.6 + s.r() * 0.4)); }
  // where a window should be, it's been drawn instead
  for (const h of face.holes) { if (h.kind !== 'window') continue; g.strokeStyle = 'rgba(60,60,70,0.4)'; g.strokeRect(s.px(h.u0) - 6, s.Y(h.y1) - 6, s.px(h.u1 - h.u0) + 12, s.px(h.y1 - h.y0) + 12); }
  return s;
}

// --------------------------------------------------------------------- the stairwell
// Gloss paint to shoulder height (bottle green), whitewash above, a century of hands.
export function paintStair(W, Hh, seed, o = {}) {
  const s = new Surface(W, Hh, 64, seed);
  plasterWall(s, '#c9c6b6', seed);
  oilPaintDado(s, o.dado || '#4f6e62', 1.45, '#22322c');
  s.rising(0.5, [30, 28, 22], 0.45).falling(0.8, [40, 36, 30], 0.35);
  for (let i = 0; i < 6; i++) s.crack(s.r() * W, Hh * (0.5 + s.r() * 0.5), 0.4 + s.r() * 0.8, Math.PI / 2 + (s.r() - 0.5));
  for (let i = 0; i < 3; i++) s.peel(s.r() * W, 1.6 + s.r() * (Hh - 1.9), 0.3 + s.r() * 0.5, 0.3 + s.r() * 0.5, underPlaster(), false);
  s.mould(s.r() * W, Hh - 0.2, 0.8, 0.5, 0.8);
  if (o.tags) { const t = ['ВИТЯ', 'ЦОЙ ЖИВ', '47 ↑', 'Zenit', 'Lena+?', 'XXX', '3 3']; for (let i = 0; i < 2; i++) s.spray(t[(s.r() * t.length) | 0], 0.5 + s.r() * (W - 1), 0.6 + s.r() * 0.6, 0.12 + s.r() * 0.12, s.r() < 0.6 ? '#1c1c1c' : '#6a1a14', (s.r() - 0.5) * 0.3); }
  return s;
}
