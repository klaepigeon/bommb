// Doors and windows: hinged leaves that swing (and push the player and the props out of
// the way), linings and architraves, double-glazed timber windows with broken panes, the
// boarded window in Sonya's room, the padded front door on its chain.
import * as THREE from 'three';
import * as CANNON from 'cannon-es';
import { G, mat, box, cyl, collider, interactive, onUpdate, solidMat, staticBox } from './core.js';
import { OPENINGS, lineById, H, openById } from './plan.js';
import { Surface, woodTex, blobPath, rng, metalTex } from './textures.js';
import { sfx } from './audio.js';

// ---------------------------------------------------------------- door leaf textures
export function panelDoorSurface(w, h, col, seed, opts = {}) {
  const s = new Surface(w, h, 160, seed).fill(col);
  s.noise(0.25, 1, 'multiply', 8, seed).grain(0.05);
  const g = s.g, hg = s.hg;
  const panels = opts.glazed ? [[0.12, 1.05, w - 0.24, 0.85]] : [[0.12, 1.15, w - 0.24, 0.75], [0.12, 0.12, w - 0.24, 0.85]];
  for (const [x, y, pw, ph] of panels) {
    g.strokeStyle = 'rgba(0,0,0,0.3)'; g.lineWidth = 4; g.strokeRect(s.px(x), s.Y(y + ph), s.px(pw), s.px(ph));
    g.strokeStyle = 'rgba(255,255,240,0.2)'; g.lineWidth = 2; g.strokeRect(s.px(x) + 4, s.Y(y + ph) + 4, s.px(pw) - 8, s.px(ph) - 8);
    hg.fillStyle = '#5a5a5a'; hg.fillRect(s.px(x), s.Y(y + ph), s.px(pw), s.px(ph));
    hg.fillStyle = '#707070'; hg.fillRect(s.px(x) + 6, s.Y(y + ph) + 6, s.px(pw) - 12, s.px(ph) - 12);
  }
  // flaking paint showing older layers and bare wood
  for (let i = 0; i < 26; i++) {
    const p = blobPath(s.r() * s.W, s.r() * s.H, 3 + s.r() * 22, 2 + s.r() * 12, s.r, 0.7, 16);
    g.fillStyle = s.r() < 0.5 ? '#8a7a60' : '#5c4630'; g.fill(p); hg.fillStyle = '#585858'; hg.fill(p);
  }
  // hand grime around the handle, kick scuffs low down
  const grd = g.createRadialGradient(s.px(w - 0.09), s.Y(1.0), 0, s.px(w - 0.09), s.Y(1.0), s.px(0.22));
  grd.addColorStop(0, 'rgba(40,30,18,0.45)'); grd.addColorStop(1, 'rgba(40,30,18,0)'); g.fillStyle = grd; g.fillRect(0, 0, s.W, s.H);
  s.rising(0.3, [40, 34, 26], 0.4);
  if (opts.scratches) { // gouges at a child's height, on the inside
    g.strokeStyle = 'rgba(70,50,30,0.7)'; g.lineWidth = 1.5;
    for (let i = 0; i < 14; i++) { const x = s.px(0.3 + s.r() * 0.35), y = s.Y(0.6 + s.r() * 0.5); g.beginPath(); g.moveTo(x, y); g.lineTo(x + (s.r() - 0.5) * 8, y + 20 + s.r() * 40); g.stroke(); }
  }
  if (opts.text) s.scrawl(opts.text, 0.12, 1.75, 0.05, 'rgba(40,30,20,0.7)', -0.03);
  return s;
}
export function paddedDoorSurface(w, h, seed, num = '47', col = '#4a2a22') { // quilted leatherette over felt, studded in a diamond grid
  const s = new Surface(w, h, 128, seed).fill(col).rough(0.45);
  s.noise(0.3, 0.7, 'multiply', 6, seed).grain(0.07);
  const g = s.g, hg = s.hg, step = 0.18;
  for (let y = 0.15; y < h - 0.1; y += step) for (let x = 0.08 + ((y / step | 0) % 2) * step / 2; x < w - 0.05; x += step) {
    const cx = s.px(x), cy = s.Y(y);
    const grd = hg.createRadialGradient(cx, cy, 2, cx, cy, s.px(step * 0.6)); grd.addColorStop(0, '#404040'); grd.addColorStop(1, '#a0a0a0');
    hg.fillStyle = grd; hg.fillRect(cx - s.px(step), cy - s.px(step), s.px(step * 2), s.px(step * 2));
    g.fillStyle = '#b8a070'; g.beginPath(); g.arc(cx, cy, 3, 0, 6.28); g.fill(); // brass stud
  }
  for (let i = 0; i < 5; i++) { // splits in the vinyl, felt bulging out
    const p = blobPath(s.r() * s.W, s.r() * s.H, 6 + s.r() * 20, 3 + s.r() * 30, s.r, 0.6, 16);
    g.fillStyle = '#6e6252'; g.fill(p); hg.fillStyle = '#c0c0c0'; hg.fill(p);
  }
  // a chalk mark from outside, seen when the door is ajar? no - on the inside: a number
  if (num) s.scrawl([num], 0.35, 1.85, 0.08, 'rgba(220,210,190,0.35)');
  return s;
}

