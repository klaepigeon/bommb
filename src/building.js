// The rest of Building 14: the stairwell from the basement to the top, its landings and
// their doors (most locked; a few not), the lobby with the mailboxes and the street door,
// and the light fittings, of which the building can now afford four at a time.
import * as THREE from 'three';
import { G, mat, box, cyl, group, collider, staticBox, interactive, onUpdate, solidMat, sphere, floorRegion, zone } from './core.js';
import { STAIR, STOREY, EXT, floorY, flatNo, LINES, OPENINGS, lineById, openById } from './plan.js';
import { holedPlane } from './shell.js';
import { makeDoor, paddedDoorSurface, panelDoorSurface, glassMat } from './openings.js';
import { paintStair } from './surfaces.js';
import { Surface, metalTex, woodTex, rng, canvas } from './textures.js';
import { M, rbox, makeProp, pickable } from './furniture.js';
import { sfx, knockSeq } from './audio.js';
import { canvasTex, examine, sheet } from './dress.js';
import * as D from './docs.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
const S = STAIR, HALF = STOREY / 2, RISERS = 9;
export const FLOORS = {}; // per-floor groups, for culling

// ---------------------------------------------------------------- pooled lights
// Every fitting in the building is a "fixture"; four real lights are handed each frame to
// the four nearest fixtures that are on. Light count stays fixed (no shader rebuilds) and
// the stairwell can have a lamp on every landing.
const fixtures = [];
export function fixture(f) { const o = { color: 0xffd8a0, k: 4, range: 7, flicker: 'bulb', on: true, t: Math.random() * 9, ...f }; fixtures.push(o); return o; }
function flickerK(f, dt) {
  f.t += dt; const t = f.t;
  if (f.flicker === 'dying') { if (f.hold > 0) { f.hold -= dt; return f.v; } if (Math.random() < dt * 1.2) { f.hold = 0.04 + Math.random() * 0.4; f.v = Math.random() * 0.3; return f.v; } return 0.75 + Math.sin(t * 9) * 0.1; }
  if (f.flicker === 'fluoro') { if (f.hold > 0) { f.hold -= dt; return f.v; } if (Math.random() < dt * 0.4) { f.hold = 0.05 + Math.random() * 0.2; f.v = Math.random() < 0.5 ? 0 : 0.3; return f.v; } return 0.97; }
  if (f.flicker === 'steady') return 1;
  return 0.92 + Math.sin(t * 7.3) * 0.03 + (Math.random() < dt * 0.3 ? -0.5 : 0);
}
export function buildLightPool() {
  const pool = [];
  for (let i = 0; i < 4; i++) { const l = new THREE.PointLight(0xffffff, 0, 7, 2); G.scene.add(l); pool.push(l); }
  G.poolLights = pool; G.fixtures = fixtures;
  const cam = new THREE.Vector3();
  onUpdate((dt) => {
    G.camera.getWorldPosition(cam);
    for (const f of fixtures) { f.cur = f.on && (!f.when || f.when()) ? f.k * flickerK(f, dt) * (G.decayLight ? G.decayLight(f) : 1) : 0; if (f.mesh) f.mesh.material.emissiveIntensity = (f.cur / f.k) * (f.glow ?? 2); }
    const near = fixtures.filter((f) => f.cur > 0 && Math.abs(f.pos.y - cam.y) < 5).sort((a, b) => a.pos.distanceToSquared(cam) - b.pos.distanceToSquared(cam));
    pool.forEach((l, i) => { const f = near[i]; if (!f || f.pos.distanceTo(cam) > 16) { l.intensity = 0; return; } l.position.copy(f.pos); l.color.setHex(f.color); l.distance = f.range; l.intensity = f.cur; });
  });
}

// ---------------------------------------------------------------- materials
let MAT;
function mats() {
  if (MAT) return MAT;
  const wallT = paintStair(4.2, STOREY, 1201, { tags: true }).textures({ repeat: true });
  const wallT2 = paintStair(4.2, STOREY, 1202, { dado: '#5a6a7e' }).textures({ repeat: true });
  const terr = new Surface(1.2, 1.2, 128, 1203).fill('#8a8478');
  { const g = terr.g; for (let i = 0; i < 900; i++) { g.fillStyle = ['#5a5248', '#b8b0a0', '#6a4a3a', '#2a2826'][i % 4]; g.fillRect(terr.r() * terr.W, terr.r() * terr.H, 1 + terr.r() * 3, 1 + terr.r() * 3); } terr.noise(0.35, 0.6, 'multiply', 5, 1204).rough(0.6); g.fillStyle = 'rgba(40,36,30,0.6)'; g.fillRect(0, 0, terr.W, 2); g.fillRect(0, 0, 2, terr.H); }
  const terrT = terr.textures({ repeat: true });
  MAT = {
    wall: new THREE.MeshStandardMaterial({ map: wallT.map, bumpMap: wallT.bumpMap, bumpScale: 1.4, roughness: 0.9 }),
    wall2: new THREE.MeshStandardMaterial({ map: wallT2.map, bumpMap: wallT2.bumpMap, bumpScale: 1.4, roughness: 0.9 }),
    floor: new THREE.MeshStandardMaterial({ map: terrT.map, roughnessMap: terrT.roughnessMap, roughness: 1 }),
    soffit: mat('soffit', { color: 0x9a968a, roughness: 1, map: metalTex('#9a968a', 0.3, 1205).map }),
    step: mat('stepConc', { color: 0x7e7a70, roughness: 0.95, map: metalTex('#7e7a70', 0.2, 1206).map }),
    nosing: mat('nosing', { color: 0x3a3632, metalness: 0.6, roughness: 0.5 }),
    rail: mat('stairRail', { color: 0x4a2a1a, roughness: 0.45, map: woodTex('#4a2a1a', 1207, 1).map }),
    bar: mat('baluster', { color: 0x2e3430, metalness: 0.5, roughness: 0.6, map: metalTex('#2e3430', 0.8, 1208).map }),
    core: mat('stairCore', { color: 0x8a867a, roughness: 1 }),
  };
  for (const k of ['wall', 'wall2', 'floor']) { MAT[k].map.repeat.set(1, 1); }
  return MAT;
}

