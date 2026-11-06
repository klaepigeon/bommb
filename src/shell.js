// The building fabric: one painted skin per room face (with real holes for doors and
// windows), reveals, thresholds, skirting, the collapsed ceilings, wall collision, and the
// outside face of Building 14.
import * as THREE from 'three';
import { G, mat, box, solid, collider, staticBox, solidMat, texMat } from './core.js';
import { H, T, EXT, ROOMS, LINES, OPENINGS, lineById, inner, BALCONY, STOREY, GROUND, LANDING } from './plan.js';
import { paintWall, paintFloor, paintCeiling } from './surfaces.js';
import { Surface, underPlaster, blobPath, woodTex, rng } from './textures.js';

const shapeRect = (x0, y0, x1, y1) => { const p = new THREE.Path(); p.moveTo(x0, y0); p.lineTo(x1, y0); p.lineTo(x1, y1); p.lineTo(x0, y1); p.closePath(); return p; };

function faceMaterial(surface, extra = {}) {
  const t = surface.textures();
  const m = new THREE.MeshStandardMaterial({ map: t.map, bumpMap: t.bumpMap, bumpScale: 1.6, roughness: 0.92, ...extra });
  if (t.roughnessMap) { m.roughnessMap = t.roughnessMap; m.roughness = 1; }
  return m;
}

// flat polygon (in a local u,v frame) with holes -> mesh, uv = (u/W, v/Hh)
function holedPlane(W, Hh, holes, material, polyHoles = []) {
  const shape = new THREE.Shape(); shape.moveTo(0, 0); shape.lineTo(W, 0); shape.lineTo(W, Hh); shape.lineTo(0, Hh); shape.closePath();
  for (const h of holes) shape.holes.push(shapeRect(Math.max(0.001, h.u0), Math.max(0.001, h.y0), Math.min(W - 0.001, h.u1), Math.min(Hh - 0.001, h.y1)));
  for (const pts of polyHoles) { const p = new THREE.Path(); pts.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y))); p.closePath(); shape.holes.push(p); }
  const g = new THREE.ShapeGeometry(shape, 1);
  const pos = g.attributes.pos || g.attributes.position, uv = g.attributes.uv;
  for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / W, pos.getY(i) / Hh);
  const m = new THREE.Mesh(g, material);
  m.receiveShadow = true; m.castShadow = false;
  return m;
}

// jagged hole outline for a collapse, as [x,z] points
function jagged(cx, cz, rx, rz, seed) {
  const r = rng(seed), pts = [], n = 22;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2, k = 0.7 + r() * 0.45 + 0.15 * Math.sin(a * 3 + seed);
    pts.push([cx + Math.cos(a) * rx * k, cz + Math.sin(a) * rz * k]);
  }
  return pts;
}

export const CEILING_HOLES = {
  living: { pts: jagged(2.6, 3.9, 0.62, 0.5, 3), cx: 2.6, cz: 3.9 },
  bath: { pts: jagged(7.75, 6.3, 0.72, 0.55, 8), cx: 7.75, cz: 6.3 },
};
export const FLOOR_HOLES = {
  living: { pts: [[3.8, 0.25], [4.25, 0.22], [4.3, 0.55], [4.2, 0.74], [3.9, 0.7], [3.75, 0.5]], cx: 4.02, cz: 0.48 },
};

