// The other flats you can get into.
//   48 (across the landing): the Sokolovs' flat as a draft — reality's sketch of it, grey,
//      labelled in pencil, with three shapes standing in it that have the family's names.
//   51 (upstairs): the flat from the note, empty, never lived in, and past its living room
//      the building simply stops.
//   44 (downstairs): a corridor that is longer than the building, and then longer.
import * as THREE from 'three';
import { G, mat, box, cyl, group, collider, staticBox, interactive, onUpdate, floorRegion, zone, sphere } from './core.js';
import { ROOMS, LINES, OPENINGS, STOREY, floorY, H } from './plan.js';
import { buildZone, mirrorPlan, offsetPlan } from './zone.js';
import { faceMaterial } from './shell.js';
import { makeDoor, paddedDoorSurface, panelDoorSurface, DOORS } from './openings.js';
import { paintEcho, paintEchoFloor, paintDraft, paintCeiling } from './surfaces.js';
import { CEILING_HOLES } from './shell.js';
import { Surface, rng, canvas, metalTex, woodTex } from './textures.js';
import { M, rbox, makeProp } from './furniture.js';
import { fixture } from './building.js';
import { sfx, knockSeq } from './audio.js';
import { canvasTex, examine, sheet, chair } from './dress.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
// the Sokolovs' plan as it was drawn, before anything else was added to the arrays
const L47 = LINES.slice(0, 10), O47 = OPENINGS.slice(0, 12);

export function buildFlats() {
  flat48();
  flat51();
  flat44();
}