// ---------------------------------------------------------------- doors
export const DOORS = {};

export function lining(o, l, woodM) {
  const depth = l.p1 - l.p0, mid = (l.p0 + l.p1) / 2, t = 0.025, w = o.a1 - o.a0, h = o.y1, oy = o.oy || 0;
  const arch = 0.07, archT = 0.018;
  const along = (a, y, sa, sy, sd, p) => (l.axis === 'z'
    ? box(sa, sy, sd, woodM, { x: a, y: y + oy, z: p, cast: false, parent: o.parent })
    : box(sd, sy, sa, woodM, { x: p, y: y + oy, z: a, cast: false, parent: o.parent }));
  // jamb linings
  along(o.a0 + t / 2, h / 2, t, h, depth, mid);
  along(o.a1 - t / 2, h / 2, t, h, depth, mid);
  along((o.a0 + o.a1) / 2, h - t / 2, w, t, depth, mid);
  // architraves on both faces
  for (const p of [l.p0 - archT / 2, l.p1 + archT / 2]) {
    along(o.a0 - arch / 2 + 0.01, (h + arch) / 2, arch, h + arch, archT, p);
    along(o.a1 + arch / 2 - 0.01, (h + arch) / 2, arch, h + arch, archT, p);
    along((o.a0 + o.a1) / 2, h + arch / 2 - 0.01, w + arch * 2 - 0.02, arch, archT, p);
  }
}

