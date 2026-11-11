// A generic builder for a set of rooms on any floor: the same construction as Flat 47's
// shell (one skin per room face with real holes, wall cores, collision, floors and
// ceilings) but driven by a plan passed in, at any height, inside its own group so the
// whole thing can be hidden when you're nowhere near it.
import * as THREE from 'three';
import { G, box, collider, staticBox, floorRegion, zone } from './core.js';
import { T, LINES, OPENINGS, lineById, openById } from './plan.js';
import { holedPlane } from './shell.js';

// the finished face of a room side: on its line's inner face if there's a line, else the nominal edge
function faceCoord(def, room, side) {
  const axis = side === 'n' || side === 's' ? 'z' : 'x';
  const c = side === 'n' ? room.z0 : side === 's' ? room.z1 : side === 'w' ? room.x0 : room.x1;
  const l = def.lines.find((q) => q.axis === axis && Math.abs(q.c - c) < 1e-6 && (axis === 'z' ? q.a0 < room.x1 && q.a1 > room.x0 : q.a0 < room.z1 && q.a1 > room.z0));
  if (!l) return { c, at: c, line: null };
  const at = side === 'n' || side === 'w' ? Math.max(l.p0, l.p1) : Math.min(l.p0, l.p1);
  return { c, at, line: l };
}

// mirror a 47-style plan across x = m (so 48 is 47 seen in a mirror)
export function mirrorPlan(rooms, lines, openings, m, prefix) {
  const R = {}, X = (x) => m - x;
  for (const [k, r] of Object.entries(rooms)) R[k] = { ...r, x0: X(r.x1), x1: X(r.x0) };
  const L = lines.map((l) => (l.axis === 'x' ? { ...l, id: prefix + l.id, c: X(l.c), p0: X(l.p1), p1: X(l.p0) } : { ...l, id: prefix + l.id, a0: X(l.a1), a1: X(l.a0) }));
  const O = openings.map((o) => { const l = lines.find((q) => q.id === o.line); return l.axis === 'z' ? { ...o, id: prefix + o.id, line: prefix + o.line, a0: X(o.a1), a1: X(o.a0) } : { ...o, id: prefix + o.id, line: prefix + o.line }; });
  return { rooms: R, lines: L, openings: O };
}
export function offsetPlan(rooms, lines, openings, prefix) {
  return { rooms: { ...rooms }, lines: lines.map((l) => ({ ...l, id: prefix + l.id })), openings: openings.map((o) => ({ ...o, id: prefix + o.id, line: prefix + o.line })) };
}

