// Furniture and fittings, built from parts: carcasses with working doors and drawers,
// soft furnishings draped over what's under them, the small objects of a life.
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { G, mat, box, cyl, group, solid, interactive, onUpdate, staticBox, collider } from './core.js';
import { woodTex, fabricTex, metalTex, enamelTex, paperTex, Surface, rng, blobPath, canvas, textSheet, noiseCanvas } from './textures.js';
import { sfx } from './audio.js';
import { makeProp, pickable } from './props.js';

// ---------------------------------------------------------------- materials
export const M = {};
export function initMaterials() {
  M.veneer = mat('veneer', { map: woodTex('#5a3620', 101, 1).map, roughness: 0.55 });
  M.veneerDull = mat('veneerDull', { map: woodTex('#4a2e1c', 102, 0.9).map, roughness: 0.75 });
  M.pine = mat('pine', { map: woodTex('#8a6a44', 103, 1).map, roughness: 0.8 });
  M.paintedWood = mat('paintedWood', { map: woodTex('#c9c0aa', 104, 1).map, roughness: 0.7, color: 0xe0d8c4 });
  M.paintedBlue = mat('paintedBlue', { map: woodTex('#7f97a3', 105, 1).map, roughness: 0.7 });
  M.chipboard = mat('chipboard', { map: woodTex('#8c7656', 106, 1).map, roughness: 0.95 });
  M.sofa = mat('sofaFab', { map: fabricTex('#5b4f3a', 107, 2).map, roughness: 1 });
  M.chairFab = mat('chairFab', { map: fabricTex('#6a3a2a', 108, 0).map, roughness: 1 });
  M.foam = mat('foam', { color: 0xb59a52, roughness: 1 });
  M.sheet = mat('sheet', { map: fabricTex('#c7c0b0', 109, 0).map, roughness: 1 });
  M.blanket = mat('blanket', { map: fabricTex('#6e3d34', 110, 1).map, roughness: 1 });
  M.childBlanket = mat('childBlanket', { map: fabricTex('#8a9cb5', 111, 1).map, roughness: 1 });
  M.rug = mat('rug', { map: rugTex(), roughness: 1 });
  M.iron = mat('ironF', { map: metalTex('#4a4440', 0.7, 112).map, roughness: 0.7, metalness: 0.5 });
  M.rust = mat('rustF', { map: metalTex('#6a4a34', 1.4, 113).map, roughness: 0.85, metalness: 0.3 });
  M.chrome = mat('chrome', { color: 0x9a9a96, roughness: 0.3, metalness: 0.9, map: metalTex('#9a9a96', 0.25, 114).map });
  M.enamel = mat('enamelW', { map: enamelTex('#e6e2d4', 5, 115).map, roughness: 0.35 });
  M.enamelCream = mat('enamelC', { map: enamelTex('#d9d0b4', 6, 116).map, roughness: 0.4 });
  M.radiator = mat('radiator', { map: metalTex('#c8c0ac', 0.6, 117).map, roughness: 0.6, metalness: 0.2 });
  M.black = mat('blackPlastic', { color: 0x1a1918, roughness: 0.5 });
  M.bakelite = mat('bakelite', { color: 0x2a1d16, roughness: 0.35 });
  M.glass = mat('clearGlass', { color: 0xc8d4d0, roughness: 0.05, metalness: 0.1, transparent: true, opacity: 0.25, depthWrite: false });
  M.greenGlass = mat('greenGlass', { color: 0x2f5a34, roughness: 0.1, metalness: 0.1, transparent: true, opacity: 0.7 });
  M.brownGlass = mat('brownGlass', { color: 0x5a3414, roughness: 0.1, metalness: 0.1, transparent: true, opacity: 0.75 });
  M.paper = mat('paperM', { map: paperTex('#ddd2b8', 118).map, roughness: 0.95 });
  M.cardboard = mat('cardboard', { map: woodTex('#9c7c52', 119, 1).map, roughness: 1, color: 0xd8c0a0 });
  M.porcelain = mat('porcelain', { color: 0xe8e4dc, roughness: 0.25 });
  M.mould = mat('foodMould', { color: 0x3a3a2a, roughness: 1, map: fabricTex('#4a4a34', 120, 0).map });
  M.wax = mat('wax', { color: 0xe8dcc0, roughness: 0.6, emissive: 0x000000 });
  M.mirror = mat('mirror', { color: 0x9aa0a0, roughness: 0.05, metalness: 1 });
  M.tile = mat('tileM', { map: enamelTex('#d6dcd8', 4, 121).map, roughness: 0.3 });
  M.water = mat('stagnant', { color: 0x16140c, roughness: 0.05, metalness: 0.2, transparent: true, opacity: 0.92 });
  M.cloth = [
    mat('cl0', { map: fabricTex('#3d4a5c', 122, 0).map, roughness: 1 }), mat('cl1', { map: fabricTex('#7a6a50', 123, 1).map, roughness: 1 }),
    mat('cl2', { map: fabricTex('#5a2a2a', 124, 0).map, roughness: 1 }), mat('cl3', { map: fabricTex('#9a9a8a', 125, 2).map, roughness: 1 }),
    mat('cl4', { map: fabricTex('#2a2a2a', 126, 0).map, roughness: 1 }), mat('cl5', { map: fabricTex('#c4a46a', 127, 1).map, roughness: 1 }),
  ];
  M.books = [0x6a2a22, 0x2a3a5a, 0x3a5a3a, 0x7a6a3a, 0x4a3a2a, 0x8a8070, 0x2a2a2a, 0x5a3a5a].map((c, i) => mat('book' + i, { color: c, roughness: 0.8, map: bookTex(i).map }));
}
function rugTex() {
  const s = new Surface(2, 3, 128, 201).fill('#6e2a22'), g = s.g;
  g.strokeStyle = '#c8a060'; g.lineWidth = 10; g.strokeRect(20, 20, s.W - 40, s.H - 40);
  g.strokeStyle = '#1e2a3a'; g.lineWidth = 18; g.strokeRect(50, 50, s.W - 100, s.H - 100);
  g.fillStyle = '#1e2a3a'; g.beginPath(); g.ellipse(s.W / 2, s.H / 2, s.W * 0.25, s.H * 0.3, 0, 0, 6.28); g.fill();
  g.fillStyle = '#c8a060'; for (let i = 0; i < 8; i++) { g.beginPath(); g.ellipse(s.W / 2, s.H / 2, 18 + i * 10, 30 + i * 16, 0, 0, 6.28); g.globalAlpha = 0.2; g.fill(); }
  g.globalAlpha = 1;
  for (let y = 70; y < s.H - 70; y += 32) for (let x = 70; x < s.W - 70; x += 32) { g.fillStyle = (x + y) % 64 ? 'rgba(200,160,96,0.25)' : 'rgba(20,30,50,0.25)'; g.fillRect(x, y, 10, 10); }
  s.noise(0.5, 0.7, 'multiply', 6, 202).grain(0.15);
  // worn bald through the middle, a dark tide mark from the water
  g.fillStyle = 'rgba(160,140,110,0.3)'; g.fill(blobPath(s.W / 2, s.H * 0.6, s.W * 0.3, s.H * 0.2, s.r));
  g.fillStyle = 'rgba(30,20,10,0.35)'; g.fill(blobPath(s.W * 0.2, s.H * 0.15, s.W * 0.35, s.H * 0.18, s.r));
  return s.textures().map;
}
function bookTex(i) {
  const s = new Surface(0.5, 0.5, 128, 300 + i).fill('#ffffff');
  const g = s.g; g.fillStyle = 'rgba(0,0,0,0.0)';
  g.fillStyle = 'rgba(200,170,90,0.8)'; g.fillRect(0, 10, 64, 4); g.fillRect(0, 50, 64, 4);
  s.noise(0.3, 0.5, 'multiply', 4, 300 + i).grain(0.1);
  return s.textures({ repeat: true });
}