// spec: { id, hinge: 'a0'|'a1', swing: +1|-1 (toward +axis or -axis), open: initial angle, max, surface, glazed, stuck, locked }
export function makeDoor(spec) {
  const o = openById[spec.id], l = lineById[o.line], oy = o.oy || 0;
  const woodM = spec.liningMat || mat('lining', { map: woodTex('#b9ae98', 21, 1).map, roughness: 0.75, color: 0xd8cfbc });
  lining(o, l, woodM);
  const w = o.a1 - o.a0 - 0.05, h = o.y1 - 0.03, th = spec.thick || 0.04;
  const hingeA = spec.hinge === 'a0' ? o.a0 + 0.025 : o.a1 - 0.025;
  const dirA = spec.hinge === 'a0' ? 1 : -1;       // along the opening from hinge to latch
  const mid = spec.plane ?? (l.p0 + l.p1) / 2 + (spec.inset || 0);
  const P = l.axis === 'z' ? new THREE.Vector3(hingeA, oy + 0.012, mid) : new THREE.Vector3(mid, oy + 0.012, hingeA);
  const d = l.axis === 'z' ? [dirA, 0] : [0, dirA];
  const psi0 = Math.atan2(-d[1], d[0]);
  const n = l.axis === 'z' ? [0, spec.swing] : [spec.swing, 0];
  const sign = Math.sign(n[0] * d[1] + n[1] * -d[0]) || 1;

  const pivot = new THREE.Group(); pivot.position.copy(P); pivot.rotation.y = psi0; (o.parent || G.scene).add(pivot);
  const surf = spec.surface || panelDoorSurface(w, h, spec.color || '#d4cbb4', spec.seed || 1, spec);
  const tx = surf.textures();
  const faceM = new THREE.MeshStandardMaterial({ map: tx.map, bumpMap: tx.bumpMap, bumpScale: 2, roughness: tx.roughnessMap ? 1 : 0.7, roughnessMap: tx.roughnessMap || null });
  const edgeM = solidMat('doorEdge', 0x6b5a44, 0.8);
  const leaf = new THREE.Mesh(new THREE.BoxGeometry(w, h, th), [edgeM, edgeM, edgeM, edgeM, faceM, faceM]);
  // mirror the back face's uv so the handle grime is on the right side from both sides
  leaf.position.set(w / 2, h / 2, 0); leaf.castShadow = true; leaf.receiveShadow = true;
  pivot.add(leaf);
  if (spec.glazed) { // frosted glass in the top panel, one corner broken out
    const gm = mat('frosted', { color: 0xc8ccc4, roughness: 0.35, transparent: true, opacity: 0.55, metalness: 0 });
    const gl = new THREE.Mesh(new THREE.PlaneGeometry(w - 0.26, 0.82), gm); gl.position.set(w / 2, 1.47, th / 2 + 0.002); pivot.add(gl);
    const gl2 = gl.clone(); gl2.position.z = -th / 2 - 0.002; gl2.rotation.y = Math.PI; pivot.add(gl2);
  }
  // handle: lever + backplate on both sides, at the latch edge
  const brass = mat('brass', { color: 0x8a7550, roughness: 0.45, metalness: 0.8, map: metalTex('#8a7550', 0.3, 31).map });
  for (const s of [1, -1]) {
    const bp = box(0.035, 0.18, 0.008, brass, { x: w - 0.07, y: 0.98, z: s * (th / 2 + 0.004), parent: pivot, static: false });
    const lev = box(0.12, 0.018, 0.018, brass, { x: w - 0.11, y: 1.02, z: s * (th / 2 + 0.035), parent: pivot, static: false });
    const stem = box(0.016, 0.016, 0.03, brass, { x: w - 0.07, y: 1.02, z: s * (th / 2 + 0.018), parent: pivot, static: false });
    void bp; void lev; void stem;
  }
  // hinges
  for (const y of [0.25, h - 0.25]) cyl(0.009, 0.009, 0.1, 6, brass, { x: 0, y, z: 0, parent: pivot, static: false });

  const col = collider({ hx: w / 2, hz: th / 2 + 0.01, y0: oy, y1: oy + h, door: true });
  const body = new CANNON.Body({ mass: 0, type: CANNON.Body.KINEMATIC });
  body.addShape(new CANNON.Box(new CANNON.Vec3(w / 2, h / 2, th / 2 + 0.005)));
  G.phys.addBody(body);

  const door = {
    id: spec.id, pivot, leaf, w, h, angle: spec.open || 0, target: spec.open || 0, max: spec.max || 1.6,
    sign, psi0, col, body, spec, locked: spec.locked || null, moving: false, speed: spec.speed || 2.2,
    world: new THREE.Vector3(), // centre of the leaf (for sound)
  };
  const sync = () => {
    const ang = psi0 + sign * door.angle;
    pivot.rotation.y = ang;
    const cx = P.x + Math.cos(ang) * w / 2, cz = P.z - Math.sin(ang) * w / 2;
    col.x = cx; col.z = cz; col.rot = ang;
    body.position.set(cx, oy + h / 2, cz); body.quaternion.setFromEuler(0, ang, 0);
    door.world.set(cx, oy + 1.1, cz);
  };
  sync();
  onUpdate((dt) => {
    if (Math.abs(door.target - door.angle) < 0.001) { if (door.moving) { door.moving = false; if (door.target === 0) sfx(spec.shutSound || 'doorShut', door.world); } return; }
    door.moving = true;
    const k = Math.min(1, dt * door.speed * (spec.stiff ? 0.45 : 1));
    door.angle += Math.sign(door.target - door.angle) * Math.min(Math.abs(door.target - door.angle), Math.max(k * Math.abs(door.target - door.angle), dt * 0.25));
    sync();
  });
  interactive(leaf, {
    prompt: () => (door.locked ? door.locked.prompt() : door.target > 0.15 ? 'Close' : door.unstuck && door.target > 0 ? 'Shove it open' : 'Open'),
    use: () => {
      if (door.locked && door.locked.use()) return;
      if (door.target > 0.15) { door.target = 0; sfx(spec.creak || 'doorCreak', door.world, { rate: 1.1 }); }
      else {
        door.target = door.max;
        if (spec.stuckOnce && !door.unstuck) { door.unstuck = true; door.target = 0.12; sfx('doorStuck', door.world); setTimeout(() => G.ui.toast(spec.stuckOnce), 50); return; }
        sfx(spec.creak || 'doorCreak', door.world);
      }
    },
  });
  DOORS[spec.id] = door;
  return door;
}