// a wall plane with UVs in metres / 4.2 x STOREY (the tiled stair texture)
function wallPlane(parent, W, Hh, holes, material, pos, ry) {
  const m = holedPlane(W, Hh, holes, material);
  const uv = m.geometry.attributes.uv, p = m.geometry.attributes.position;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, p.getX(i) / 4.2, p.getY(i) / STOREY);
  m.position.set(...pos); m.rotation.y = ry; m.castShadow = true; m.userData.blocker = true;
  parent.add(m); G.zoneSkins = (G.zoneSkins || []).concat([m]);
  return m;
}

// ---------------------------------------------------------------- a flight of stairs
// from (zA, yA) to (zB, yB) across x0..x1, as solid steps with a sloped soffit underneath
function flight(parent, x0, x1, zA, yA, zB, yB) {
  const m = mats(), n = RISERS, run = (zB - zA) / n, rise = (yB - yA) / n, w = x1 - x0, cx = (x0 + x1) / 2;
  const ar = Math.abs(rise);
  for (let i = 0; i < n; i++) {
    // a step whose tread sits on the ramp line at its middle, carried down to the soffit
    const zc = zA + run * (i + 0.5), top = yA + (yB - yA) * (i + 0.5) / n + ar / 2;
    box(w, ar + 0.14, Math.abs(run) + 0.02, m.step, { x: cx, y: top - (ar + 0.14) / 2, z: zc, parent });
    box(w, 0.02, 0.04, m.nosing, { x: cx, y: top - 0.01, z: zc + (rise > 0 ? -1 : 1) * Math.sign(run) * Math.abs(run) / 2, parent, cast: false });
  }
  // soffit: a slab under the whole flight
  const len = Math.hypot(zB - zA, yB - yA), ang = Math.atan2(yB - yA, zB - zA);
  const s = box(w, 0.14, len, m.soffit, { x: cx, y: (yA + yB) / 2 - 0.24, z: (zA + zB) / 2, parent });
  s.rotation.x = -ang;
  // walking surface: a ramp the player rides (steps are drawn, the ramp is felt)
  floorRegion({ x0, x1, z0: Math.min(zA, zB), z1: Math.max(zA, zB), za: zA, ya: yA, zb: zB, yb: yB });
}

// balusters and a handrail along the well edge of a flight
function railing(parent, x, zA, yA, zB, yB) {
  const m = mats(), n = 8;
  for (let i = 0; i <= n; i++) { const k = i / n, z = zA + (zB - zA) * k, y = yA + (yB - yA) * k; box(0.018, 0.92, 0.018, m.bar, { x, y: y + 0.46, z, parent, cast: false }); }
  const len = Math.hypot(zB - zA, yB - yA), ang = Math.atan2(yB - yA, zB - zA);
  const r = box(0.05, 0.04, len + 0.1, m.rail, { x, y: (yA + yB) / 2 + 0.92, z: (zA + zB) / 2, parent }); r.rotation.x = -ang;
}