// ---------------------------------------------------------------- generic parts
export function rbox(w, h, d, r, material, o = {}) {
  const m = new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 2, Math.min(r, w / 2, h / 2, d / 2)), material);
  m.castShadow = o.cast ?? true; m.receiveShadow = true;
  m.position.set(o.x || 0, (o.y || 0) + (o.base ? h / 2 : 0), o.z || 0);
  if (o.ry) m.rotation.y = o.ry; if (o.rx) m.rotation.x = o.rx; if (o.rz) m.rotation.z = o.rz;
  (o.parent || G.scene).add(m);
  if (o.static !== false) m.userData.static = true;
  return m;
}
export function lathe(points, seg, material, o = {}) {
  const m = new THREE.Mesh(new THREE.LatheGeometry(points.map(([r, y]) => new THREE.Vector2(r, y)), seg), material);
  m.castShadow = o.cast ?? true; m.receiveShadow = true;
  m.position.set(o.x || 0, o.y || 0, o.z || 0); if (o.ry) m.rotation.y = o.ry; if (o.rx) m.rotation.x = o.rx; if (o.rz) m.rotation.z = o.rz;
  (o.parent || G.scene).add(m);
  if (o.static !== false) m.userData.static = true;
  return m;
}

const drapeNoise = {};
// cloth heightfield draped over a set of boxes (footprints in the cloth's local frame)
// supports: [{x0,x1,z0,z1,top}]; cloth spans w x d centred at origin; falls hang toward floor y=floorY
export function drape(w, d, supports, material, o = {}) {
  const nx = o.nx || 36, nz = o.nz || 36, r = rng(o.seed || 1), floorY = o.floorY ?? 0;
  const g = new THREE.PlaneGeometry(w, d, nx, nz); g.rotateX(-Math.PI / 2);
  const p = g.attributes.position;
  const nk = o.seed || 1; const nzs = drapeNoise[nk] || (drapeNoise[nk] = noiseCanvas(64, 4, 3, nk).getContext('2d', { willReadFrequently: true }).getImageData(0, 0, 64, 64).data);
  const nval = (u, v) => nzs[(((v * 63) | 0) * 64 + ((u * 63) | 0)) * 4] / 255;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), z = p.getZ(i);
    let y = floorY + 0.01, best = Infinity;
    for (const s of supports) {
      const dx = Math.max(s.x0 - x, 0, x - s.x1), dz = Math.max(s.z0 - z, 0, z - s.z1), dd = Math.hypot(dx, dz);
      // over the support: its top; beyond it: hanging, dropping steeply with distance
      const yy = dd === 0 ? s.top : s.top - dd * (o.fall || 3.2) - dd * dd * 4;
      if (dd < best || yy > y) { if (yy > y) y = yy; best = Math.min(best, dd); }
    }
    y = Math.max(floorY + 0.008, y);
    const u = (x / w + 0.5), v = (z / d + 0.5);
    y += (nval(u, v) - 0.5) * (o.wrinkle ?? 0.06) + Math.sin(x * 9 + r() * 0.3) * 0.004;
    // where it lies on the floor, push it outward a little so it pools
    p.setY(i, y);
  }
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, material); m.castShadow = true; m.receiveShadow = true;
  m.material.side = THREE.DoubleSide;
  m.position.set(o.x || 0, o.y || 0, o.z || 0); if (o.ry) m.rotation.y = o.ry;
  (o.parent || G.scene).add(m); m.userData.static = true;
  return m;
}
// a crumpled garment on the floor
export function crumple(x, z, w, d, material, seed, o = {}) {
  return drape(w, d, [{ x0: -w * 0.25, x1: w * 0.2, z0: -d * 0.2, z1: d * 0.25, top: 0.06 }], material, { x, z, y: o.y || 0, ry: o.ry || 0, seed, wrinkle: 0.07, fall: 0.8, nx: 14, nz: 14, floorY: 0, ...o });
}