// ---------------------------------------------------------------- windows
const frameMat = () => mat('winFrame', { map: woodTex('#e2dccb', 41, 1).map, color: 0xd9d2bf, roughness: 0.8 });
export function glassMat(dirt = 0) {
  return mat('glass' + dirt, { color: dirt ? 0xb8bcb0 : 0xc8d0d0, roughness: dirt ? 0.5 : 0.1, metalness: 0.0, transparent: true, opacity: dirt ? 0.22 : 0.1, depthWrite: false, emissive: 0x30363e, emissiveIntensity: 0.4 });
}

// a pane w x h centred at local (x,y) in frame plane; broken: 0 intact, 1 cracked/holed, 2 mostly gone
function pane(parent, x, y, w, h, broken, seed) {
  const r = rng(seed);
  const shape = new THREE.Shape(); shape.moveTo(-w / 2, -h / 2); shape.lineTo(w / 2, -h / 2); shape.lineTo(w / 2, h / 2); shape.lineTo(-w / 2, h / 2); shape.closePath();
  if (broken) {
    const hole = new THREE.Path(), n = 14, cx = (r() - 0.5) * w * 0.3, cy = (r() - 0.5) * h * 0.3;
    const R = broken === 2 ? 0.48 : 0.22;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2, k = (i % 2 ? 0.45 : 1) * (0.6 + r() * 0.5);
      const px = Math.max(-w / 2 + 0.01, Math.min(w / 2 - 0.01, cx + Math.cos(a) * w * R * k));
      const py = Math.max(-h / 2 + 0.01, Math.min(h / 2 - 0.01, cy + Math.sin(a) * h * R * k));
      i ? hole.lineTo(px, py) : hole.moveTo(px, py);
    }
    hole.closePath(); shape.holes.push(hole);
  }
  const m = new THREE.Mesh(new THREE.ShapeGeometry(shape), glassMat(seed % 3 === 0 ? 1 : 0));
  m.position.set(x, y, 0); m.renderOrder = 2; parent.add(m);
  return m;
}

// window in an opening on the n or s wall. broken: per-pane damage [outerL, outerR, innerL, innerR]
function makeWindow(id, opts = {}) {
  const o = openById[id], l = lineById[o.line];
  const fm = frameMat(), w = o.a1 - o.a0, h = o.y1 - o.y0, cx = (o.a0 + o.a1) / 2, cy = (o.y0 + o.y1) / 2;
  const inward = l.id === 'n' ? 1 : -1;  // +z is inside for the north wall
  const inner = l.id === 'n' ? l.p1 : l.p0, outer = l.id === 'n' ? l.p0 : l.p1;
  const planes = [inner - inward * 0.09, outer + inward * 0.1];
  const r = rng(id.length * 31);
  planes.forEach((pz, k) => {
    const grp = new THREE.Group(); grp.position.set(cx, cy, pz); G.scene.add(grp);
    const fw = 0.055, mz = 0.05;
    const bar = (bx, by, bw, bh) => box(bw, bh, mz, fm, { x: bx, y: by, z: 0, parent: grp, static: true });
    bar(0, h / 2 - fw / 2, w, fw); bar(0, -h / 2 + fw / 2, w, fw); bar(-w / 2 + fw / 2, 0, fw, h); bar(w / 2 - fw / 2, 0, fw, h);
    bar(0, 0, fw, h); // mullion
    const tr = h / 2 - 0.42; bar(-w / 4, tr, w / 2, fw * 0.8); // transom over the fortochka (left)
    const pw = w / 2 - fw * 1.5, ph = h - fw * 2;
    const dmg = (opts.broken || [])[k * 2] || 0, dmg2 = (opts.broken || [])[k * 2 + 1] || 0;
    pane(grp, -w / 4, (tr - h / 2 + fw) / 2 + 0.0, pw, tr + h / 2 - fw * 1.5, dmg, k * 7 + 3 + id.length);
    pane(grp, -w / 4, (tr + h / 2) / 2, pw, h / 2 - tr - fw * 1.5, 0, k * 7 + 4);
    pane(grp, w / 4, 0, pw, ph, dmg2, k * 7 + 5 + id.length);
    // window catch
    if (k === 0) box(0.02, 0.08, 0.025, mat('brassDull', { color: 0x6e6250, metalness: 0.7, roughness: 0.5 }), { x: fw / 2 + 0.02, y: 0, z: inward * 0.03, parent: grp });
    void r;
  });
  // inside sill board, outside tin drip
  const sillM = mat('sill', { map: woodTex('#cfc6b0', 43, 1).map, color: 0xcfc6b0, roughness: 0.7 });
  box(w + 0.1, 0.035, 0.26, sillM, { x: cx, y: o.y0 - 0.0, z: inner + inward * 0.02 - inward * 0.08, cast: false });
  box(w + 0.06, 0.012, 0.16, mat('tin', { color: 0x5f5d58, roughness: 0.5, metalness: 0.7 }), { x: cx, y: o.y0 - 0.06, z: outer - inward * 0.06, cast: false });
  // the glass is still a wall
  staticBox(cx, cy, (l.p0 + l.p1) / 2, w, h, l.p1 - l.p0);
}