// ---------------------------------------------------------------- the stairwell, floor by floor
const SKIP = new Set(['4:W', '4:E1', '4:E2', '5:W', '3:E1', '3:E2']); // doors that belong to flats built as zones
const LOCKED_TEXT = [
  'Locked.', 'Locked. A draught under it smells of cold ash.', 'Locked. Behind it a radio is playing to nobody — a waltz, very quietly.',
  'Locked. Someone has nailed it shut from this side.', 'Locked. The peephole is dark, and then it isn’t.', 'Locked. Through the letter flap: a hallway exactly like the Sokolovs’, with the same paper on the walls.',
  'Locked. Chalk on it: a number, crossed out, the same number written again.', 'It won’t open. It isn’t locked. It just won’t.',
];
let doorSeed = 3000;
function landingDoor(f, k, line, a0, a1, swing, hinge, opts = {}) {
  const id = `st${f}${k}`;
  const Y = floorY(f);
  const o = { id, line, a0, a1, y0: 0, y1: 2.08, kind: 'door', oy: Y, parent: FLOORS[f] };
  OPENINGS.push(o); openById[id] = o;
  const num = opts.num ?? String(flatNo(f, { W: 0, E1: 1, E2: 2, S: 3 }[k]));
  const r = rng(doorSeed++);
  const padded = r() < 0.55;
  const surface = opts.surface || (padded ? paddedDoorSurface(0.83, 2.05, doorSeed, '', ['#4a2a22', '#3a2a2e', '#2e2a24', '#5a3a2a'][(r() * 4) | 0]) : panelDoorSurface(0.83, 2.05, ['#8a7a6a', '#6a7a6a', '#7a6a5a', '#a89a88'][(r() * 4) | 0], doorSeed, {}));
  const text = opts.lockedText || LOCKED_TEXT[(r() * LOCKED_TEXT.length) | 0];
  const door = makeDoor({ id, hinge, swing, open: opts.open || 0, max: opts.max || 1.5, surface, thick: padded ? 0.07 : 0.045, speed: 3, liningMat: MAT.core,
    locked: opts.locked === false ? null : { prompt: () => 'Try the door', use: () => { sfx('click', door.world, { rate: 0.7 }); sfx('doorStuck', door.world, { vol: 0.4 }); G.ui.toast(typeof text === 'function' ? text() : text); opts.onTry?.(door); return true; } } });
  // the number plate, above the peephole on the landing side
  const plate = numberPlate(num);
  // which side of the leaf faces the landing? (local +z of the pivot, in the world)
  const lz = new THREE.Vector3(0, 0, 1).applyAxisAngle(new THREE.Vector3(0, 1, 0), door.psi0);
  const toLanding = { W: [1, 0], E1: [-1, 0], E2: [-1, 0], S: [0, -1] }[k];
  const out = lz.x * toLanding[0] + lz.z * toLanding[1] > 0 ? 1 : -1;
  door.pivot.add(plate); plate.position.set(door.w / 2, 1.78, out * 0.04); if (out < 0) plate.rotation.y = Math.PI;
  door.plate = plate; door.floor = f; door.k = k;
  // knock on it
  if (opts.locked !== false) interactive(plate, { prompt: () => 'Knock', range: 1.6, use: () => knockDoor(door) });
  return door;
}
function numberPlate(num) {
  const c = canvas(96, 48), g = c.getContext('2d');
  const draw = (n) => { g.fillStyle = '#b8a070'; g.fillRect(0, 0, 96, 48); g.strokeStyle = '#5a4a2a'; g.lineWidth = 4; g.strokeRect(2, 2, 92, 44); g.fillStyle = '#2a2014'; g.font = 'bold 30px Georgia'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(n, 48, 26); };
  draw(num);
  const t = canvasTex(c);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(0.12, 0.06), new THREE.MeshStandardMaterial({ map: t, roughness: 0.4, metalness: 0.6 }));
  m.userData.redraw = (n) => { draw(n); t.needsUpdate = true; };
  return m;
}
let knockN = 0;
function knockDoor(door) {
  const p = door.world;
  for (let i = 0; i < 3; i++) sfx('doorShut', p, { vol: 0.5, rate: 2.2, delay: i * 0.28 });
  knockN++;
  const answer = knockN % 3 === 2;
  setTimeout(() => {
    if (answer) { for (let i = 0; i < 3; i++) sfx('doorShut', p, { vol: 0.35, rate: 2.0, delay: i * 0.3 }); G.rumble?.(0.4, 200); setTimeout(() => G.ui.toast('Three knocks back, from the other side. Exactly at your height.'), 1200); }
    else G.ui.toast(['Nothing.', 'Nothing. Then, far below, a door closes.', 'The knocks go away down the stairwell and don’t come back.'][knockN % 3]);
  }, 1600);
}

// big stencilled floor numbers on the landing wall; the top two are redrawn by the loop
function floorSign(parent, f, Y) {
  const c = canvas(256, 256), g = c.getContext('2d');
  const draw = (n) => { g.clearRect(0, 0, 256, 256); g.fillStyle = 'rgba(30,34,30,0.85)'; g.font = 'bold 190px Impact, "Arial Black", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(String(n), 128, 136); g.globalCompositeOperation = 'destination-out'; for (let i = 0; i < 60; i++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.6})`; g.fillRect(Math.random() * 256, Math.random() * 256, 4 + Math.random() * 18, 2 + Math.random() * 8); } g.globalCompositeOperation = 'source-over'; };
  draw(f === 0 ? '0' : f);
  const t = canvasTex(c);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(0.7, 0.7), new THREE.MeshStandardMaterial({ map: t, transparent: true, roughness: 0.9 }));
  m.position.set(S.x1 - 0.01, Y + 1.95, 5.75); m.rotation.y = -Math.PI / 2; parent.add(m);
  m.userData.redraw = (n) => { draw(n); t.needsUpdate = true; };
  return m;
}