// ---------------------------------------------------------------- carcasses with doors and drawers
// a drawer that slides along local +z of `parent` (the carcass front faces +z)
export function drawer(parent, x, y, w, h, depth, front, o = {}) {
  const z0 = o.z || 0; const g = new THREE.Group(); g.position.set(x, y, z0); parent.add(g);
  const sideM = o.inner || M.chipboard;
  box(w, h, 0.018, front, { x: 0, y: 0, z: -0.009 + 0.001, parent: g, static: false });             // front
  box(w - 0.04, 0.012, depth - 0.03, sideM, { x: 0, y: -h / 2 + 0.03, z: -depth / 2, parent: g, static: false, cast: false }); // bottom
  for (const s of [-1, 1]) box(0.012, h * 0.7, depth - 0.03, sideM, { x: s * (w / 2 - 0.03), y: -h * 0.1, z: -depth / 2, parent: g, static: false, cast: false });
  box(w - 0.04, h * 0.7, 0.012, sideM, { x: 0, y: -h * 0.1, z: -depth + 0.03, parent: g, static: false, cast: false });
  const knob = o.knob !== false ? box(0.09, 0.012, 0.02, M.chrome, { x: 0, y: h * 0.15, z: 0.012, parent: g, static: false }) : null;
  void knob;
  const it = { open: 0, target: 0, max: Math.min(depth * 0.75, o.max || 0.35), contents: g };
  onUpdate((dt) => { if (it.open !== it.target) { it.open += Math.sign(it.target - it.open) * Math.min(Math.abs(it.target - it.open), dt * 1.2); g.position.z = z0 + it.open; } });
  interactive(g.children[0], {
    prompt: () => (o.stuck && !it.forced ? 'Pull the drawer' : it.target ? 'Close drawer' : 'Open drawer'),
    use: () => {
      if (o.stuck && !it.forced) { it.forced = true; it.target = it.max * 0.4; sfx('drawer', g.getWorldPosition(new THREE.Vector3()), { rate: 0.7 }); G.ui.toast(o.stuck); return; }
      it.target = it.target ? 0 : it.max; sfx('drawer', g.getWorldPosition(new THREE.Vector3()), { rate: it.target ? 1 : 1.2 });
    },
  });
  g.userData.drawer = it;
  return g;
}
// a hinged cabinet door on `parent`, hinge at local x=hx, panel spans toward +x (side=1) or -x (side=-1)
export function cabDoor(parent, hx, y, w, h, front, side = 1, o = {}) {
  const pv = new THREE.Group(); pv.position.set(hx, y, o.z ?? 0.01); parent.add(pv);
  const panel = o.glass
    ? (() => { const gg = new THREE.Group(); pv.add(gg); const t = 0.03;
      box(w, t * 1.5, 0.02, front, { x: side * w / 2, y: h / 2 - t, parent: gg, static: false }); box(w, t * 1.5, 0.02, front, { x: side * w / 2, y: -h / 2 + t, parent: gg, static: false });
      box(t * 1.5, h, 0.02, front, { x: side * (w - t), y: 0, parent: gg, static: false }); box(t * 1.5, h, 0.02, front, { x: side * t, y: 0, parent: gg, static: false });
      if (!o.broken) { const gl = new THREE.Mesh(new THREE.PlaneGeometry(w - t * 3, h - t * 3), M.glass); gl.position.set(side * w / 2, 0, 0.002); gl.renderOrder = 2; gg.add(gl); }
      return gg; })()
    : box(w, h, 0.02, front, { x: side * w / 2, y: 0, parent: pv, static: false });
  if (o.knob !== false) box(0.015, 0.07, 0.02, M.chrome, { x: side * (w - 0.04), y: 0, z: 0.02, parent: pv, static: false });
  const it = { a: o.open || 0, target: o.open || 0, max: o.max || 1.75 };
  pv.rotation.y = side * it.a;
  onUpdate((dt) => { if (it.a !== it.target) { it.a += Math.sign(it.target - it.a) * Math.min(Math.abs(it.target - it.a), dt * 3.2); pv.rotation.y = side * it.a; } });
  interactive(panel, {
    prompt: () => (o.locked ? o.locked : it.target ? 'Close' : 'Open'),
    use: () => {
      if (o.locked) { G.ui.toast(o.lockedMsg || 'Locked.'); sfx('click', pv.getWorldPosition(new THREE.Vector3())); return; }
      it.target = it.target ? 0 : it.max; sfx(o.sound || 'cabinet', pv.getWorldPosition(new THREE.Vector3()), { rate: it.target ? 1 : 1.3 });
    },
  });
  return { pivot: pv, it };
}