// broken glass on the floor beneath a window
function shards(x0, x1, z, dz, n, seed) {
  const r = rng(seed), gm = glassMat(0);
  for (let i = 0; i < n; i++) {
    const s = 0.02 + r() * 0.07, sh = new THREE.Shape();
    sh.moveTo(0, 0); sh.lineTo(s, r() * s * 0.4); sh.lineTo(s * (0.3 + r() * 0.5), s * (0.6 + r() * 0.8)); sh.closePath();
    const m = new THREE.Mesh(new THREE.ShapeGeometry(sh), gm);
    m.rotation.set(-Math.PI / 2, 0, r() * 6.28); m.position.set(x0 + r() * (x1 - x0), 0.004 + r() * 0.002, z + r() * dz);
    m.renderOrder = 2; G.scene.add(m);
  }
}

// ---------------------------------------------------------------- build all
export function buildOpenings() {
  // windows
  makeWindow('livWin', { broken: [2, 1, 1, 0] });
  makeWindow('bedWin', { broken: [0, 1, 0, 0] });
  makeWindow('kitWin', { broken: [0, 0, 0, 1] });
  makeWindow('childWin', {});
  shards(0.8, 2.5, 0.05, 0.6, 26, 3);
  shards(5.9, 6.7, 0.05, 0.3, 6, 4);

  // interior doors
  makeDoor({ id: 'dLiving', hinge: 'a1', swing: -1, open: 1.45, max: 1.55, glazed: true, color: '#cfc6ae', seed: 3 });
  makeDoor({ id: 'dBed', hinge: 'a1', swing: -1, open: 0.55, max: 1.6, color: '#cbc2aa', seed: 4 });
  makeDoor({ id: 'dChild', hinge: 'a0', swing: 1, open: 0, max: 1.5, color: '#c7c8bd', seed: 5, scratches: false, text: null });
  makeDoor({ id: 'dBath', hinge: 'a1', swing: 1, open: 0, max: 1.45, color: '#d6d2c2', seed: 6, stiff: true, stuckOnce: 'Swollen with damp. It gives a little.', creak: 'doorScrape' });
  // the box-room door: bolted on the living-room side
  const store = makeDoor({ id: 'dStore', hinge: 'a0', swing: 1, open: 0, max: 2.5, color: '#b9ad94', seed: 7 });
  {
    const o = openById.dStore, l = lineById[o.line], zf = l.p0 - 0.012;
    const iron = mat('iron', { map: metalTex('#4a4440', 0.8, 51).map, roughness: 0.7, metalness: 0.6 });
    box(0.03, 0.09, 0.012, iron, { x: o.a1 - 0.07, y: 1.38, z: zf, static: false }); // keeper on the frame
    const boltGrp = new THREE.Group(); G.scene.add(boltGrp);
    const plate = box(0.16, 0.05, 0.01, iron, { x: o.a1 - 0.2, y: 1.38, z: zf, parent: boltGrp, static: false });
    const rod = cyl(0.008, 0.008, 0.16, 6, iron, { x: o.a1 - 0.13, y: 1.38, z: zf - 0.012, rz: Math.PI / 2, parent: boltGrp, static: false });
    // bolt moves with the door leaf (it's on the door, the keeper is on the frame)
    store.pivot.attach(boltGrp);
    store.locked = {
      prompt: () => 'Slide the bolt',
      use: () => {
        sfx('bolt', store.world);
        rod.position.x += 0.06 * (store.spec.hinge === 'a1' ? 1 : -1);
        store.locked = null;
        G.ui.toast('Bolted from this side.');
        return true;
      },
    };
    void plate;
  }
  // balcony door: half-glazed, opens inward toward the room
  makeDoor({ id: 'balDoor', hinge: 'a1', swing: 1, open: 1.5, max: 1.6, glazed: true, color: '#d9d3c2', seed: 8, plane: -0.1 });

  // the kitchen door: off its hinges, leaning in the hall. the lining and hinges remain
  {
    const o = openById.dKit, l = lineById[o.line];
    lining(o, l, mat('lining', {}));
    const s = panelDoorSurface(0.8, 2.0, '#cfc7b0', 9, { glazed: true });
    const t = s.textures();
    // leaning against the hall's south wall, top resting on it
    const leaf = box(0.8, 2.0, 0.04, new THREE.MeshStandardMaterial({ map: t.map, bumpMap: t.bumpMap, bumpScale: 2, roughness: 0.75 }), { x: 7.1, y: 1.0, z: 5.02, static: false });
    leaf.rotation.x = 0.06;
    collider({ x: 7.1, z: 5.03, hx: 0.42, hz: 0.09, y0: 0, y1: 2 });
    staticBox(7.1, 1.0, 5.03, 0.84, 2.0, 0.14);
    interactive(leaf, { prompt: () => 'Kitchen door', use: () => G.ui.toast('Lifted off its hinges and leant here. Someone wanted the kitchen open to the hall.') });
  }

  buildEntry();
  buildBoardedWindow();
}