export const SIGNS = {}, LDOORS = {};
export function buildStairwell() {
  const m = mats();
  // the walls' lines (for the door builder)
  const lines = [
    { id: 'stW', axis: 'x', c: 10, p0: 10, p1: S.x0, a0: S.z0, a1: S.z1 },
    { id: 'stE', axis: 'x', c: S.x1 + 0.21, p0: S.x1, p1: S.x1 + EXT, a0: S.z0, a1: S.z1 },
    { id: 'stS', axis: 'z', c: S.z1 + 0.21, p0: S.z1, p1: S.z1 + EXT, a0: S.x0, a1: S.x1 },
  ];
  for (const l of lines) { LINES.push(l); lineById[l.id] = l; }
  const W = S.x1 - S.x0, Dz = S.z1 - S.z0;
  const DW = [4.12, 5.0], DE1 = [4.12, 5.0], DE2 = [6.42, 7.3], DS = [10.68, 11.55], WIN = [12.55, 13.65];
  for (const f of S.floors) {
    const Y = floorY(f), grp = new THREE.Group(); grp.userData.noBake = true; grp.userData.zone = 'stair' + f; G.scene.add(grp); FLOORS[f] = grp;
    // ---- walls of this storey band (Y .. Y+STOREY): holes for doors and the window
    const wm = f % 2 ? m.wall : m.wall2;
    const Hb = STOREY, door = (a, b) => ({ u0: a, u1: b, y0: 0, y1: 2.08, kind: 'door' });
    const top = f === S.floors[S.floors.length - 1];
    const bandH = top ? 2.9 : Hb;
    wallPlane(grp, Dz, bandH, f === 0 ? [] : [door(S.z1 - DW[1], S.z1 - DW[0])], wm, [S.x0, Y, S.z1], Math.PI / 2);               // west wall, faces +x
    wallPlane(grp, Dz, bandH, f === 0 ? [] : f === 3 || f === 4 ? [door(DE1[0], DE1[1])] : [door(DE1[0], DE1[1]), door(DE2[0], DE2[1])], wm, [S.x1, Y, S.z0], -Math.PI / 2);     // east wall, faces -x
    const southHoles = [door(S.x1 - DS[1], S.x1 - DS[0])];
    if (f === 1) southHoles.push({ u0: S.x1 - 13.75, u1: S.x1 - 12.45, y0: 0, y1: 2.25, kind: 'door' }); else if (f > 0) southHoles.push({ u0: S.x1 - WIN[1], u1: S.x1 - WIN[0], y0: 0.95, y1: 2.25, kind: 'window' });
    wallPlane(grp, W, bandH, southHoles, wm, [S.x1, Y, S.z1], Math.PI);                                                              // south wall, faces -z
    wallPlane(grp, W, bandH, [], wm, [S.x0, Y - HALF, S.z0], 0);                                                                     // north wall (half-landing side)
    if (f === 0) wallPlane(grp, W, HALF, [], wm, [S.x0, Y - 0.01, S.z0], 0);
    // cores behind the skins, for the sun's shadow map
    box(0.4, bandH, Dz, m.core, { x: S.x0 - 0.21, y: Y, base: true, z: (S.z0 + S.z1) / 2, parent: grp }).receiveShadow = false;
    box(0.4, bandH, Dz, m.core, { x: S.x1 + 0.21, y: Y, base: true, z: (S.z0 + S.z1) / 2, parent: grp }).receiveShadow = false;
    // ---- the landing slab and its underside
    const lz = (S.zl + S.z1) / 2, ld = S.z1 - S.zl;
    box(W, 0.22, ld, m.floor, { x: (S.x0 + S.x1) / 2, y: Y - 0.11, z: lz, parent: grp, uvs: 1 / 1.2 });
    floorRegion({ x0: S.x0, x1: S.x1, z0: S.zl, z1: S.z1, y: Y, zone: 'stair' + f });
    staticBox((S.x0 + S.x1) / 2, Y - 0.11, lz, W, 0.22, ld);
    zone({ key: 'stair' + f, name: f === 0 ? 'Basement' : f === 1 ? 'Entrance' : `Stairwell — floor ${f}`, x0: S.x0, x1: S.x1, z0: S.z0, z1: S.z1, y0: Y - HALF + 0.2, y1: Y + HALF + 0.2, group: grp, surface: 'concrete', stair: true, floor: f, sky: 0 });
    // ---- flights below this landing: west down to the half-landing, east on down to the floor below
    if (f > 0) {
      const Ym = Y - HALF;
      flight(grp, S.x0, S.wx1, S.zl, Y, S.zm, Ym);
      flight(grp, S.ex0, S.x1, S.zm, Ym, S.zl, Y - STOREY);
      box(W, 0.2, S.zm - S.z0, m.floor, { x: (S.x0 + S.x1) / 2, y: Ym - 0.1, z: (S.z0 + S.zm) / 2, parent: grp, uvs: 1 / 1.2 });
      floorRegion({ x0: S.x0, x1: S.x1, z0: S.z0, z1: S.zm, y: Ym });
      staticBox((S.x0 + S.x1) / 2, Ym - 0.1, (S.z0 + S.zm) / 2, W, 0.2, S.zm - S.z0);
      railing(grp, S.wx1 - 0.03, S.zl, Y, S.zm, Ym);
      railing(grp, S.ex0 + 0.03, S.zm, Ym, S.zl, Y - STOREY);
      // the half-landing window was bricked up years ago; you can see where
      // a radiator nobody has felt warm since the spring
      const rad = group({ x: (S.x0 + S.x1) / 2, y: Ym, z: S.z0 + 0.12, parent: grp });
      for (let i = 0; i < 10; i++) rbox(0.055, 0.5, 0.09, 0.02, M.radiator, { x: -0.3 + i * 0.065, y: 0.15, base: true, parent: rad });
      // the lamp on the half-landing
      const hl = box(0.2, 0.12, 0.08, mat('bulkHalf' + f, { color: 0x2a2a26, emissive: 0xffd8a0, emissiveIntensity: 0, roughness: 0.4 }), { x: (S.x0 + S.x1) / 2, y: Ym + 2.3, z: S.z0 + 0.05, parent: grp, static: false });
      fixture({ pos: V((S.x0 + S.x1) / 2, Ym + 2.1, S.z0 + 0.4), mesh: hl, range: 9, k: 9, color: 0xffd0a0, flicker: f % 3 === 0 ? 'dying' : 'bulb', on: f !== 6 && f !== 2 });
    }
    // the landing lamp, over the south door; some are dead
    const lm = box(0.24, 0.14, 0.08, mat('bulkLand' + f, { color: 0x2a2a26, emissive: [0xffd8a0, 0xfff0d8, 0xff8a60][f % 3], emissiveIntensity: 0, roughness: 0.4 }), { x: 11.1, y: Y + 2.45, z: S.z1 - 0.05, parent: grp, static: false });
    fixture({ pos: V(11.1, Y + 2.25, S.z1 - 0.4), mesh: lm, range: 10, k: f === 4 ? 9 : 13, color: [0xffd8a0, 0xfff0d8, 0xff8a60][f % 3], flicker: f === 4 ? 'dying' : f === 7 ? 'fluoro' : 'bulb', on: f !== 3 && f !== 8 });
    // ---- doors
    if (f > 0) {
      for (const [k, line, a0, a1, swing, hinge] of [['W', 'stW', DW[0], DW[1], 1, 'a0'], ['E1', 'stE', DE1[0], DE1[1], -1, 'a1'], ['E2', 'stE', DE2[0], DE2[1], -1, 'a1'], ['S', 'stS', DS[0], DS[1], -1, 'a0']]) {
        if (SKIP.has(`${f}:${k}`)) continue;
        LDOORS[`${f}:${k}`] = landingDoor(f, k, line, a0, a1, swing, hinge);
      }
    } else basement(grp, Y);
    SIGNS[f] = floorSign(grp, f, Y);
    // a top floor to the stairwell: a ceiling over landing 10
    if (top) box(W, 0.2, Dz, m.soffit, { x: (S.x0 + S.x1) / 2, y: Y + 2.9, base: true, z: (S.z0 + S.z1) / 2, parent: grp });
    landingDressing(grp, f, Y);
  }
  // walls: one collider each, full height, minus the door gaps (doors close them)
  const Hall = -16, Htop = 32;
  collider({ x: S.x0 - 0.21, z: (S.z0 + DW[0]) / 2, hx: 0.21, hz: (DW[0] - S.z0) / 2, y0: Hall, y1: Htop });
  collider({ x: S.x0 - 0.21, z: (DW[1] + S.z1) / 2, hx: 0.21, hz: (S.z1 - DW[1]) / 2, y0: Hall, y1: Htop });
  collider({ x: S.x1 + 0.21, z: (S.z0 + DE1[0]) / 2, hx: 0.21, hz: (DE1[0] - S.z0) / 2, y0: Hall, y1: Htop });
  collider({ x: S.x1 + 0.21, z: (DE1[1] + DE2[0]) / 2, hx: 0.21, hz: (DE2[0] - DE1[1]) / 2, y0: Hall, y1: Htop });
  collider({ x: S.x1 + 0.21, z: (DE2[1] + S.z1) / 2, hx: 0.21, hz: (S.z1 - DE2[1]) / 2, y0: Hall, y1: Htop });
  collider({ x: (S.x0 + S.x1) / 2, z: S.z0 - 0.21, hx: W / 2, hz: 0.21, y0: Hall, y1: Htop });
  collider({ x: (S.x0 + DS[0]) / 2, z: S.z1 + 0.21, hx: (DS[0] - S.x0) / 2, hz: 0.21, y0: Hall, y1: Htop });
  collider({ x: (DS[1] + 12.45) / 2, z: S.z1 + 0.21, hx: (12.45 - DS[1]) / 2, hz: 0.21, y0: Hall, y1: Htop });
  collider({ x: (13.75 + S.x1) / 2, z: S.z1 + 0.21, hx: (S.x1 - 13.75) / 2, hz: 0.21, y0: Hall, y1: Htop });
  const Y1 = floorY(1);
  collider({ x: 13.1, z: S.z1 + 0.21, hx: 0.65, hz: 0.21, y0: Hall, y1: Y1 - 0.3 });
  collider({ x: 13.1, z: S.z1 + 0.21, hx: 0.65, hz: 0.21, y0: Y1 + 2.2, y1: Htop });
  // the stairwell's west wall below floor 4 also backs the flats under 47: the door gaps there are doors
  // the well between the flights
  collider({ x: (S.wx1 + S.ex0) / 2, z: (S.zm + S.zl) / 2, hx: (S.ex0 - S.wx1) / 2 + 0.02, hz: (S.zl - S.zm) / 2, y0: Hall, y1: Htop });
  // the landing edges over the well
  lobby();
  street();
  stairLoop();
  buildLightPool();
}