// open-fronted carcass: back, sides, top, bottom; front at local z = d/2. Returns the group
export function carcass(w, h, d, material, o = {}) {
  const g = group(o);
  const t = o.t || 0.018;
  box(w, h, t, o.backMat || M.chipboard, { x: 0, y: h / 2, z: -d / 2 + t / 2, parent: g });
  box(t, h, d, material, { x: -w / 2 + t / 2, y: h / 2, z: 0, parent: g });
  box(t, h, d, material, { x: w / 2 - t / 2, y: h / 2, z: 0, parent: g });
  if (!o.noTop) box(w, t, d, material, { x: 0, y: h - t / 2, z: 0, parent: g });
  box(w, t, d, material, { x: 0, y: (o.plinth || 0) + t / 2, z: 0, parent: g });
  if (o.plinth) box(w - 0.02, o.plinth, t, material, { x: 0, y: o.plinth / 2, z: d / 2 - 0.03, parent: g });
  for (const sy of o.shelves || []) box(w - t * 2, t, d - t, material, { x: 0, y: sy, z: t / 2, parent: g });
  if (o.solid !== false) {
    const c = Math.cos(o.ry || 0), s = Math.sin(o.ry || 0);
    void c; void s;
    solid(o.x || 0, o.y || 0, o.z || 0, w, h, d, o.ry || 0, { noPhys: true });
    // shelf surfaces for physics (so things rest on them) — top only plus shelves
    const yaw = o.ry || 0;
    for (const sy of [h, ...(o.shelves || []), (o.plinth || 0) + t]) staticBox(o.x || 0, (o.y || 0) + sy - 0.01, o.z || 0, w, 0.02, d, yaw);
    const back = new THREE.Vector3(0, 0, -d / 2).applyAxisAngle(new THREE.Vector3(0, 1, 0), yaw);
    staticBox((o.x || 0) + back.x, (o.y || 0) + h / 2, (o.z || 0) + back.z, w, h, 0.02, yaw);
    for (const sx of [-1, 1]) { const side = new THREE.Vector3(sx * w / 2, 0, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), yaw); staticBox((o.x || 0) + side.x, (o.y || 0) + h / 2, (o.z || 0) + side.z, 0.02, h, d, yaw); }
  }
  g.userData.dims = { w, h, d };
  return g;
}