export function buildShell() {
  const scene = G.scene;
  const plasterTex = new Surface(1, 1, 128, 5).fill('#bdb4a0').noise(0.3, 0.6, 'multiply', 6, 5).grain(0.06).textures({ repeat: true });
  const revealMat = texMat('reveal', plasterTex, { roughness: 0.95 });

  // ---- room skins
  for (const [key, room] of Object.entries(ROOMS)) {
    const ir = inner(room), W = ir.x1 - ir.x0, D = ir.z1 - ir.z0;
    const sides = [
      { side: 'n', axis: 'z', c: room.z0, a0: ir.x0, a1: ir.x1, map: (a) => a - ir.x0, pos: [ir.x0, 0, ir.z0], ry: 0 },
      { side: 's', axis: 'z', c: room.z1, a0: ir.x0, a1: ir.x1, map: (a) => ir.x1 - a, pos: [ir.x1, 0, ir.z1], ry: Math.PI },
      { side: 'w', axis: 'x', c: room.x0, a0: ir.z0, a1: ir.z1, map: (a) => ir.z1 - a, pos: [ir.x0, 0, ir.z1], ry: Math.PI / 2 },
      { side: 'e', axis: 'x', c: room.x1, a0: ir.z0, a1: ir.z1, map: (a) => a - ir.z0, pos: [ir.x1, 0, ir.z0], ry: -Math.PI / 2 },
    ];
    for (const sd of sides) {
      const fw = sd.a1 - sd.a0;
      const holes = [];
      for (const o of OPENINGS) {
        const l = lineById[o.line];
        if (l.axis !== sd.axis || l.c !== sd.c) continue;
        if (o.a1 <= sd.a0 || o.a0 >= sd.a1) continue;
        const u0 = sd.map(o.a0), u1 = sd.map(o.a1);
        holes.push({ u0: Math.min(u0, u1), u1: Math.max(u0, u1), y0: o.y0, y1: o.y1, kind: o.kind, id: o.id });
      }
      const ext = (sd.axis === 'z' && (sd.c === 0 || sd.c === 8)) || (sd.axis === 'x' && (sd.c === 0 || sd.c === 10));
      const s = paintWall(key, sd.side, { W: fw, holes, ext });
      const m = holedPlane(fw, H, holes, faceMaterial(s));
      m.position.set(...sd.pos); m.rotation.y = sd.ry;
      m.name = `${key}-${sd.side}`;
      scene.add(m);
    }
    // floor
    const fs = paintFloor(key, W, D), fmat = faceMaterial(fs);
    const fh = FLOOR_HOLES[key] ? [FLOOR_HOLES[key].pts.map(([x, z]) => [x - ir.x0, -(z - ir.z0)])] : [];
    {
      const shape = new THREE.Shape(); shape.moveTo(0, 0); shape.lineTo(W, 0); shape.lineTo(W, -D); shape.lineTo(0, -D); shape.closePath();
      for (const pts of fh) { const p = new THREE.Path(); pts.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y))); p.closePath(); shape.holes.push(p); }
      const g = new THREE.ShapeGeometry(shape); const pos = g.attributes.position, uv = g.attributes.uv;
      for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / W, 1 + pos.getY(i) / D);
      const m = new THREE.Mesh(g, fmat); m.rotation.x = -Math.PI / 2; m.position.set(ir.x0, 0, ir.z0); m.receiveShadow = true; m.name = key + '-floor';
      scene.add(m);
    }
    // ceiling
    const cs = paintCeiling(key, W, D), cmat = faceMaterial(cs);
    {
      const shape = new THREE.Shape(); shape.moveTo(0, 0); shape.lineTo(W, 0); shape.lineTo(W, D); shape.lineTo(0, D); shape.closePath();
      const ch = CEILING_HOLES[key];
      if (ch) { const p = new THREE.Path(); ch.pts.forEach(([x, z], i) => (i ? p.lineTo(x - ir.x0, z - ir.z0) : p.moveTo(x - ir.x0, z - ir.z0))); p.closePath(); shape.holes.push(p); }
      const g = new THREE.ShapeGeometry(shape); const pos = g.attributes.position, uv = g.attributes.uv;
      for (let i = 0; i < pos.count; i++) uv.setXY(i, pos.getX(i) / W, 1 - pos.getY(i) / D);
      const m = new THREE.Mesh(g, cmat); m.rotation.x = Math.PI / 2; m.position.set(ir.x0, H, ir.z0); m.receiveShadow = true; m.name = key + '-ceiling';
      scene.add(m);
    }
    // skirting boards (not in the bathroom or box room)
    if (key !== 'bath' && key !== 'storage') {
      const sk = mat('skirt', { map: woodTex('#4a3626', 4, 1).map, roughness: 0.7, color: 0xb8a890 });
      for (const sd of sides) {
        // break the skirting at door openings
        let segs = [[sd.a0, sd.a1]];
        for (const o of OPENINGS) {
          const l = lineById[o.line]; if (l.axis !== sd.axis || l.c !== sd.c || o.y0 > 0) continue;
          segs = segs.flatMap(([a, b]) => (o.a1 <= a || o.a0 >= b) ? [[a, b]] : [[a, o.a0 - 0.07], [o.a1 + 0.07, b]].filter(([p, q]) => q - p > 0.05));
        }
        for (const [a, b] of segs) {
          const len = b - a, mid = (a + b) / 2, hgt = 0.085, th = 0.018;
          if (sd.axis === 'z') box(len, hgt, th, sk, { x: mid, y: 0, base: true, z: sd.side === 'n' ? ir.z0 + th / 2 : ir.z1 - th / 2, cast: false });
          else box(th, hgt, len, sk, { x: sd.side === 'w' ? ir.x0 + th / 2 : ir.x1 - th / 2, y: 0, base: true, z: mid, cast: false });
        }
      }
    }
  }

  // ---- reveals + thresholds
  for (const o of OPENINGS) {
    const l = lineById[o.line], depth = l.p1 - l.p0, mid = (l.p0 + l.p1) / 2;
    const isDoor = o.kind !== 'window';
    const h = o.y1 - o.y0, w = o.a1 - o.a0;
    const parts = [];
    // jambs
    parts.push({ along: o.a0, nrm: 1, y: o.y0 + h / 2, h });
    parts.push({ along: o.a1, nrm: -1, y: o.y0 + h / 2, h });
    for (const p of parts) {
      const pl = new THREE.Mesh(new THREE.PlaneGeometry(depth, p.h), revealMat);
      pl.receiveShadow = true;
      if (l.axis === 'z') { pl.position.set(p.along, p.y, mid); pl.rotation.y = p.nrm > 0 ? Math.PI / 2 : -Math.PI / 2; }
      else { pl.position.set(mid, p.y, p.along); pl.rotation.y = p.nrm > 0 ? 0 : Math.PI; }
      scene.add(pl);
    }
    // head
    const head = new THREE.Mesh(new THREE.PlaneGeometry(l.axis === 'z' ? w : depth, l.axis === 'z' ? depth : w), revealMat);
    head.rotation.x = Math.PI / 2; head.position.set(l.axis === 'z' ? (o.a0 + o.a1) / 2 : mid, o.y1, l.axis === 'z' ? mid : (o.a0 + o.a1) / 2); head.receiveShadow = true;
    scene.add(head);
    if (!isDoor || o.kind === 'balcony') {
      const sill = new THREE.Mesh(new THREE.PlaneGeometry(l.axis === 'z' ? w : depth, l.axis === 'z' ? depth : w), revealMat);
      sill.rotation.x = -Math.PI / 2; sill.position.set(l.axis === 'z' ? (o.a0 + o.a1) / 2 : mid, o.y0 + 0.001, l.axis === 'z' ? mid : (o.a0 + o.a1) / 2); sill.receiveShadow = true;
      scene.add(sill);
    }
    if (isDoor && o.kind !== 'balcony') { // threshold saddle
      const th = mat('threshold', { map: woodTex('#5a3f28', 6).map, roughness: 0.6 });
      if (l.axis === 'z') box(w, 0.015, depth + 0.02, th, { x: (o.a0 + o.a1) / 2, y: 0, base: true, z: mid, cast: false });
      else box(depth + 0.02, 0.015, w, th, { x: mid, y: 0, base: true, z: (o.a0 + o.a1) / 2, cast: false });
    }
  }

  // ---- wall collision and physics: every line minus its door gaps (windows stay solid)
  for (const l of LINES) {
    const gaps = OPENINGS.filter((o) => o.line === l.id && o.y0 === 0).map((o) => [o.a0, o.a1]).sort((a, b) => a[0] - b[0]);
    let a = l.a0; const segs = [];
    for (const [g0, g1] of gaps) { segs.push([a, g0]); a = g1; }
    segs.push([a, l.a1]);
    const mid = (l.p0 + l.p1) / 2, th = l.p1 - l.p0;
    for (const [s0, s1] of segs) {
      if (s1 - s0 < 0.01) continue;
      if (l.axis === 'z') solid((s0 + s1) / 2, -0.5, mid, s1 - s0, H + 1, th);
      else solid(mid, -0.5, (s0 + s1) / 2, th, H + 1, s1 - s0);
    }
    // lintels above doors (props only)
    for (const [g0, g1] of gaps) {
      if (l.axis === 'z') staticBox((g0 + g1) / 2, (2.05 + H) / 2, mid, g1 - g0, H - 2.05, th);
      else staticBox(mid, (2.05 + H) / 2, (g0 + g1) / 2, th, H - 2.05, g1 - g0);
    }
  }
  // solid wall cores: hidden behind the skins, but they fill the junctions and block light
  // (shadow maps) through the wall cavities. Shrunk a hair so they never z-fight the skins.
  const coreM = revealMat;
  for (const l of LINES) {
    const ops = OPENINGS.filter((o) => o.line === l.id).sort((a, b) => a.a0 - b.a0);
    const th = l.p1 - l.p0 - 0.006, mid = (l.p0 + l.p1) / 2;
    const piece = (a0, a1, y0, y1) => {
      if (a1 - a0 < 0.005 || y1 - y0 < 0.005) return;
      const m = l.axis === 'z' ? box(a1 - a0, y1 - y0, th, coreM, { x: (a0 + a1) / 2, y: y0, base: true, z: mid }) : box(th, y1 - y0, a1 - a0, coreM, { x: mid, y: y0, base: true, z: (a0 + a1) / 2 });
      m.receiveShadow = false;
    };
    let a = l.a0 + (l.ext ? 0 : 0.003);
    for (const o of ops) { piece(a, o.a0, 0, H); piece(o.a0, o.a1, o.y1, H); if (o.y0 > 0) piece(o.a0, o.a1, 0, o.y0); a = o.a1; }
    piece(a, l.a1 - (l.ext ? 0 : 0.003), 0, H);
  }

  // floor slab + ceiling for physics
  staticBox(5, -0.25, 4, 12, 0.5, 10);
  staticBox(5, H + 0.25, 4, 12, 0.5, 10);
  // floor hole: you won't step there
  { const f = FLOOR_HOLES.living; collider({ x: f.cx, z: f.cz, hx: 0.3, hz: 0.28, y0: -1, y1: 0.4 }); }

  buildCollapses();
  buildFacade();
}