// ---------------------------------------------------------------- what's left on the landings
function landingDressing(grp, f, Y) {
  const r = rng(1500 + f);
  // the rubbish chute hatch on the half-landing wall
  if (f > 0) { const ch = box(0.45, 0.35, 0.05, mat('chute', { map: metalTex('#5a5a50', 1.4, 1501).map, metalness: 0.5, roughness: 0.6 }), { x: 13.3, y: Y - HALF + 0.9, z: S.z0 + 0.03, parent: grp, static: false }); examine(ch, 'Rubbish chute', ['Welded shut.', 'The hatch is open an inch. Air comes up it, cold and moving, as if the shaft goes a long way further down than five floors.', 'Somebody has stuffed it with newspaper from the inside.'][f % 3]); }
  // electrical cupboard on the landing, door hanging open, the meters stopped
  const eb = group({ x: S.x1 - 0.06, y: Y + 1.4, z: 5.75 + 0.9, ry: -Math.PI / 2, parent: grp });
  box(0.7, 0.9, 0.12, mat('elecCab', { map: metalTex('#6a7068', 1.0, 1502).map, roughness: 0.6, metalness: 0.4 }), { parent: eb });
  if (r() < 0.5) { const d = box(0.7, 0.9, 0.02, mat('elecCab', {}), { x: -0.5, z: 0.25, ry: 1.2, parent: eb, static: false }); void d; }
  // things people left: a pram, a bag of rubbish, a pot plant long dead, a child's bike, chairs
  const pick = (r() * 6) | 0;
  if (pick === 0) { const p = group({ x: 13.3, y: Y, z: 7.4, ry: 0.4, parent: grp }); rbox(0.4, 0.35, 0.8, 0.08, mat('pram', { color: 0x2a3a4a, roughness: 0.7 }), { y: 0.45, base: true, parent: p }); for (const sx of [-0.2, 0.2]) for (const sz of [-0.3, 0.3]) cyl(0.12, 0.12, 0.03, 12, M.black, { x: sx, y: 0.12, z: sz, rz: Math.PI / 2, parent: p }); examine(p.children[0], 'Pram', 'Empty. A knitted blanket folded in it, very neatly, for later.'); }
  if (pick === 1) for (let i = 0; i < 3; i++) rbox(0.35, 0.4, 0.3, 0.1, mat('binBagIn', { color: 0x161616, roughness: 0.3 }), { x: 11.0 + i * 0.25, y: Y, base: true, z: 7.6, ry: r() * 3, parent: grp });
  if (pick === 2) { const c = group({ x: 13.4, y: Y, z: 6.0, ry: -Math.PI / 2, parent: grp }); box(0.42, 0.04, 0.42, M.veneer, { y: 0.44, parent: c }); for (const sx of [-0.18, 0.18]) for (const sz of [-0.18, 0.18]) box(0.035, 0.44, 0.035, M.veneer, { x: sx, y: 0.22, z: sz, parent: c }); box(0.4, 0.4, 0.03, M.veneer, { y: 0.68, z: -0.19, parent: c }); examine(c.children[0], 'Chair', 'Somebody brought a kitchen chair out here to sit on the landing and wait. It faces the stairs going down.'); }
  if (pick === 3) { const p = group({ x: 13.6, y: Y, z: 7.6, parent: grp }); cyl(0.14, 0.11, 0.25, 12, mat('terracotta', { color: 0x8a4a30, roughness: 0.9 }), { y: 0.125, parent: p }); for (let k = 0; k < 5; k++) cyl(0.004, 0.003, 0.6, 3, mat('deadStem', { color: 0x4a3a24 }), { y: 0.5, rz: (r() - 0.5), rx: (r() - 0.5), parent: p }); }
  // newspapers and post on the floor in front of doors nobody opened
  for (let i = 0; i < 3; i++) { const p = new THREE.Mesh(new THREE.PlaneGeometry(0.2, 0.28), M.paper); p.rotation.set(-Math.PI / 2, 0, r() * 6); p.position.set(S.x0 + 0.4 + r() * 3, Y + 0.004 + i * 0.001, S.zl + 0.4 + r() * 4); grp.add(p); }
  // floor 7: the door of 74 is open on a room full of chairs, all facing the door
  // floor 5: a child's drawing stuck to the wall at a child's height, the same one as in the box room
  if (f === 5) { const d = sheet(D.drawing, 0.3, 0.22, { x: S.x0 + 0.01, y: Y + 0.9, z: 6.6, ry: Math.PI / 2, parent: grp, name: 'Drawing' }); void d; }
}