// ---------------------------------------------------------------- small things
export function book(parent, x, y, z, o = {}) {
  const r = rng(o.seed || (x * 1000 + z * 77) | 0), w = o.w || 0.025 + r() * 0.03, h = o.h || 0.18 + r() * 0.08, d = o.d || 0.13 + r() * 0.05;
  const m = box(w, h, d, M.books[(r() * M.books.length) | 0], { x, y: y + h / 2, z, parent, ry: o.ry || 0, rz: o.rz || 0, static: false });
  return m;
}
export function bookRow(parent, x0, x1, y, z, seed, o = {}) {
  const r = rng(seed); let x = x0; const out = [];
  while (x < x1 - 0.03) {
    if (r() < (o.gaps || 0.06)) { x += 0.06 + r() * 0.1; continue; }
    const w = 0.022 + r() * 0.035; const lean = x + w > x1 - 0.1 && r() < 0.5 ? 0.2 : 0;
    const b = book(parent, x + w / 2, y, z, { w, seed: seed * 31 + out.length, rz: -lean });
    out.push(b); x += w + 0.002;
  }
  return out;
}
export function bottle(x, y, z, glassM, o = {}) {
  const pts = [[0, 0], [0.034, 0], [0.036, 0.01], [0.036, 0.17], [0.03, 0.2], [0.013, 0.24], [0.012, 0.3], [0.014, 0.305], [0, 0.305]];
  const m = lathe(pts.map(([a, b]) => [a * (o.s || 1), b * (o.s || 1)]), 12, glassM, { x, y, z, rz: o.rz, rx: o.rx, ry: o.ry, static: false });
  if (o.label) { const l = cyl(0.0365 * (o.s || 1), 0.0365 * (o.s || 1), 0.07, 12, o.label, { y: 0.09 * (o.s || 1), parent: m, open: true, static: false }); void l; }
  m.renderOrder = 1;
  return m;
}
export function jar(x, y, z, content, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); (o.parent || G.scene).add(g);
  const h = o.h || 0.14, r = o.r || 0.045;
  cyl(r * 0.92, r * 0.92, h * (o.fill ?? 0.75), 10, content, { y: h * (o.fill ?? 0.75) / 2 + 0.005, parent: g, static: false });
  const gl = cyl(r, r, h, 12, M.glass, { y: h / 2, parent: g, static: false }); gl.renderOrder = 2;
  cyl(r * 0.95, r * 0.95, 0.012, 12, o.lid || M.rust, { y: h + 0.006, parent: g, static: false });
  return g;
}
export function can(x, y, z, label, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); if (o.rz) g.rotation.z = o.rz; if (o.ry) g.rotation.y = o.ry; if (o.rx) g.rotation.x = o.rx; (o.parent || G.scene).add(g);
  cyl(0.037, 0.037, 0.105, 14, label, { y: 0.0525, parent: g, static: false });
  if (!o.open) cyl(0.035, 0.035, 0.004, 14, M.chrome, { y: 0.107, parent: g, static: false });
  return g;
}
export function labelMat(key, bg, fg, text, sub = '') {
  return mat('lab' + key, {
    map: textSheet(0.24, 0.1, (g, W, H) => {
      g.fillStyle = bg; g.fillRect(0, 0, W, H); g.fillStyle = fg; g.font = `bold ${H * 0.3}px Georgia, serif`; g.textAlign = 'center';
      g.fillText(text, W * 0.3, H * 0.5); g.font = `${H * 0.14}px Georgia, serif`; g.fillText(sub, W * 0.3, H * 0.75);
      g.fillText(text, W * 0.8, H * 0.5);
    }, bg, key.length), roughness: 0.6,
  });
}
export function plate(x, y, z, food, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); (o.parent || G.scene).add(g);
  lathe([[0, 0], [0.08, 0], [0.1, 0.012], [0.125, 0.02], [0.127, 0.022], [0, 0.012]], 18, M.porcelain, { parent: g, static: false });
  if (food) { // dried, collapsed, grown over
    const f = new THREE.Mesh(new THREE.SphereGeometry(0.06, 10, 6), food); f.scale.set(1, 0.25, 0.8); f.position.y = 0.018; f.castShadow = true; g.add(f);
    if (o.bone) box(0.07, 0.012, 0.012, M.porcelain, { x: 0.03, y: 0.03, z: 0.02, ry: 0.6, parent: g, static: false });
  }
  return g;
}
export function cup(x, y, z, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); (o.parent || G.scene).add(g);
  lathe([[0, 0], [0.03, 0], [0.038, 0.07], [0.04, 0.085], [0.036, 0.085], [0.034, 0.075], [0.026, 0.005], [0, 0.005]], 14, o.mat || M.porcelain, { parent: g, static: false });
  const handle = new THREE.Mesh(new THREE.TorusGeometry(0.022, 0.005, 5, 10, Math.PI), o.mat || M.porcelain); handle.rotation.z = -Math.PI / 2; handle.position.set(0.04, 0.045, 0); g.add(handle);
  if (o.rz) g.rotation.z = o.rz; if (o.ry) g.rotation.y = o.ry;
  return g;
}
export function candle(x, y, z, h = 0.08, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); (o.parent || G.scene).add(g);
  // melted down: a puddle of wax and a short stub
  const puddle = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.045, 0.006, 12), M.wax); puddle.position.y = 0.003; g.add(puddle);
  cyl(0.013, 0.016, h, 10, M.wax, { y: h / 2 + 0.004, parent: g, static: false });
  cyl(0.0015, 0.0015, 0.012, 4, M.black, { y: h + 0.01, parent: g, static: false });
  g.userData.top = h + 0.02;
  return g;
}