// ================================================================== 48: the draft
const LABELS = { living: 'living room', bedroom: 'bedroom', kitchen: 'kitchen', hall: 'hall', storage: 'box room?', child: "Sonya's", bath: 'bath + wc' };
function flat48() {
  const MX = 24.42; // mirror line: 47's east wall (x = 10) lands on the stairwell's east wall (x = 14.42)
  const p = mirrorPlan(ROOMS, L47, O47, MX, 'f48');
  const plain = mat('draftPlain', { color: 0xd8d6cf, roughness: 1, emissive: 0xd8d6cf, emissiveIntensity: 0.16 });
  const def = {
    key: 'f48', name: 'Flat 48', oy: 0, H, ...p,
    paint: (room, side, face) => { const m = faceMaterial(paintDraft(room, side, face, LABELS[room]), { roughness: 1 }); m.emissive = new THREE.Color(0xffffff); m.emissiveMap = m.map; m.emissiveIntensity = 0.16; return m; },
    floor: () => mat('draftFloor', { color: 0xb4b2ab, roughness: 1, emissive: 0xb4b2ab, emissiveIntensity: 0.12 }),
    ceil: () => plain, core: plain,
    names: Object.fromEntries(Object.keys(ROOMS).map((k) => [k, 'Flat 48'])),
  };
  const grp = buildZone(def);
  for (const z of G.zones) if (z.key.startsWith('f48')) { z.surface = 'concrete'; z.sky = 0; z.flat = 48; }
  // the door from the landing: the only finished thing in it
  makeDoor({ id: 'f48dEntry', hinge: 'a0', swing: 1, open: 0.55, max: 1.4, surface: paddedDoorSurface(0.83, 2.07, 4848, '48', '#3a2a2e'), thick: 0.07, plane: 14.27,
    locked: { prompt: () => (G.flags.f48 ? 'Open' : 'Try the door'), use: () => { if (!G.flags.f48) { G.flags.f48 = true; G.ui.toast('It isn’t locked. It was never locked.'); } return false; } } });
  G.door48 = DOORS.f48dEntry;
  // windows and the balcony door: overexposed, white, nothing to see
  const glow = mat('draftWindow', { color: 0xffffff, emissive: 0xfafaf4, emissiveIntensity: 1.6, roughness: 1 });
  for (const o of p.openings) {
    if (o.kind !== 'window' && o.kind !== 'balcony') continue;
    const l = p.lines.find((q) => q.id === o.line), mid = (l.p0 + l.p1) / 2;
    const pl = new THREE.Mesh(new THREE.PlaneGeometry(o.a1 - o.a0, o.y1 - o.y0), glow); pl.position.set((o.a0 + o.a1) / 2, (o.y0 + o.y1) / 2, mid); if (l.c > 4) pl.rotation.y = Math.PI; grp.add(pl);
    fixture({ pos: V((o.a0 + o.a1) / 2, 1.6, l.c > 4 ? mid - 0.6 : mid + 0.6), k: 3.5, color: 0xf4f6ff, flicker: 'steady', range: 6, when: () => P48() });
    if (o.y0 === 0) collider({ x: (o.a0 + o.a1) / 2, z: mid, hx: (o.a1 - o.a0) / 2, hz: 0.2, y0: -0.4, y1: 3 });
  }
  // furniture as it would be if you only half remembered it: grey blocks with paper tags
  const X = (x) => MX - x;
  const block = (x, z, w, d, h, label, desc) => {
    const m = box(w, h, d, plain, { x: X(x), y: 0, base: true, z, parent: grp, static: false });
    collider({ x: X(x), z, hx: w / 2, hz: d / 2, y0: 0, y1: h }); staticBox(X(x), h / 2, z, w, h, d);
    const t = tag(label); t.position.set(X(x), h + 0.002, z); t.rotation.set(-Math.PI / 2, 0, (Math.random() - 0.5) * 0.6); grp.add(t);
    examine([m, t], label, desc || `A shape the size of a ${label.toLowerCase()}. A paper tag on it in pencil: "${label}".`);
    return m;
  };
  block(0.45, 2.4, 0.85, 2.0, 0.6, 'SOFA', 'The size of their sofa, exactly. On the tag, in a different pencil: "the green one with the burn".');
  block(1.62, 2.6, 0.46, 0.9, 0.45, 'TABLE (small)');
  block(2.4, 1.35, 0.78, 1.1, 0.76, 'TABLE', 'On top, three pale circles where plates would go.');
  block(4.1, 2.1, 0.45, 2.4, 2.2, 'WALL UNIT', 'Its tag: "WALL UNIT (the good glasses, TV, the doll)". Someone is making a list.');
  block(5.47, 1.85, 2.0, 1.55, 0.6, 'BED');
  block(7.23, 0.9, 0.6, 1.2, 2.0, 'WARDROBE');
  block(9.7, 1.6, 0.6, 2.6, 0.9, 'KITCHEN');
  block(9.68, 3.37, 0.6, 0.6, 1.5, 'FRIDGE', 'The tag says FRIDGE, and under it: "note on the door — what did it say?"');
  block(3.28, 7.05, 0.82, 1.85, 0.45, "SONYA'S BED", 'Smaller. The tag has been rubbed out and written again several times.');
  block(7.35, 7.62, 1.7, 0.76, 0.55, 'BATH');
  // three of them. Facing the walls. Do not look away for long.
  figure(grp, X(9.2), 2.65, 1.72, 'MAMA', 'At the stove. The tag is pinned where a heart would be: "MAMA — Marta — hair up, the blue cardigan".');
  figure(grp, X(6.0), 0.55, 1.84, 'PAPA', 'At the bedroom window, looking out at the white. The tag: "PAPA — nights — the jacket".');
  figure(grp, X(3.3), 6.3, 1.22, 'SONYA', 'By the small bed. The tag: "SONYA (7) — 8 on the 22nd". It is the only one whose tag has a drawing on it: a house with black windows.');
  // 48 has its own hum and no echo at all
  zoneHum(V(X(5), 1.5, 4), 'f48');
}
const P48 = () => String(G.playerZone || '').startsWith('f48') || (G.playerPos && G.playerPos.x > 12 && G.playerPos.x < 16 && Math.abs(G.playerPos.y) < 2);
function tag(text) {
  const c = canvas(128, 64), g = c.getContext('2d'); g.fillStyle = '#ece6d2'; g.fillRect(0, 0, 128, 64); g.fillStyle = 'rgba(40,40,50,0.85)'; g.font = '20px "Segoe Print","Bradley Hand",cursive'; g.textAlign = 'center'; g.fillText(text, 64, 40);
  return new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.08), new THREE.MeshStandardMaterial({ map: canvasTex(c), roughness: 1, side: THREE.DoubleSide }));
}
// a grey standing shape. When it isn't on screen it turns a little toward you.
function figure(grp, x, z, h, name, desc) {
  const m = mat('draftPlain', {});
  const g = group({ x, y: 0, z, parent: grp });
  rbox(h * 0.24, h * 0.62, h * 0.15, 0.06, m, { y: h * 0.18, base: true, parent: g, static: false });
  rbox(h * 0.14, h * 0.14, h * 0.14, 0.05, m, { y: h * 0.82, base: true, parent: g, static: false });
  for (const s of [-1, 1]) rbox(h * 0.08, h * 0.2, h * 0.08, 0.03, m, { x: s * h * 0.06, y: 0, base: true, parent: g, static: false });
  const t = tag(name); t.position.set(0, h * 0.62, h * 0.08); g.add(t);
  collider({ x, z, hx: h * 0.13, hz: h * 0.1, y0: 0, y1: h });
  // start facing away from the room's middle
  g.rotation.y = Math.atan2(x - 19.5, z - 4) ;
  examine(g.children, name, desc);
  const fr = new THREE.Frustum(), pm = new THREE.Matrix4(), wp = new THREE.Vector3();
  onUpdate((dt) => {
    if (!P48()) return;
    const cam = G.camera; pm.multiplyMatrices(cam.projectionMatrix, cam.matrixWorldInverse); fr.setFromProjectionMatrix(pm);
    g.getWorldPosition(wp); wp.y += h * 0.5;
    if (fr.containsPoint(wp)) return;
    const want = Math.atan2(cam.position.x - x, cam.position.z - z), d = Math.atan2(Math.sin(want - g.rotation.y), Math.cos(want - g.rotation.y));
    if (Math.abs(d) > 0.02) { g.rotation.y += Math.sign(d) * Math.min(Math.abs(d), dt * 0.25); if (!g.userData.moved) { g.userData.moved = true; } }
  });
}