// ---------------------------------------------------------------- basement (floor 0)
function basement(grp, Y) {
  // a steel door on the south wall, chained, wet underneath
  const d = group({ x: (10.68 + 11.55) / 2, y: Y, z: S.z1 - 0.04, parent: grp });
  const steel = mat('steelDoor', { map: metalTex('#4a4a44', 2.0, 1601).map, metalness: 0.6, roughness: 0.6 });
  box(0.9, 2.05, 0.06, steel, { y: 1.025, parent: d });
  for (let i = 0; i < 7; i++) { const l = new THREE.Mesh(new THREE.TorusGeometry(0.03, 0.007, 4, 8), mat('chainB', { color: 0x5a554e, metalness: 0.8, roughness: 0.5 })); l.position.set(0.3 - i * 0.04, 1.1 - Math.sin(i / 6 * Math.PI) * 0.08, -0.06); l.rotation.y = (i % 2) * 1.5; d.add(l); }
  const pud = new THREE.Mesh(new THREE.CircleGeometry(0.7, 20), mat('basePuddle', { color: 0x141412, roughness: 0.02, metalness: 0.3, transparent: true, opacity: 0.8 })); pud.rotation.x = -Math.PI / 2; pud.scale.set(1.4, 0.7, 1); pud.position.set(11.1, Y + 0.004, S.z1 - 0.6); grp.add(pud);
  collider({ x: 11.1, z: S.z1 - 0.04, hx: 0.45, hz: 0.04, y0: Y, y1: Y + 2.1 });
  let n = 0;
  interactive(d.children[0], {
    prompt: () => 'Basement door', range: 1.8,
    use: () => {
      n++; sfx('chainRattle', d.position, { vol: 0.9, rate: 0.7 });
      G.ui.toast(['Chained, and the chain is newer than the door. The water seeping under it is warm.', 'You knock without meaning to. Your knuckles do it.', 'From the other side, right up against the door: three, then three.'][Math.min(2, n - 1)]);
      if (n >= 2) setTimeout(() => knockSeq(V(11.1, Y + 1.2, S.z1 + 0.3), n >= 3 ? [3, 3] : [3], 0.9, 0), 900);
    },
  });
  // notice taped to it
  sheet(() => ({ canvas: (() => { const c = canvas(300, 200), g = c.getContext('2d'); g.fillStyle = '#e8e0c8'; g.fillRect(0, 0, 300, 200); g.fillStyle = '#8a1a14'; g.font = 'bold 34px Georgia'; g.textAlign = 'center'; g.fillText('DO NOT', 150, 70); g.fillText('GO DOWN', 150, 115); g.font = '16px Georgia'; g.fillStyle = '#2a2a2a'; g.fillText('— District Committee', 150, 165); return c; })(), text: 'DO NOT GO DOWN. — District Committee' }), 0.3, 0.2, { x: 11.1, y: Y + 1.55, z: S.z1 - 0.075, ry: Math.PI, parent: grp, name: 'Notice' });
}