// a framed photograph, or the empty frame
export function photoTex(kind, seed) {
  const c = canvas(256, 320), g = c.getContext('2d'), r = rng(seed);
  const sepia = kind !== 'colour';
  const bg = g.createLinearGradient(0, 0, 0, 320); bg.addColorStop(0, sepia ? '#9a8a6a' : '#7a8a9a'); bg.addColorStop(1, sepia ? '#5a4a34' : '#4a4a3a');
  g.fillStyle = bg; g.fillRect(0, 0, 256, 320);
  // ground, a doorway or sea behind
  g.fillStyle = sepia ? 'rgba(60,45,30,0.6)' : 'rgba(70,80,60,0.6)'; g.fillRect(0, 230, 256, 90);
  if (kind === 'sea') { g.fillStyle = 'rgba(120,140,150,0.6)'; g.fillRect(0, 150, 256, 60); }
  const people = kind === 'wedding' ? [[100, 1.0, '#e8e4dc'], [160, 1.08, '#2a2a2a']] : kind === 'baby' ? [[128, 0.9, '#d8d0c0']] : kind === 'old' ? [[128, 1.0, '#3a3028']] : kind === 'sea' ? [[90, 1.0, '#a04030'], [150, 1.1, '#e8e0d0'], [120, 0.55, '#d8c040']] : [[80, 1.0, '#7a4a3a'], [170, 1.12, '#3a4a5a'], [125, 0.6, '#c8a050']];
  g.filter = 'blur(2px)';
  for (const [x, s, col] of people) {
    const top = 310 - 230 * s;
    g.fillStyle = col; g.beginPath(); g.roundRect(x - 28 * s, top + 52 * s, 56 * s, 200 * s, 18 * s); g.fill();
    g.fillStyle = sepia ? '#c8a888' : '#d8b098'; g.beginPath(); g.ellipse(x, top + 30 * s, 17 * s, 21 * s, 0, 0, 6.28); g.fill();
    g.fillStyle = 'rgba(30,20,10,0.7)'; g.beginPath(); g.ellipse(x, top + 16 * s, 18 * s, 11 * s, 0, Math.PI, 0); g.fill();
    if (kind === 'baby') { g.fillStyle = '#f0e8d8'; g.beginPath(); g.ellipse(x, top + 120, 40, 26, 0, 0, 6.28); g.fill(); }
  }
  g.filter = 'none';
  const v = g.createRadialGradient(128, 160, 60, 128, 160, 200); v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(30,20,10,0.6)'); g.fillStyle = v; g.fillRect(0, 0, 256, 320);
  // age: foxing, a fold line, water damage on one corner
  for (let i = 0; i < 30; i++) { g.fillStyle = `rgba(120,80,30,${r() * 0.3})`; g.beginPath(); g.arc(r() * 256, r() * 320, r() * 4, 0, 6.28); g.fill(); }
  if (r() < 0.5) { g.fillStyle = 'rgba(255,240,210,0.25)'; g.fillRect(0, 150 + r() * 40, 256, 2); }
  g.fillStyle = 'rgba(200,180,140,0.35)'; g.fill(blobPath(256, 320, 90, 70, r));
  g.strokeStyle = '#efe6d2'; g.lineWidth = 12; g.strokeRect(0, 0, 256, 320);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.userData = { canvas: c };
  return t;
}
export function frame(x, y, z, ry, w, h, kind, seed, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = ry; (o.parent || G.scene).add(g);
  const fm = o.frameMat || M.veneer;
  const t = 0.025;
  box(w, t, 0.02, fm, { y: h / 2 - t / 2, parent: g, static: false }); box(w, t, 0.02, fm, { y: -h / 2 + t / 2, parent: g, static: false });
  box(t, h, 0.02, fm, { x: -w / 2 + t / 2, parent: g, static: false }); box(t, h, 0.02, fm, { x: w / 2 - t / 2, parent: g, static: false });
  box(w, h, 0.005, M.cardboard, { z: -0.008, parent: g, static: false, cast: false });
  let tex = null;
  if (kind) {
    tex = photoTex(kind, seed);
    const ph = new THREE.Mesh(new THREE.PlaneGeometry(w - t * 2, h - t * 2), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.5 }));
    ph.position.z = 0.0; g.add(ph);
    if (!o.noGlass) { const gl = new THREE.Mesh(new THREE.PlaneGeometry(w - t * 2, h - t * 2), o.cracked ? M.glass : M.glass); gl.position.z = 0.006; gl.renderOrder = 2; g.add(gl); }
  }
  if (o.lean) g.rotation.x = -o.lean;
  g.userData.photo = tex;
  return g;
}
export { makeProp, pickable };