// ---------------------------------------------------------------- front door
function buildEntry() {
  const o = openById.dEntry, l = lineById[o.line];
  const door = makeDoor({
    id: 'dEntry', hinge: 'a0', swing: -1, open: 0, max: 0.11, thick: 0.07, speed: 4,
    surface: paddedDoorSurface(o.a1 - o.a0 - 0.05, o.y1 - 0.03, 91), plane: l.p0 + 0.06,
    liningMat: mat('entryLining', { map: woodTex('#3e2a1e', 22, 1).map, roughness: 0.8 }),
    creak: 'chainRattle', shutSound: 'doorHeavy',
  });
  // chain: from the leaf to a plate on the frame. visible links
  const steel = mat('chain', { color: 0x6b6660, metalness: 0.9, roughness: 0.45 });
  const links = [];
  for (let i = 0; i < 9; i++) {
    const m = new THREE.Mesh(new THREE.TorusGeometry(0.011, 0.0028, 4, 8), steel);
    m.castShadow = true; G.scene.add(m); links.push(m);
  }
  const plate = box(0.02, 0.06, 0.1, steel, { x: l.p0 - 0.012, y: 1.55, z: o.a1 + 0.06 });
  void plate;
  const padlock = box(0.03, 0.035, 0.012, mat('padlock', { color: 0x8b7444, metalness: 0.8, roughness: 0.4 }), { x: l.p0 - 0.02, y: 1.5, z: o.a1 + 0.04, static: false });
  const a = new THREE.Vector3(), b = new THREE.Vector3(l.p0 - 0.03, 1.55, o.a1 + 0.05);
  onUpdate(() => {
    // anchor on the leaf near the latch edge, inside face
    a.set(door.w - 0.08, 1.55, 0.04).applyMatrix4(door.pivot.matrixWorld);
    const sag = 0.09 * (1 - door.angle / door.max) + 0.01;
    for (let i = 0; i < links.length; i++) {
      const t = (i + 0.5) / links.length;
      links[i].position.lerpVectors(a, b, t); links[i].position.y -= Math.sin(t * Math.PI) * sag;
      links[i].lookAt(b); links[i].rotation.z = (i % 2) * Math.PI / 2;
    }
  });
  // peephole
  const brass = mat('brass', {});
  const ph = cyl(0.012, 0.012, 0.02, 10, brass, { x: 0, y: 1.58, z: 0.04, rx: Math.PI / 2, parent: door.pivot, static: false });
  ph.position.x = (o.a1 - o.a0) / 2;
  interactive(ph, { prompt: () => 'Look through the peephole', use: () => G.peephole?.(), range: 1.4 });
  // the cutscene needs the door open and unchained, then slammed and chained again
  G.entry = {
    door,
    setChain(on) { links.forEach((x) => { x.visible = on; }); padlock.visible = on; door.max = on ? 0.11 : 1.3; },
  };
  const free = (how) => {
    links.forEach((l) => { l.visible = false; }); padlock.visible = false;
    door.max = 1.45; door.speed = 2.2; door.locked = null; door.target = 1.45; G.flags.outside = true; setTimeout(() => G.tip?.('out'), 4000);
    sfx(how === 'axe' ? 'metal' : 'click', door.world, { vol: 1, rate: how === 'axe' ? 0.8 : 0.6 }); sfx('chainRattle', door.world, { rate: 0.8 });
    G.ui.toast(how === 'axe' ? 'Three blows. The chain gives on the third and falls in a heap. The door swings out onto the landing on its own weight.' : 'The little key turns. The padlock drops into your hand, cold. The chain slides off.');
  };
  door.locked = {
    prompt: () => (G.I?.held?.name === 'Axe' ? 'Cut the chain with the axe' : G.flags.key ? 'Unlock the padlock' : door.target > 0.05 ? 'Close' : 'Open'),
    use: () => {
      if (G.I?.held?.name === 'Axe') { free('axe'); return true; }
      if (G.flags.key) { free('key'); return true; }
      if (door.target > 0.05) { door.target = 0; sfx('doorHeavy', door.world, { vol: 0.5 }); return true; }
      door.target = door.max; sfx('chainRattle', door.world);
      if (!G.flags.chainSeen) { G.flags.chainSeen = true; setTimeout(() => G.ui.toast('The chain is padlocked on this side. No key on the ring by the door.'), 600); }
      G.tip?.('chain');
      return true;
    },
  };
  // evacuation notice glued to the inside of the door
  G.notices = G.notices || {};
}