// ---------------------------------------------------------------- the lobby (floor 1)
function lobby() {
  const Y = floorY(1), grp = FLOORS[1];
  // mailboxes on the east wall between the two doors: 47's stuffed full
  const mb = group({ x: S.x1 - 0.06, y: Y + 1.0, z: 5.7, ry: -Math.PI / 2, parent: grp });
  const steel = mat('mailbox', { map: metalTex('#5a6a6a', 1.2, 1701).map, metalness: 0.5, roughness: 0.6 });
  box(1.0, 0.9, 0.18, steel, { parent: mb });
  for (let row = 0; row < 4; row++) for (let col = 0; col < 5; col++) {
    const n = 35 + (3 - row) * 4 + col; // rough order
    const flap = box(0.17, 0.18, 0.01, mat('mbFlap', { color: 0x3a4444, metalness: 0.5, roughness: 0.5 }), { x: -0.4 + col * 0.2, y: 0.33 - row * 0.22, z: 0.095, parent: mb, static: false });
    if (n === 47) { flap.rotation.x = -0.6; const env = box(0.15, 0.08, 0.01, M.paper, { x: -0.4 + col * 0.2, y: 0.36 - row * 0.22, z: 0.12, rx: -0.4, parent: mb, static: false }); pickable(env, { name: 'Letters for 47', desc: 'Bills, a postcard from Kursk, and a letter to Sonya from her class: "Get well soon from 2B." All postmarked after the 15th. Somebody is still delivering the post.', mass: 0.05, sound: 'paper' }); }
  }
  // the noticeboard
  sheet(D.notice, 0.36, 0.5, { x: S.x0 + 0.012, y: Y + 1.5, z: 6.6, ry: Math.PI / 2, parent: grp, name: 'Notice' });
  // the street door: double, half-glazed, the glass white with what's outside
  const dg = group({ x: 13.1, y: Y, z: S.z1 + 0.06, parent: grp });
  const wood = mat('streetDoor', { map: woodTex('#5a4632', 1702, 1).map, roughness: 0.7 });
  const leaves = [];
  for (const s of [-1, 1]) {
    const pv = group({ x: s * 0.64, y: 0, z: 0, parent: dg });
    box(0.62, 2.2, 0.05, wood, { x: -s * 0.31, y: 1.1, parent: pv, static: false });
    const gl = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 0.9), mat('whiteGlass', { color: 0xffffff, emissive: 0xf4f4f0, emissiveIntensity: 1.4, roughness: 0.4 })); gl.position.set(-s * 0.31, 1.5, -0.03); gl.rotation.y = Math.PI; pv.add(gl);
    leaves.push(pv);
  }
  fixture({ pos: V(13.1, Y + 1.6, S.z1 - 0.6), k: 2.5, color: 0xf0f0ff, flicker: 'steady', range: 6 });
  let open = false, a = 0;
  const col = collider({ x: 13.1, z: S.z1 + 0.06, hx: 0.66, hz: 0.05, y0: Y, y1: Y + 2.2 });
  onUpdate((dt) => { a += ((open ? 1.4 : 0) - a) * Math.min(1, dt * 3); leaves[0].rotation.y = a; leaves[1].rotation.y = -a; col.on = a < 0.5; });
  interactive(dg, { prompt: () => (open ? 'Close the street door' : 'Open the street door'), range: 2, use: () => { open = !open; sfx(open ? 'doorCreak' : 'doorHeavy', V(13.1, Y + 1, S.z1), { rate: 0.8 }); if (open && !G.flags.streetSeen) { G.flags.streetSeen = true; setTimeout(() => G.ui.toast('White. Not fog: there is no grain to it, nothing moving in it. The step outside the door, and then nothing.'), 900); } } });
}