// --------------------------------------------------------------------- collapses
function buildCollapses() {
  const scene = G.scene;
  const lath = mat('lath', { map: woodTex('#6a5a44', 8, 0.9).map, roughness: 0.95 });
  const joistM = mat('joist', { map: woodTex('#3e2c1c', 9, 0.8).map, roughness: 0.95 });
  const plasterChunk = solidMat('plasterChunk', 0xb8ae98, 0.95);
  const voidM = solidMat('void', 0x050404, 1);
  const edgeM = mat('plasterEdge', { color: 0x7a7262, roughness: 1 });
  const r = rng(77);

  for (const [key, ch] of Object.entries(CEILING_HOLES)) {
    // the void above: dark cavity with joists running across, then the floorboards of the flat upstairs
    const cx = ch.cx, cz = ch.cz;
    box(2.2, 0.02, 2.2, voidM, { x: cx, y: H + 0.42, z: cz, cast: false });
    for (const side of [[0, 1.1], [0, -1.1], [1.1, 0], [-1.1, 0]]) {
      box(side[0] ? 0.02 : 2.2, 0.45, side[0] ? 2.2 : 0.02, voidM, { x: cx + side[0], y: H + 0.2, z: cz + side[1], cast: false });
    }
    for (let k = -2; k <= 2; k++) box(0.08, 0.2, 2.2, joistM, { x: cx + k * 0.45 + 0.1, y: H + 0.12, z: cz });
    // boards of the floor above (some gaps: dark beyond)
    for (let k = -8; k <= 8; k++) if (r() > 0.15) box(2.2, 0.025, 0.12, joistM, { x: cx, y: H + 0.235, z: cz + k * 0.13, cast: false });
    // lath strips across the hole, some broken and hanging down
    const pts = ch.pts;
    for (let k = -6; k <= 6; k++) {
      const z = cz + k * 0.09;
      if (r() < 0.45) continue;
      const hang = r() < 0.4;
      const len = 0.3 + r() * 0.5, m = box(len, 0.008, 0.035, lath, { x: cx + (r() - 0.5) * 0.6, y: H + 0.015, z });
      if (hang) { m.rotation.z = (r() < 0.5 ? 1 : -1) * (0.5 + r() * 0.8); m.position.y -= len * 0.3; }
    }
    // a broken plaster lip around the edge: thick chunks
    for (let i = 0; i < pts.length; i++) {
      const [x, z] = pts[i], [x2, z2] = pts[(i + 1) % pts.length];
      const len = Math.hypot(x2 - x, z2 - z), ang = Math.atan2(z2 - z, x2 - x);
      const m = box(len + 0.03, 0.04 + r() * 0.05, 0.05 + r() * 0.04, edgeM, { x: (x + x2) / 2, y: H + 0.02 - r() * 0.02, z: (z + z2) / 2, cast: false });
      m.rotation.y = -ang; m.rotation.x = (r() - 0.5) * 0.4;
      if (r() < 0.25) { const hang = box(0.04 + r() * 0.08, 0.15 + r() * 0.25, 0.012, lath, { x: (x + x2) / 2, y: H - 0.1, z: (z + z2) / 2, cast: true }); hang.rotation.set((r() - 0.5) * 0.5, r() * 3, (r() - 0.5) * 0.5); }
    }
    // the fall: a heap of plaster slabs, lath and dust below
    const heap = new THREE.Group(); scene.add(heap);
    for (let i = 0; i < 46; i++) {
      const a = r() * 6.28, d = Math.pow(r(), 0.8) * 0.85, s = 0.04 + r() * 0.16 * (1 - d * 0.6);
      const geo = new THREE.DodecahedronGeometry(s, 0); const p = geo.attributes.position;
      for (let k = 0; k < p.count; k++) p.setY(k, p.getY(k) * (0.25 + r() * 0.2));
      geo.computeVertexNormals();
      const m = new THREE.Mesh(geo, i % 5 ? plasterChunk : edgeM); m.castShadow = true; m.receiveShadow = true;
      m.position.set(cx + Math.cos(a) * d, s * 0.2 * (1 - d) + 0.01 + (1 - d) * 0.06, cz + Math.sin(a) * d * 0.85);
      m.rotation.set(r() * 0.6, r() * 6, r() * 0.6); m.userData.static = true;
      heap.add(m);
    }
    for (let i = 0; i < 10; i++) {
      const m = box(0.5 + r() * 0.5, 0.008, 0.035, lath, { x: cx + (r() - 0.5) * 1.2, y: 0.03 + r() * 0.08, z: cz + (r() - 0.5) * 1.0, parent: heap });
      m.rotation.set((r() - 0.5) * 0.3, r() * 3, (r() - 0.5) * 0.3);
    }
    // the heap's a low obstacle
    collider({ x: cx, z: cz, hx: 0.32, hz: 0.27, y0: 0, y1: 0.25, heap: true });
    // a little grey light from the flat above, where its own window is out
    if (key === 'living') { const l = new THREE.PointLight(0x8a96a8, 0.9, 3.5, 2); l.position.set(cx + 0.3, H + 0.3, cz - 0.2); G.scene.add(l); }
    staticBox(cx, 0.05, cz, 0.7, 0.1, 0.56);
    void key;
  }

  // floor hole in the living room: rotten boards gone, the joists and the dark below
  const f = FLOOR_HOLES.living;
  box(0.7, 0.02, 0.7, voidM, { x: f.cx, y: -0.5, z: f.cz, cast: false });
  for (const [dx, dz, w, d] of [[0.32, 0, 0.02, 0.7], [-0.32, 0, 0.02, 0.7], [0, 0.32, 0.66, 0.02], [0, -0.32, 0.66, 0.02]]) box(w, 0.5, d, voidM, { x: f.cx + dx, y: -0.25, z: f.cz + dz, cast: false });
  for (let k = -1; k <= 1; k += 2) box(0.07, 0.18, 0.62, joistM, { x: f.cx + k * 0.18, y: -0.1, z: f.cz });
  // splintered board ends sticking into the gap
  for (let i = 0; i < 4; i++) { const m = box(0.22, 0.02, 0.07, mat('rotboard', { map: woodTex('#4a3220', 12, 0.7).map, roughness: 1 }), { x: f.cx - 0.15 + i * 0.12, y: -0.03, z: f.cz - 0.25 + (i % 2) * 0.5 }); m.rotation.set(0.2 * (i % 2 ? 1 : -1), 0.4 * i, 0.15); }
}