// ---------------------------------------------------------------- Sonya's boarded window
function buildBoardedWindow() {
  const o = openById.childWin, l = lineById[o.line];
  const z = l.p0 - 0.03, cx = (o.a0 + o.a1) / 2, w = o.a1 - o.a0;
  const r = rng(12);
  const planks = [];
  const plankTex = woodTex('#7a5c3c', 61, 0.9).map;
  const ys = [0.9, 1.13, 1.38, 1.6, 1.86, 2.12, 2.3];
  ys.forEach((y, i) => {
    const pw = 0.13 + r() * 0.05, len = w + 0.22 + r() * 0.12;
    const m = box(len, pw, 0.022, mat('plank' + (i % 3), { map: plankTex, roughness: 0.9, color: [0xffffff, 0xd8ccb8, 0xc0b4a0][i % 3] }), { x: cx + (r() - 0.5) * 0.06, y: y + 0.03, z: z - i * 0.003, static: false });
    m.rotation.z = (r() - 0.5) * 0.08;
    // nails
    for (const s of [-1, 1]) box(0.012, 0.012, 0.01, mat('nail', { color: 0x3a3632, metalness: 0.6, roughness: 0.6 }), { x: s * (len / 2 - 0.05), y: 0, z: 0.013, parent: m, static: false });
    planks.push(m);
  });
  // one plank is only held at one end
  const loose = planks[3];
  loose.rotation.z = -0.16;
  interactive(loose, {
    prompt: () => 'Pull the loose board',
    use: () => {
      loose.userData.it.disabled = true;
      sfx('board', loose.position);
      G.makeProp?.(loose, { mass: 2, size: [w + 0.3, 0.16, 0.022] , name: 'Plank', desc: 'Pine, nailed up from inside. The nails went in at an angle, in a hurry.' });
      G.flags.boardPulled = true;
      G.onBoardPulled?.();
    },
  });
  G.boardedPlanks = planks;
}

void H; void OPENINGS;