// ---------------------------------------------------------------- the street that isn't there
function street() {
  const Y = floorY(1);
  const grp = new THREE.Group(); grp.userData.zone = 'street'; G.scene.add(grp);
  // a porch step and a canopy, then white
  box(1.8, 0.2, 1.4, mats().step, { x: 13.1, y: Y - 0.1, z: S.z1 + 1.12, parent: grp });
  const white = new THREE.Mesh(new THREE.BoxGeometry(60, 30, 60), new THREE.MeshBasicMaterial({ color: 0xf2f2ee, side: THREE.BackSide, fog: false }));
  white.position.set(13.1, Y, S.z1 + 31); grp.add(white);
  const floorW = new THREE.Mesh(new THREE.PlaneGeometry(60, 60), new THREE.MeshBasicMaterial({ color: 0xe8e8e4, fog: false })); floorW.rotation.x = -Math.PI / 2; floorW.position.set(13.1, Y - 0.2, S.z1 + 31); grp.add(floorW);
  grp.visible = false;
  G.streetVoid = grp;
  floorRegion({ x0: 12.2, x1: 14.0, z0: S.z1, z1: S.z1 + 1.82, y: Y });
  floorRegion({ x0: -20, x1: 46, z0: S.z1 + 1.8, z1: 60, y: Y - 0.2 });
  zone({ key: 'street', name: '', x0: -20, x1: 46, z0: S.z1 + 0.43, z1: 60, y0: Y - 1, y1: Y + 4, group: grp, surface: 'concrete', sky: 0, street: true });
  // walk out into it and it gives you back
  onUpdate(() => {
    const p = G.playerPos; if (!p) return;
    const out = p.z > S.z1 + 0.4 && p.y < Y + 2 && p.y > Y - 2;
    grp.visible = out || (p.y > Y - 2 && p.y < Y + 3 && p.z > S.z1 - 3.5 && p.x > 11);
    if (out && p.z > S.z1 + 7 && !G.whiteout) {
      G.whiteout = 1.4;
      setTimeout(() => { G.teleport?.(13.1, S.z1 - 2.6, Y, Math.PI); G.addDecay?.(0.08); G.ui.toast('You walked out into it and came in through the door, facing the stairs. Your shoes are dry.', 6); }, 650);
    }
  });
}

// ---------------------------------------------------------------- the stairs that don't stop
// Above the top floor the stairs go on to a landing exactly like the one below it. Step onto it
// and you're back on the floor below — and the numbers on the wall go up by one.
function stairLoop() {
  let loops = 0;
  const T = S.top, Ytop = floorY(T), Ynext = floorY(T + 1);
  onUpdate(() => {
    const p = G.playerPos; if (!p) return;
    if (p.y > Ynext - 0.12 && p.z > S.zl + 0.3) {
      loops++;
      G.teleport?.(p.x, p.z, p.y - STOREY, null, true);
      SIGNS[T].userData.redraw(T + loops); SIGNS[T + 1].userData.redraw(T + 1 + loops);
      for (const k of ['W', 'E1', 'E2', 'S']) { const d1 = LDOORS[`${T}:${k}`]; if (d1) d1.plate.userData.redraw(String(flatNo(T + loops, { W: 0, E1: 1, E2: 2, S: 3 }[k]))); const d2 = LDOORS[`${T + 1}:${k}`]; if (d2) d2.plate.userData.redraw(String(flatNo(T + 1 + loops, { W: 0, E1: 1, E2: 2, S: 3 }[k]))); }
      G.addDecay?.(0.06);
      if (loops === 2) G.tip?.('loop');
      if (loops === 1) setTimeout(() => G.ui.toast(`The building has nine floors. The wall says ${T + 1}.`), 400);
      if (loops === 4) setTimeout(() => G.ui.toast('Somewhere below, on a landing you passed, a door opens.'), 800);
      if (loops === 7) setTimeout(() => G.ui.toast('Your legs are tired. The numbers keep going.'), 600);
    }
  });
  void Ytop;
}