// def: { key, name, oy, H, rooms, lines, openings, paint(room, side, face) -> material,
//        floor(room, W, D) -> material, ceil(room, W, D) -> material, floorHoles, ceilHoles,
//        omit: { room: ['n', ...] }, noLines: [ids], core: material, names: { room: 'Kitchen' } }
export function buildZone(def) {
  const group = new THREE.Group(); group.userData.zone = def.key; group.userData.noBake = true; G.scene.add(group);
  const oy = def.oy, Hh = def.H;
  def.group = group;
  // make the plan visible to the door builder (openings.js)
  for (const l of def.lines) { if (!lineById[l.id]) { LINES.push(l); lineById[l.id] = l; } }
  for (const o of def.openings) { o.oy = oy; o.parent = group; if (!openById[o.id]) { OPENINGS.push(o); openById[o.id] = o; } }
  const skins = [];
  let bx0 = Infinity, bx1 = -Infinity, bz0 = Infinity, bz1 = -Infinity;
  for (const [key, room] of Object.entries(def.rooms)) {
    const fn = faceCoord(def, room, 'n').at, fs = faceCoord(def, room, 's').at, fw = faceCoord(def, room, 'w').at, fe = faceCoord(def, room, 'e').at;
    const ir = { x0: fw, x1: fe, z0: fn, z1: fs }, W = ir.x1 - ir.x0, D = ir.z1 - ir.z0;
    bx0 = Math.min(bx0, room.x0); bx1 = Math.max(bx1, room.x1); bz0 = Math.min(bz0, room.z0); bz1 = Math.max(bz1, room.z1);
    const sides = [
      { side: 'n', axis: 'z', c: room.z0, a0: ir.x0, a1: ir.x1, map: (a) => a - ir.x0, pos: [ir.x0, oy, ir.z0], ry: 0 },
      { side: 's', axis: 'z', c: room.z1, a0: ir.x0, a1: ir.x1, map: (a) => ir.x1 - a, pos: [ir.x1, oy, ir.z1], ry: Math.PI },
      { side: 'w', axis: 'x', c: room.x0, a0: ir.z0, a1: ir.z1, map: (a) => ir.z1 - a, pos: [ir.x0, oy, ir.z1], ry: Math.PI / 2 },
      { side: 'e', axis: 'x', c: room.x1, a0: ir.z0, a1: ir.z1, map: (a) => a - ir.z0, pos: [ir.x1, oy, ir.z0], ry: -Math.PI / 2 },
    ];
    for (const sd of sides) {
      if (def.omit?.[key]?.includes(sd.side)) continue;
      const fw2 = sd.a1 - sd.a0, holes = [];
      for (const o of def.openings) {
        const l = def.lines.find((q) => q.id === o.line);
        if (!l || l.axis !== sd.axis || Math.abs(l.c - sd.c) > 1e-6 || o.a1 <= sd.a0 || o.a0 >= sd.a1) continue;
        const u0 = sd.map(o.a0), u1 = sd.map(o.a1);
        holes.push({ u0: Math.min(u0, u1), u1: Math.max(u0, u1), y0: o.y0, y1: o.y1, kind: o.kind, id: o.id });
      }
      const m = holedPlane(fw2, Hh, holes, def.paint(key, sd.side, { W: fw2, holes, ext: !!faceCoord(def, room, sd.side).line?.ext }));
      if (def.uvTile) { const uv = m.geometry.attributes.uv, pp = m.geometry.attributes.position; for (let i = 0; i < uv.count; i++) uv.setXY(i, pp.getX(i) / def.uvTile, pp.getY(i) / Hh); }
      m.position.set(...sd.pos); m.rotation.y = sd.ry; m.castShadow = true; m.userData.blocker = true; m.name = `${def.key}:${key}-${sd.side}`;
      group.add(m); skins.push(m);
    }
    const mkFlat = (mat, y, up, holesPts) => {
      const shape = new THREE.Shape(); shape.moveTo(0, 0); shape.lineTo(W, 0); shape.lineTo(W, D); shape.lineTo(0, D); shape.closePath();
      for (const pts of holesPts || []) { const p = new THREE.Path(); pts.forEach(([x, z], i) => (i ? p.lineTo(x - ir.x0, z - ir.z0) : p.moveTo(x - ir.x0, z - ir.z0))); p.closePath(); shape.holes.push(p); }
      const g = new THREE.ShapeGeometry(shape); const pos = g.attributes.position, uv = g.attributes.uv;
      for (let i = 0; i < pos.count; i++) uv.setXY(i, def.uvTile ? (pos.getX(i) + ir.x0) / def.uvTile : pos.getX(i) / W, def.uvTile ? (pos.getY(i) + ir.z0) / def.uvTile : 1 - pos.getY(i) / D);
      if (up) { // rotate so the shape's +y runs along +z and the face points up
        const m = new THREE.Mesh(g, mat); m.rotation.x = Math.PI / 2; m.position.set(ir.x0, y, ir.z0);
        m.material.side = THREE.DoubleSide; return m;
      }
      const m = new THREE.Mesh(g, mat); m.rotation.x = Math.PI / 2; m.position.set(ir.x0, y, ir.z0); return m;
    };
    if (def.floor) { const f = mkFlat(def.floor(key, W, D), oy, true, def.floorHoles?.[key]); f.receiveShadow = true; f.name = `${def.key}:${key}-floor`; group.add(f); }
    if (def.ceil) { const c = mkFlat(def.ceil(key, W, D), oy + Hh, false, def.ceilHoles?.[key]); c.receiveShadow = true; c.castShadow = true; c.userData.blocker = true; c.name = `${def.key}:${key}-ceiling`; group.add(c); skins.push(c); }
    zone({ key: `${def.key}:${key}`, name: def.names?.[key] || room.name || def.name, x0: ir.x0 - 0.05, x1: ir.x1 + 0.05, z0: ir.z0 - 0.05, z1: ir.z1 + 0.05, y0: oy - 0.3, y1: oy + Hh, group, def });
  }
  // walls: cores (shadows, junctions), collision and physics, minus door gaps
  const coreM = def.core;
  for (const l of def.lines) {
    if (def.noLines?.includes(l.id)) continue;
    const ops = def.openings.filter((o) => o.line === l.id).sort((a, b) => a.a0 - b.a0);
    const th = l.p1 - l.p0, mid = (l.p0 + l.p1) / 2;
    const piece = (a0, a1, y0, y1) => {
      if (a1 - a0 < 0.005 || y1 - y0 < 0.005 || !coreM) return;
      const m = l.axis === 'z' ? box(a1 - a0, y1 - y0, th - 0.006, coreM, { x: (a0 + a1) / 2, y: oy + y0, base: true, z: mid, parent: group }) : box(th - 0.006, y1 - y0, a1 - a0, coreM, { x: mid, y: oy + y0, base: true, z: (a0 + a1) / 2, parent: group });
      m.receiveShadow = false;
    };
    let a = l.a0;
    for (const o of ops) { piece(a + 0.003, o.a0, 0, Hh); piece(o.a0, o.a1, o.y1, Hh); if (o.y0 > 0) piece(o.a0, o.a1, 0, o.y0); a = o.a1; }
    piece(a, l.a1 - 0.003, 0, Hh);
    // collision: door gaps open, windows solid
    const gaps = ops.filter((o) => o.y0 === 0).map((o) => [o.a0, o.a1]);
    let s = l.a0; const segs = [];
    for (const [g0, g1] of gaps) { segs.push([s, g0]); s = g1; }
    segs.push([s, l.a1]);
    for (const [s0, s1] of segs) {
      if (s1 - s0 < 0.01) continue;
      if (l.axis === 'z') { collider({ x: (s0 + s1) / 2, z: mid, hx: (s1 - s0) / 2, hz: th / 2, y0: oy - 0.4, y1: oy + Hh + 0.3 }); staticBox((s0 + s1) / 2, oy + Hh / 2, mid, s1 - s0, Hh, th); }
      else { collider({ x: mid, z: (s0 + s1) / 2, hx: th / 2, hz: (s1 - s0) / 2, y0: oy - 0.4, y1: oy + Hh + 0.3 }); staticBox(mid, oy + Hh / 2, (s0 + s1) / 2, th, Hh, s1 - s0); }
    }
  }
  // floor for walking and for props
  // pad by a wall's thickness so the door thresholds are floor too
  const fr = def.floorRect || { x0: bx0 - 0.45, x1: bx1 + 0.45, z0: bz0 - 0.45, z1: bz1 + 0.45 };
  floorRegion({ ...fr, y: oy, zone: def.key });
  if (!def.noSlab) { staticBox((fr.x0 + fr.x1) / 2, oy - 0.2, (fr.z0 + fr.z1) / 2, fr.x1 - fr.x0, 0.4, fr.z1 - fr.z0); staticBox((fr.x0 + fr.x1) / 2, oy + Hh + 0.2, (fr.z0 + fr.z1) / 2, fr.x1 - fr.x0, 0.4, fr.z1 - fr.z0); }
  G.zoneSkins = (G.zoneSkins || []).concat(skins);
  void T;
  return group;
}