// ================================================================== 51: the echo, and where it stops
function flat51() {
  const oy = STOREY, p = offsetPlan(ROOMS, L47, O47, 'f51');
  const holes = { living: [CEILING_HOLES.living.pts], bath: [CEILING_HOLES.bath.pts] };
  const def = {
    key: 'f51', name: 'Flat 51', oy, H, ...p,
    paint: (room, side, face) => faceMaterial(paintEcho(room, side, face)),
    floor: (room, W, D) => faceMaterial(paintEchoFloor(room, W, D)),
    ceil: (room, W, D) => faceMaterial(paintCeiling(room, W, D)),
    core: mat('reveal', {}),
    floorHoles: holes,
    // the north wall isn't there. Past the living room, bedroom and kitchen: nothing.
    omit: { living: ['n'], bedroom: ['n'], kitchen: ['n'] }, noLines: ['f51n'],
    names: { living: 'Flat 51', bedroom: 'Flat 51', kitchen: 'Flat 51', hall: 'Flat 51', child: 'Flat 51', bath: 'Flat 51', storage: 'Flat 51' },
  };
  const grp = buildZone(def);
  for (const z of G.zones) if (z.key.startsWith('f51')) { z.surface = { living: 'wood', bedroom: 'wood', child: 'wood', kitchen: 'lino', hall: 'lino', bath: 'tile', storage: 'concrete' }[z.key.split(':')[1]]; z.sky = 0; z.dust = true; }
  // the holes in the floor, over 47's: rims you won't step over
  for (const ch of Object.values(CEILING_HOLES)) collider({ x: ch.cx, z: ch.cz, hx: 0.55, hz: 0.45, y0: oy - 0.3, y1: oy + 0.4 });
  // the door is open, as the note said
  makeDoor({ id: 'f51dEntry', hinge: 'a0', swing: -1, open: 1.35, max: 1.5, surface: paddedDoorSurface(0.83, 2.07, 5151, '51', '#2e2a24'), thick: 0.07, plane: 10.06 });
  makeDoor({ id: 'f51dLiving', hinge: 'a1', swing: -1, open: 1.5, max: 1.55, color: '#d8d0bc', seed: 51 });
  makeDoor({ id: 'f51dChild', hinge: 'a0', swing: 1, open: 0, max: 1.5, color: '#d8d0bc', seed: 52 });
  makeDoor({ id: 'f51dBath', hinge: 'a1', swing: 1, open: 1.2, max: 1.45, color: '#d8d0bc', seed: 53 });
  makeDoor({ id: 'f51dBed', hinge: 'a1', swing: -1, open: 1.4, max: 1.6, color: '#d8d0bc', seed: 54 });
  makeDoor({ id: 'f51dStore', hinge: 'a1', swing: 1, open: 0.3, max: 1.45, color: '#d8d0bc', seed: 55 });
  // one bulb in the hall, nothing else
  const bulb = sphere(0.035, mat('bulb51', { color: 0xfff0d0, emissive: 0xfff0d0, emissiveIntensity: 0 }), { x: 7.3, y: oy + H - 0.54, z: 4.5, parent: grp, static: false });
  cyl(0.004, 0.004, 0.5, 4, M.black, { x: 7.3, y: oy + H - 0.25, z: 4.5, parent: grp });
  fixture({ pos: V(7.3, oy + H - 0.6, 4.5), mesh: bulb, k: 3, color: 0xfff0d0, flicker: 'bulb' });
  // a chair in the living room, facing where the wall should be
  const c = chair(2.2, 1.6, 0, false); c.mesh.position.y += oy; c.body.position.y += oy; c.body.wakeUp();
  // his footprints: in from the landing, down the hall, through the living room, and on
  const prints = [];
  const path = [[9.8, 4.55], [7.0, 4.6], [4.6, 4.6], [3.6, 3.8], [3.2, 2.0], [3.0, 0.2], [2.8, -4], [2.5, -12], [2.0, -22]];
  for (let i = 0; i < path.length - 1; i++) {
    const [ax, az] = path[i], [bx, bz] = path[i + 1], len = Math.hypot(bx - ax, bz - az), n = Math.floor(len / 0.36);
    for (let k = 0; k < n; k++) { const t = k / n; prints.push([ax + (bx - ax) * t + ((k % 2) - 0.5) * 0.18 * Math.cos(Math.atan2(bz - az, bx - ax)), az + (bz - az) * t - ((k % 2) - 0.5) * 0.18 * Math.sin(Math.atan2(bz - az, bx - ax)), Math.atan2(bx - ax, bz - az)]); }
  }
  footprintMesh(prints, oy, grp, 0x6a6458);
  // the void beyond: a floor that goes on into the dark, and things standing in it
  voidBeyond(oy);
  // your own footprints in the dust
  const mine = []; let mesh = null;
  G.onStep = (pos, yaw) => {
    if (!(G.playerZone && (G.playerZone.startsWith('f51') || G.playerZone === 'void'))) return;
    mine.push([pos.x, pos.z, yaw]); if (mine.length > 300) mine.shift();
    if (mesh) { grp.remove(mesh); mesh.geometry.dispose(); }
    mesh = footprintMesh(mine, oy, grp, 0x7a7466);
  };
  zoneHum(V(4, oy + 1.5, 2), 'f51');
}
function footprintMesh(list, oy, parent, color) {
  const geo = new THREE.CircleGeometry(0.06, 8); geo.scale(0.75, 1.7, 1); geo.rotateX(-Math.PI / 2);
  const m = new THREE.InstancedMesh(geo, mat('print' + color, { color, roughness: 1, transparent: true, opacity: 0.55, depthWrite: false }), Math.max(1, list.length));
  const mm = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(1, 1, 1);
  list.forEach(([x, z, a], i) => { q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), a); mm.compose(new THREE.Vector3(x, oy + 0.006, z), q, s); m.setMatrixAt(i, mm); });
  m.count = list.length; m.renderOrder = 1; parent.add(m);
  return m;
}
function voidBeyond(oy) {
  const grp = new THREE.Group(); grp.userData.zone = 'void'; G.scene.add(grp);
  // the floor: 51's dust, continuing, then the dust thinning to a grid like graph paper, then nothing
  const s = new Surface(8, 8, 32, 5101).fill('#6a6862').noise(0.4, 1, 'multiply', 6, 5102);
  s.g.strokeStyle = 'rgba(160,156,146,0.35)'; s.g.lineWidth = 1; for (let i = 0; i <= 8; i++) { s.g.beginPath(); s.g.moveTo(s.px(i), 0); s.g.lineTo(s.px(i), s.H); s.g.stroke(); s.g.beginPath(); s.g.moveTo(0, s.px(i)); s.g.lineTo(s.W, s.px(i)); s.g.stroke(); }
  const t = s.textures({ repeat: true }); t.map.repeat.set(40, 40);
  const fl = new THREE.Mesh(new THREE.PlaneGeometry(320, 320), new THREE.MeshStandardMaterial({ map: t.map, roughness: 1, color: 0x8a8880, emissive: 0xffffff, emissiveMap: t.map, emissiveIntensity: 0.45 }));
  fl.rotation.x = -Math.PI / 2; fl.position.set(5, oy - 0.002, -158); grp.add(fl);
  floorRegion({ x0: -150, x1: 160, z0: -320, z1: 0.05, y: oy, zone: 'void' });
  zone({ key: 'void', name: '', x0: -150, x1: 160, z0: -320, z1: -0.05, y0: oy - 0.5, y1: oy + 4, group: grp, surface: 'concrete', sky: 0, void: true });
  // the cut edge of the building: the wall ends ragged, floor slab showing in section
  const sec = mat('slabSection', { color: 0x5a5650, roughness: 1 });
  box(10.4, 0.36, 0.42, sec, { x: 5.2, y: oy - 0.18, z: -0.21, parent: grp });
  // things standing out there, a long way off: a wardrobe, a door in its frame with no wall, a lamp post, a bed
  const r = rng(5103), grey = mat('voidThing', { color: 0x141414, roughness: 1 });
  const thing = (x, z, w, h, d, ry) => { const m = box(w, h, d, grey, { x, y: oy, base: true, z, ry, parent: grp }); return m; };
  thing(-6, -18, 1.0, 1.9, 0.55, 0.4); thing(9, -26, 0.9, 2.05, 0.08, -0.2); thing(14, -26, 0.15, 2.05, 0.15, 0); thing(4.1, -26, 0.15, 2.05, 0.15, 0);
  thing(-14, -40, 2.0, 0.6, 1.6, 1.1); thing(22, -55, 0.25, 6.0, 0.25, 0); thing(-30, -70, 12, 9, 10, 0.2); thing(40, -90, 8, 14, 8, -0.3);
  for (let i = 0; i < 30; i++) { const a = r() * Math.PI, d = 40 + r() * 140; thing(5 + Math.cos(a) * d * 1.4, -Math.sin(a) * d - 10, 0.5 + r() * 3, 0.5 + r() * 8, 0.5 + r() * 3, r() * 3); }
  // a light, very far off, at floor height, the colour of the hall bulb in 47
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ color: 0xffd8a0, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false, map: (() => { const c = canvas(64, 64), g = c.getContext('2d'); const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.3, 'rgba(255,255,255,0.3)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); return new THREE.CanvasTexture(c); })() }));
  sp.scale.set(6, 6, 1); sp.position.set(2, oy + 1.6, -210); grp.add(sp);
  grp.visible = false;
  G.voidGroup = grp;
  // walk far enough out and you're home
  let fired = false;
  onUpdate(() => {
    const p = G.playerPos; if (!p) return;
    const near = p.y > oy - 1 && p.y < oy + 3 && p.z < 6.2 && p.x < 11;
    grp.visible = near;
    if (G.playerZone === 'void' && p.z < -24 && !fired) {
      fired = true; G.blackout = 1.6;
      setTimeout(() => { G.teleport?.(8.6, 4.55, 0, Math.PI / 2); G.addDecay?.(0.15); G.onReturn?.(); G.ui.toast('The hall light in 47. You are standing under it. You didn’t come down the stairs.', 7); fired = false; }, 1200);
    }
  });
}

// ================================================================== 44: the corridor
function flat44() {
  const oy = floorY(3), CELLS = 10, CX = (k) => 19 + k * 6, END = 79;
  const rooms = { vest: { x0: 14.42, x1: 17, z0: 3.5, z1: 6.0 }, corr: { x0: 17, x1: END, z0: 4.15, z1: 5.35 } };
  const lines = [
    { id: 'f44w', axis: 'x', c: 14.21, p0: 14.0, p1: 14.42, a0: 0, a1: 8, ext: true },
    { id: 'f44vn', axis: 'z', c: 3.5, p0: 3.36, p1: 3.5, a0: 14.42, a1: 17.07 },
    { id: 'f44vs', axis: 'z', c: 6.0, p0: 6.0, p1: 6.14, a0: 14.42, a1: 17.07 },
    { id: 'f44ve', axis: 'x', c: 17, p0: 16.93, p1: 17.07, a0: 3.5, a1: 6.0 },
    { id: 'f44cn', axis: 'z', c: 4.15, p0: 4.08, p1: 4.15, a0: 17, a1: END },
    { id: 'f44cs', axis: 'z', c: 5.35, p0: 5.35, p1: 5.42, a0: 17, a1: END },
    { id: 'f44end', axis: 'x', c: END, p0: END, p1: END + 0.14, a0: 4.15, a1: 5.35 },
    { id: 'f44cb', axis: 'z', c: 1.6, p0: 1.46, p1: 1.6, a0: 17, a1: END },
  ];
  const openings = [
    { id: 'f44dEntry', line: 'f44w', a0: 4.12, a1: 5.0, y0: 0, y1: 2.08, kind: 'door' },
    { id: 'f44arch', line: 'f44ve', a0: 4.15, a1: 5.35, y0: 0, y1: 2.2, kind: 'gap' },
  ];
  for (let k = 0; k < CELLS; k++) {
    const x0 = CX(k) - 1.0, x1 = CX(k) + 1.0;
    rooms['cell' + k] = { x0, x1, z0: 1.6, z1: 4.15 };
    lines.push({ id: 'f44c' + k + 'w', axis: 'x', c: x0, p0: x0 - 0.07, p1: x0 + 0.07, a0: 1.6, a1: 4.15 });
    lines.push({ id: 'f44c' + k + 'e', axis: 'x', c: x1, p0: x1 - 0.07, p1: x1 + 0.07, a0: 1.6, a1: 4.15 });
    openings.push({ id: 'f44d' + k, line: 'f44cn', a0: CX(k) - 0.38, a1: CX(k) + 0.38, y0: 0, y1: 2.0, kind: 'door' });
  }
  // one material for every wall: institutional, the same metre after metre
  const s = new Surface(3, H, 64, 4401).fill('#cfc6a4').noise(0.18, 1.5, 'multiply', 10, 4402);
  { const g = s.g; g.fillStyle = '#5c7268'; g.fillRect(0, s.Y(1.35), s.W, s.px(1.35)); g.fillStyle = '#2c3a34'; g.fillRect(0, s.Y(1.35), s.W, 3); s.rising(0.3, [30, 30, 25], 0.4); s.grain(0.05); }
  const wt = s.textures({ repeat: true });
  const wallM = new THREE.MeshStandardMaterial({ map: wt.map, bumpMap: wt.bumpMap, bumpScale: 1, roughness: 0.85 });
  const fs = new Surface(2, 2, 64, 4403).fill('#6e6a5a'); fs.g.fillStyle = '#5e5a4c'; for (let i = 0; i < 2; i++) fs.g.fillRect(i * fs.px(1), 0, 3, fs.H); fs.noise(0.3, 0.8, 'multiply', 6, 4404).rough(0.5);
  const ft = fs.textures({ repeat: true });
  const floorM = new THREE.MeshStandardMaterial({ map: ft.map, roughnessMap: ft.roughnessMap, roughness: 1 });
  const ceilM = mat('ceil44', { color: 0xb8b4a4, roughness: 1 });
  const def = { key: 'f44', name: 'Flat 44', oy, H, rooms, lines, openings, uvTile: 3, paint: () => wallM, floor: () => floorM, ceil: () => ceilM, core: null, noSlab: false, names: { vest: 'Flat 44', corr: 'Flat 44', ...Object.fromEntries([...Array(CELLS)].map((_, k) => ['cell' + k, 'Flat 44'])) } };
  const grp = buildZone(def);
  for (const z of G.zones) if (z.key.startsWith('f44')) { z.surface = 'lino'; z.sky = 0; }
  makeDoor({ id: 'f44dEntry', hinge: 'a1', swing: 1, open: 0, max: 1.4, surface: panelDoorSurface(0.83, 2.05, '#7a7a6a', 4405, {}), thick: 0.045, plane: 14.27, locked: { prompt: () => 'Open', use: () => { if (!G.flags.f44) { G.flags.f44 = true; setTimeout(() => G.ui.toast('A flat’s hallway, and then a corridor, going east, a long way further than the building does.'), 1400); } return false; } } });
  // the cells: each the same. a chair facing the back wall; a bulb; a door
  const chairs = [];
  for (let k = 0; k < CELLS; k++) {
    const x = CX(k);
    makeDoor({ id: 'f44d' + k, hinge: 'a0', swing: -1, open: 1.3, max: 1.45, surface: panelDoorSurface(0.71, 1.97, '#9a9a88', 4410 + k, {}), thick: 0.04 });
    const c = group({ x, y: oy, z: 2.3, ry: Math.PI, parent: grp });
    box(0.42, 0.04, 0.42, M.veneer, { y: 0.44, parent: c }); for (const sx of [-0.18, 0.18]) for (const sz of [-0.18, 0.18]) box(0.035, 0.44, 0.035, M.veneer, { x: sx, y: 0.22, z: sz, parent: c });
    box(0.4, 0.42, 0.03, M.veneer, { y: 0.68, z: -0.19, parent: c });
    collider({ x, z: 2.3, hx: 0.22, hz: 0.22, y0: oy, y1: oy + 0.9 });
    chairs.push(c);
    const b = sphere(0.03, mat('bulb44_' + k, { color: 0xfff4e0, emissive: 0xfff0d0, emissiveIntensity: 0 }), { x, y: oy + H - 0.45, z: 2.9, parent: grp, static: false });
    fixture({ pos: V(x, oy + H - 0.5, 2.9), mesh: b, k: 1.6, color: 0xfff0d0, flicker: 'bulb', range: 4 });
    // tubes in the corridor between the cells
    const tm = box(1.0, 0.04, 0.1, mat('tube44_' + k, { color: 0xeef4f4, emissive: 0xe8f4ff, emissiveIntensity: 0, roughness: 0.3 }), { x: x + 3, y: oy + H - 0.03, z: 4.75, parent: grp, static: false });
    fixture({ pos: V(x + 3, oy + H - 0.3, 4.75), mesh: tm, k: 3.2, color: 0xe4eeff, flicker: 'fluoro', range: 6, when: () => k * 6 + 22 > (G.playerPos?.x ?? 0) - 12 });
    if (k % 3 === 1) examine(c.children[0], 'Chair', ['A chair facing the wall, as if someone was told to sit here and wait.', 'The same chair. The wall in front of it has two pale marks at knee height.', 'The same chair.'][k % 3]);
  }
  // the loop: past the eighth cell the corridor quietly hands you back to the second
  let loops = 0;
  onUpdate(() => {
    const p = G.playerPos; if (!p || Math.abs(p.y - oy) > 1.5) return;
    if (p.x > CX(8) + 3 && p.z > 4.1 && p.z < 5.4) {
      loops++;
      G.teleport?.(p.x - 6 * 7, p.z, p.y, null, true);
      G.addDecay?.(0.05);
      // with each pass the chairs turn a little more toward the doors
      chairs.forEach((c, i) => { c.rotation.y = Math.PI - Math.min(Math.PI, loops * 0.5 + i * 0.05); });
      if (loops === 1) setTimeout(() => G.ui.toast('Cell after cell. The same chair. You have been counting: this is the eleventh. There were ten.'), 300);
      if (loops === 3) { knockSeq(V(p.x - 12, oy + 1.2, 1.4), [3, 3], 0.7, 1); }
      if (loops === 5) setTimeout(() => G.ui.toast('The chairs are facing the doors now.'), 300);
    }
  });
  // a sound like a ventilation fan, everywhere the same
  zoneHum(V(40, oy + 2.5, 4.75), 'f44');
  void grp; void cyl; void metalTex; void woodTex; void interactive; void makeProp; void sheet; void sfx;
}

// a low steady hum that belongs to a zone
function zoneHum(pos, key) {
  G.zoneHums = G.zoneHums || [];
  G.zoneHums.push({ pos, key });
}

// when the building gives you back to 47, some things in 47 have moved
G.onReturn = () => {
  const bear = G.props.find((p) => p.name === 'Teddy bear');
  if (bear && !bear.held) { bear.body.position.set(8.2, 0.15, 4.5); bear.body.quaternion.setFromEuler(0, Math.PI / 2, 0); bear.body.velocity.set(0, 0, 0); bear.body.wakeUp(); bear.desc = 'Sonya’s bear. It was tucked into her bed. Now it’s sitting in the hall, facing the front door, as if waiting for someone to come in.'; }
  const tv = G.lights.tv; if (tv && !tv.switched) tv.switched = true;
};