// --------------------------------------------------------------------- facade of Building 14 (our side)
function buildFacade() {
  const scene = G.scene;
  const top = 6 * STOREY - 0.3, bot = GROUND;
  const x0 = -24, x1 = 34, W = x1 - x0, Hh = top - bot;
  const s = new Surface(W, Hh, 20, 444);
  // stucco over brick, the render coming away in islands; grime streaks under every sill
  s.fill('#9c8a74').noise(0.35, 2.5, 'multiply', 10, 5).noise(0.25, 0.8, 'overlay', 4, 6).grain(0.08);
  const g = s.g;
  const fx = (x) => s.px(x - x0), fy = (y) => s.Y(y - bot);
  for (let i = 0; i < 70; i++) s.peel(s.r() * W, s.r() * Hh, 1 + s.r() * 3, 0.6 + s.r() * 1.6, underPlaster('#7b4a36'), false);
  // storey bands
  for (let f = -3; f <= 6; f++) { const y = f * STOREY - 0.2; g.fillStyle = 'rgba(60,50,40,0.35)'; g.fillRect(0, fy(y + 0.12), s.W, s.px(0.24)); }
  const winsX = [[0.75, 2.55], [2.8, 3.55], [5.25, 6.75], [8.25, 9.45]];
  const modules = [-21.68, -10.84, 0, 10.84, 21.68];
  const rr = rng(4);
  for (let f = -3; f <= 5; f++) for (const mx of modules) for (const [a0, a1] of winsX) {
    const y0 = f * STOREY + (a0 === 2.8 ? 0 : 0.85), y1 = f * STOREY + 2.35, X0 = mx + a0, X1 = mx + a1;
    if (f === 0 && mx === 0) continue; // ours are real holes
    if (f === -3 && a0 === 2.8) continue; // ground floor: no balcony door
    const kind = rr();
    g.fillStyle = kind < 0.12 ? '#3c2f22' : kind < 0.3 ? '#050505' : '#1b2024';
    g.fillRect(fx(X0), fy(y1), s.px(X1 - X0), s.px(y1 - y0));
    if (kind >= 0.3) { // frame + mullion + a hint of sky reflection
      g.strokeStyle = '#d8d2c2'; g.lineWidth = 2; g.strokeRect(fx(X0) + 1, fy(y1) + 1, s.px(X1 - X0) - 2, s.px(y1 - y0) - 2);
      g.fillStyle = '#d8d2c2'; g.fillRect(fx((X0 + X1) / 2) - 1, fy(y1), 2, s.px(y1 - y0));
      const grd = g.createLinearGradient(0, fy(y1), 0, fy(y0)); grd.addColorStop(0, 'rgba(140,150,160,0.25)'); grd.addColorStop(1, 'rgba(140,150,160,0.02)');
      g.fillStyle = grd; g.fillRect(fx(X0) + 2, fy(y1) + 2, s.px(X1 - X0) - 4, s.px(y1 - y0) - 4);
      if (rr() < 0.3) { g.fillStyle = 'rgba(150,130,100,0.5)'; g.fillRect(fx(X0) + 2, fy(y1) + 2, s.px((X1 - X0) * 0.4), s.px(y1 - y0) - 4); } // a curtain
    } else if (kind < 0.12) { // boarded
      for (let b = 0; b < 4; b++) { g.fillStyle = `rgb(${90 + rr() * 30},${70 + rr() * 20},50)`; g.fillRect(fx(X0) - 2, fy(y1) + b * s.px(0.4) + 3, s.px(X1 - X0) + 4, s.px(0.2)); }
    }
    // grime streak under the sill
    const grd = g.createLinearGradient(0, fy(y0), 0, fy(y0 - 1.6)); grd.addColorStop(0, 'rgba(30,24,18,0.45)'); grd.addColorStop(1, 'rgba(30,24,18,0)');
    g.fillStyle = grd; g.fillRect(fx(X0) + 2, fy(y0), s.px(X1 - X0) - 4, s.px(1.6));
    g.fillStyle = '#6a6660'; g.fillRect(fx(X0) - 3, fy(y0) - 1, s.px(X1 - X0) + 6, 3); // tin sill
  }
  s.rising(4, [30, 26, 22], 0.5);
  const fm = faceMaterial(s, { roughness: 0.95 });
  // our four openings
  const holes = OPENINGS.filter((o) => o.line === 'n').map((o) => ({ u0: o.a0 - x0, u1: o.a1 - x0, y0: o.y0 - bot, y1: o.y1 - bot }));
  const m = holedPlane(W, Hh, holes, fm);
  m.rotation.y = Math.PI; m.position.set(x1, bot, -EXT);
  // ShapeGeometry is in local +x; rotated by PI it runs toward -x, so flip u: rebuild with mirrored holes
  scene.remove(m);
  const holesM = holes.map((h) => ({ ...h, u0: W - h.u1, u1: W - h.u0 }));
  const m2 = holedPlane(W, Hh, holesM, fm);
  const uv = m2.geometry.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setX(i, 1 - uv.getX(i));
  m2.rotation.y = Math.PI; m2.position.set(x1, bot, -EXT); m2.name = 'facade'; m2.userData.outdoor = true;
  scene.add(m2);

  // balconies of every flat on this face (ours is built properly in exterior.js)
  const slab = solidMat('balSlab', 0x7d776c, 0.95), rail = solidMat('rail', 0x3a3430, 0.6, 0.6);
  const slabs = [], rails = [];
  for (let f = -2; f <= 5; f++) for (const mx of modules) {
    if (f === 0 && mx === 0) continue;
    slabs.push([mx + (BALCONY.x0 + BALCONY.x1) / 2, f * STOREY + BALCONY.y - 0.08, (BALCONY.z0 + BALCONY.z1) / 2 - 0.05]);
    rails.push([mx + (BALCONY.x0 + BALCONY.x1) / 2, f * STOREY + BALCONY.y + 0.5, BALCONY.z0 + 0.02]);
  }
  const bw = BALCONY.x1 - BALCONY.x0 + 0.1, bd = BALCONY.z1 - BALCONY.z0 + 0.1;
  const slabI = new THREE.InstancedMesh(new THREE.BoxGeometry(bw, 0.16, bd), slab, slabs.length);
  const railI = new THREE.InstancedMesh(new THREE.BoxGeometry(bw, 1.0, 0.03), mat('railPanel', { color: 0x4d443c, roughness: 0.8, metalness: 0.3 }), rails.length);
  const mm = new THREE.Matrix4();
  slabs.forEach((p, i) => { mm.makeTranslation(...p); slabI.setMatrixAt(i, mm); });
  rails.forEach((p, i) => { mm.makeTranslation(...p); railI.setMatrixAt(i, mm); });
  slabI.castShadow = slabI.receiveShadow = true; railI.castShadow = railI.receiveShadow = true;
  scene.add(slabI, railI); slabI.userData.outdoor = railI.userData.outdoor = true;
  void rail;
  // the roof parapet and the plinth
  box(W, 0.6, 0.6, slab, { x: (x0 + x1) / 2, y: top, base: true, z: -EXT - 0.1, cast: false });
  void LANDING;
}
