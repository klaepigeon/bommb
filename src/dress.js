// Dressing the flat: what the Sokolovs owned, where they left it, and what happened to it
// after. Living room, hallway, balcony and the fittings that run through the whole flat
// (switches, the fuse box, the torch). The other rooms are in dress2.js.
import * as THREE from 'three';
import { G, mat, box, cyl, group, solid, collider, staticBox, interactive, onUpdate, circuit, setCircuit, solidMat, sphere } from './core.js';
import { M, rbox, lathe, drape, crumple, drawer, cabDoor, carcass, book, bookRow, bottle, jar, can, labelMat, plate, cup, candle, frame, makeProp, pickable, photoTex } from './furniture.js';
import { addLight, wallSwitch, LIGHTS, powered, toggleLight } from './lighting.js';
import { sfx, loopSource, knockSeq, addTimer, AUDIO } from './audio.js';
import { woodTex, fabricTex, metalTex, rng, canvas, textSheet } from './textures.js';
import * as D from './docs.js';
import { DOORS } from './openings.js';
import { BALCONY, H } from './plan.js';
import { dressRest } from './dress2.js';
import { DUST } from './particles.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
const docMat = (doc) => new THREE.MeshStandardMaterial({ map: canvasTex(doc().canvas), roughness: 0.9, side: THREE.DoubleSide });
export function canvasTex(c) { const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
// a sheet of paper lying or pinned somewhere, readable in place
export function sheet(doc, w, h, o = {}) {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), docMat(doc));
  m.position.set(o.x, o.y, o.z); m.rotation.set(o.rx || 0, o.ry || 0, o.rz || 0, 'YXZ'); m.receiveShadow = true;
  (o.parent || G.scene).add(m);
  if (o.take) pickable(m, { name: o.name, desc: o.desc, mass: 0.05, sound: 'paper', doc, take: true, verb: 'Take' });
  else pickable(m, { name: o.name, read: doc, verb: 'Read', onRead: o.onRead });
  return m;
}
// a thing you can look at but not take: shows its description
export function examine(meshes, name, desc, o = {}) {
  return interactive(meshes, { prompt: () => o.prompt || 'Look at ' + name.toLowerCase(), use: () => { if (o.doc) G.ui.read(o.doc()); else G.ui.toast(desc, 6); o.onUse?.(); }, range: o.range || 1.8 });
}

export function dressFlat() {
  G.surfaceSpots = [
    { x: 2.6, z: 3.9, r: 0.75, kind: 'debris' }, { x: 7.75, z: 6.3, r: 0.85, kind: 'debris' },
    { x: 1.65, z: 0.35, r: 0.8, kind: 'glass' }, { x: 6.2, z: 0.25, r: 0.4, kind: 'glass' },
  ];
  torch();
  fixtures();
  living();
  hall();
  const pre = new Set(G.scene.children);
  balcony();
  for (const o of G.scene.children) if (!pre.has(o)) o.userData.outdoor = true;
  dressRest();
}

// ---------------------------------------------------------------- the torch
function torch() {
  const s = new THREE.SpotLight(0xffe2b8, 0, 14, 0.58, 0.65, 1.6);
  s.castShadow = true; s.shadow.mapSize.set(1024, 1024); s.shadow.bias = -0.0006; s.shadow.normalBias = 0.02; s.shadow.camera.near = 0.08;
  G.camera.add(s); s.position.set(0.16, -0.18, 0.05); s.target.position.set(0.05, -0.12, -3); G.camera.add(s.target);
  const T = { light: s, on: false, base: 26, k: 1, set(v) { T.on = v; } };
  G.torch = T;
  G.toggleTorch = () => { T.on = !T.on; sfx('click', null, { vol: 0.6 }); if (!G.flags.torchHint) G.flags.torchHint = true; };
  onUpdate((dt, t) => {
    // a cheap torch: it browns out and you have to give it a knock
    const w = T.on ? (0.92 + Math.sin(t * 13) * 0.015 + (Math.random() < dt * 0.15 ? -0.5 : 0)) : 0;
    T.k += (w - T.k) * Math.min(1, dt * 20);
    s.intensity = T.base * Math.max(0, T.k);
    s.shadow.autoUpdate = T.k > 0.01; // no shadow pass while it's off
  });
}

// ---------------------------------------------------------------- lights, switches, fuse box
function fixtures() {
  circuit('A', true); circuit('B', true); circuit('C', false);

  // living room: a three-arm brass chandelier, glass tulips; one bulb left
  {
    const g = group({ x: 2.2, y: H, z: 2.6 });
    const brass = mat('brassF', { color: 0x7a6240, metalness: 0.8, roughness: 0.4 });
    cyl(0.05, 0.05, 0.03, 12, brass, { y: -0.015, parent: g });
    cyl(0.006, 0.006, 0.5, 5, brass, { y: -0.28, parent: g });
    const shadeM = mat('tulip', { color: 0xe8dcc0, roughness: 0.3, transparent: true, opacity: 0.75, emissive: 0xffc890, emissiveIntensity: 0 });
    const bulbs = [];
    for (let i = 0; i < 3; i++) {
      const a = i * 2.094, arm = new THREE.Group(); arm.position.y = -0.52; arm.rotation.y = a; g.add(arm);
      box(0.28, 0.012, 0.012, brass, { x: 0.14, y: 0, parent: arm });
      const sh = lathe([[0.01, 0], [0.05, -0.02], [0.07, -0.1], [0.072, -0.13], [0.06, -0.11]], 12, i === 1 ? M.glass : shadeM, { x: 0.28, y: 0.03, parent: arm, static: false });
      sh.rotation.x = Math.PI; sh.position.y = -0.01;
      if (i === 2) sh.visible = false; // one shade gone (it's on the floor)
      bulbs.push(sh);
    }
    const l = new THREE.PointLight(0xffc88a, 14, 9, 2); l.position.set(2.2 + 0.28, H - 0.62, 2.6); l.shadow.mapSize.set(512, 512); l.shadow.bias = -0.002;
    addLight('chandelier', l, { circuit: 'A', on: false, flicker: 'bulb', fixtures: [bulbs[0]], emissive: 1.2 });
    wallSwitch(4.325, 1.4, 3.97, -Math.PI / 2, ['chandelier']);
  }
  // hall: a bare bulb on its flex
  {
    const flex = cyl(0.004, 0.004, 0.5, 4, M.black, { x: 7.3, y: H - 0.25, z: 4.5 });
    void flex;
    const bulbM = mat('bulbHall', { color: 0xfff0d0, emissive: 0xffd8a0, emissiveIntensity: 0, roughness: 0.2, transparent: true, opacity: 0.85 });
    const bulb = sphere(0.035, bulbM, { x: 7.3, y: H - 0.54, z: 4.5, static: false });
    cyl(0.018, 0.018, 0.05, 8, M.bakelite, { x: 7.3, y: H - 0.49, z: 4.5 });
    const l = new THREE.PointLight(0xffd29a, 9, 7, 2); l.position.set(7.3, H - 0.6, 4.5); l.userData.shadowTier = 'high'; l.shadow.mapSize.set(512, 512); l.shadow.bias = -0.002;
    addLight('hall', l, { circuit: 'A', on: true, flicker: 'dying', fixtures: [bulb], emissive: 3 });
    wallSwitch(9.99 - 0.005, 1.4, 3.97, -Math.PI / 2, ['hall']);
    wallSwitch(4.475, 1.4, 5.11, Math.PI / 2, ['hall']);
  }
  // emergency lamp over the front door: battery, nearly flat
  {
    const g = group({ x: 9.96, y: 2.28, z: 4.56, ry: -Math.PI / 2 });
    box(0.3, 0.09, 0.07, mat('emerBox', { color: 0xd8d4c4, roughness: 0.6 }), { parent: g, static: false });
    const lens = box(0.24, 0.05, 0.01, mat('emerLens', { color: 0xffffff, emissive: 0xfff2dc, emissiveIntensity: 0, roughness: 0.3 }), { z: 0.036, y: -0.01, parent: g, static: false });
    const led = sphere(0.006, mat('led', { color: 0x300000, emissive: 0xff1a0a, emissiveIntensity: 0 }), { x: 0.12, y: 0.03, z: 0.036, parent: g, static: false });
    const l = new THREE.PointLight(0xdfe6ff, 0.9, 5, 2); l.position.set(9.8, 2.2, 4.56);
    addLight('emergency', l, { on: true, flicker: 'emergency', fixtures: [lens], emissive: 0.8 });
    const L2 = addLight('led', new THREE.PointLight(0xff2010, 0.02, 0.5, 2), { on: true, flicker: 'beacon', fixtures: [led], emissive: 6, virtual: true });
    L2.l.position.set(9.9, 2.31, 4.66);
  }
  // fuse box by the door: three switches for three circuits, one tripped
  {
    const g = group({ x: 9.72, y: 1.55, z: 5.12, ry: Math.PI });
    const steel = mat('fuseSteel', { map: metalTex('#7a7a70', 0.6, 133).map, roughness: 0.6, metalness: 0.5 });
    box(0.36, 0.48, 0.1, steel, { z: 0.05, parent: g, static: false });
    box(0.32, 0.44, 0.01, mat('fuseBack', { color: 0x2a2a26, roughness: 0.9 }), { z: 0.101, parent: g, static: false });
    // door hanging open on one hinge
    const door = box(0.36, 0.48, 0.012, steel, { x: -0.36, z: 0.14, ry: -0.5, parent: g, static: false }); door.position.x = -0.33; door.rotation.y = 1.9; door.position.z = 0.2;
    // meter with its wheel
    const meter = box(0.14, 0.12, 0.05, mat('meter', { color: 0x1a1a18, roughness: 0.4 }), { y: 0.14, z: 0.13, parent: g, static: false });
    void meter;
    const labels = { A: 'Living room, hall', B: 'Kitchen, bathroom', C: 'Bedrooms' };
    const sw = {};
    ['A', 'B', 'C'].forEach((k, i) => {
      const s = box(0.045, 0.07, 0.035, mat('breaker', { color: 0xe0dccc, roughness: 0.5 }), { x: -0.09 + i * 0.09, y: -0.08, z: 0.12, parent: g, static: false });
      const lever = box(0.018, 0.03, 0.03, solidMat('breakerLever', 0x1a1a18, 0.4), { x: 0, y: 0.015, z: 0.025, parent: s, static: false });
      const sync = () => { lever.position.y = circuit(k).on ? 0.018 : -0.018; };
      sync(); sw[k] = sync;
      interactive([s, lever], {
        range: 1.6, prompt: () => `${circuit(k).on ? 'Switch off' : 'Switch on'} — ${labels[k]}`,
        use: () => {
          const on = !circuit(k).on;
          sfx('switch', g.position, { vol: 1, rate: 0.7 });
          if (on && k === 'C' && !G.flags.cTried) { G.flags.cTried = true; sfx('click', g.position); setTimeout(() => { sfx('switch', g.position, { rate: 0.6 }); G.ui.toast('It snaps back down. Something on that side is shorting.'); }, 260); return; }
          setCircuit(k, on); sync();
          if (on) { sfx('tvOn', g.position, { vol: 0.25, rate: 0.5 }); }
        },
      });
    });
    // wires out of the top, stapled up to the ceiling
    for (let i = 0; i < 3; i++) box(0.008, 1.0, 0.008, M.black, { x: -0.12 + i * 0.03, y: 0.73, z: 0.03, parent: g });
    examine(door, 'Fuse box', 'Bakelite fuses, one replaced with a twist of copper wire. The meter wheel isn’t turning.');
    // a shorted circuit: the second time you try C it holds
    G.flags.fuseLabels = labels;
  }
}

// ---------------------------------------------------------------- living room
function living() {
  const r = rng(1001);
  // radiator under the window: cast-iron sections, rust weeping at the joints
  radiator(1.65, 0.11, 12, 0);
  // curtains on a sagging rod: one panel torn half off, moving in the draught
  {
    box(2.2, 0.02, 0.02, M.chrome, { x: 1.65, y: 2.48, z: 0.12 });
    const curtM = mat('curtain', { map: fabricTex('#8a7a58', 140, 2).map, roughness: 1, side: THREE.DoubleSide, transparent: false });
    const panels = [];
    for (const [x, w, h, tear] of [[0.68, 0.55, 2.3, 0], [2.6, 0.5, 1.6, 1]]) {
      const geo = new THREE.PlaneGeometry(w, h, 10, 16); const p = geo.attributes.position;
      for (let i = 0; i < p.count; i++) { const px = p.getX(i), py = p.getY(i); p.setZ(i, Math.sin(px * 22) * 0.025); if (tear && py < -h * 0.2) p.setY(i, py + Math.sin(px * 30) * 0.08); }
      geo.computeVertexNormals();
      const m = new THREE.Mesh(geo, curtM); m.position.set(x, 2.46 - h / 2, 0.14); m.castShadow = true; m.receiveShadow = true;
      if (tear) m.rotation.z = 0.12; G.scene.add(m); panels.push(m);
      m.userData.base = geo.attributes.position.array.slice();
    }
    onUpdate((dt, t) => {
      const gust = 0.5 + 0.5 * Math.sin(t * 0.6) * Math.sin(t * 0.23);
      for (const m of panels) { const p = m.geometry.attributes.position, b = m.userData.base; for (let i = 0; i < p.count; i++) { const y = b[i * 3 + 1]; const k = (0.5 - y / 2.3); p.setZ(i, b[i * 3 + 2] + Math.sin(t * 1.7 + b[i * 3] * 6 + y * 2) * 0.03 * gust * k + gust * k * 0.08); } p.needsUpdate = true; }
    });
  }
  // sofa against the west wall: torn, the foam coming out, a blanket half on the floor
  {
    const g = group({ x: 0.45, z: 2.4, ry: Math.PI / 2 });
    rbox(2.0, 0.22, 0.8, 0.04, M.sofa, { y: 0.18, base: true, parent: g });
    rbox(2.0, 0.5, 0.2, 0.06, M.sofa, { y: 0.4, z: -0.32, base: true, parent: g });
    for (const s of [-1, 1]) rbox(0.18, 0.5, 0.8, 0.05, M.sofa, { x: s * 0.92, y: 0.18, base: true, parent: g });
    rbox(0.82, 0.14, 0.62, 0.05, M.sofa, { x: -0.42, y: 0.4, z: 0.06, base: true, parent: g });
    const c2 = rbox(0.82, 0.14, 0.62, 0.05, M.sofa, { x: 0.42, y: 0.38, z: 0.06, base: true, parent: g }); c2.rotation.z = -0.06;
    rbox(0.3, 0.12, 0.35, 0.05, M.foam, { x: 0.3, y: 0.46, z: 0.1, base: true, parent: g }); // foam through a split
    for (const s of [-0.85, 0.85]) cyl(0.025, 0.02, 0.1, 6, M.veneerDull, { x: s, y: 0, base: true, z: 0.3, parent: g });
    drape(1.4, 1.2, [{ x0: -0.6, x1: 0.2, z0: -0.35, z1: 0.35, top: 0.55 }], M.blanket, { x: 0.55, z: 2.6, y: 0, seed: 7, wrinkle: 0.05, fall: 2.2 });
    solid(0.45, 0, 2.4, 0.85, 0.6, 2.05);
    examine(c2, 'Sofa', 'The cushions are damp right through. Someone slept here, after — the dent is still in it, and the blanket is from the box room.');
  }
  // the family wall over the sofa: frames still hanging, two missing
  {
    const fs = [[0.02, 1.7, 2.6, 0.32, 0.42, 'family', 11, 'The three of them on the embankment. Sonya is maybe four.'], [0.02, 1.55, 2.05, 0.24, 0.3, 'baby', 12, 'A baby in a lace blanket. On the back, in pencil: "Sonya, 2 weeks."'], [0.02, 1.95, 3.05, 0.22, 0.28, 'old', 13, 'An old man in a cap, unsmiling. On the back: "Papa Pavel, Zavod 3, 1971."']];
    for (const [x, y, z, w, h, kind, seed, desc] of fs) {
      const f = frame(x + 0.012, y, z, Math.PI / 2, w, h, kind, seed, { frameMat: M.veneer });
      f.rotation.z = (r() - 0.5) * 0.06;
      examine(f, 'Photograph', desc);
    }
    // one face-down on the floor below the sofa, glass cracked
    const fd = frame(1.05, 0.012, 3.55, 0, 0.3, 0.38, 'wedding', 14, { frameMat: M.veneer });
    fd.rotation.set(-Math.PI / 2, 0, 0.4); fd.position.y = 0.012;
    makeProp(fd, { mass: 0.6, name: 'Wedding photograph', desc: 'Face down, the glass starred. Marta and Ilya, 1989. Someone pulled it off the wall — the nail came with it.', sound: 'glassTink', doc: () => ({ canvas: fd.userData.photo.userData.canvas, text: 'Marta and Ilya, 1989. On the back, in her hand: "Ilya, Marta. 14 July."' }) });
  }
  // coffee table on the rug: newspapers, an ashtray full, a glass with a skin of something
  {
    const rug = new THREE.Mesh(new THREE.PlaneGeometry(1.9, 2.7, 12, 12), M.rug); rug.rotation.x = -Math.PI / 2; rug.position.set(1.65, 0.006, 2.4); rug.receiveShadow = true;
    const p = rug.geometry.attributes.position; for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i); if (y > 1.0) p.setZ(i, Math.max(0, (y - 1.0) * 0.25 * (Math.sin(x * 4) + 1))); } // one end rucked up
    rug.geometry.computeVertexNormals(); G.scene.add(rug); rug.userData.static = true;
    const g = group({ x: 1.62, z: 2.6, ry: Math.PI / 2 });
    box(0.9, 0.03, 0.46, M.veneer, { y: 0.43, parent: g });
    for (const sx of [-0.4, 0.4]) for (const sz of [-0.18, 0.18]) box(0.04, 0.42, 0.04, M.veneer, { x: sx, y: 0, base: true, z: sz, parent: g });
    box(0.82, 0.015, 0.38, M.veneerDull, { y: 0.12, parent: g });
    solid(1.62, 0, 2.6, 0.46, 0.45, 0.9);
    staticBox(1.62, 0.445, 2.6, 0.46, 0.02, 0.9);
    const np = sheet(D.paperFront, 0.32, 0.43, { x: 1.58, y: 0.448, z: 2.4, rx: -Math.PI / 2, rz: 0.3, name: 'Newspaper' }); void np;
    const ash = lathe([[0, 0], [0.06, 0], [0.065, 0.025], [0.05, 0.025], [0.045, 0.008], [0, 0.008]], 14, mat('ashtray', { color: 0x4a5a4a, roughness: 0.2, metalness: 0.1 }), { x: 1.7, y: 0.445, z: 2.85, static: false });
    for (let i = 0; i < 6; i++) cyl(0.004, 0.004, 0.03, 5, mat('butt', { color: 0xc8b890, roughness: 0.9 }), { x: (r() - 0.5) * 0.06, y: 0.015, z: (r() - 0.5) * 0.06, rz: 1.5, ry: r() * 3, parent: ash, static: false });
    makeProp(ash, { mass: 0.5, name: 'Ashtray', desc: 'Belomorkanal, the cardboard tubes pinched flat. Twenty or thirty. Somebody sat up a long time.', sound: 'glassTink' });
    const gl = lathe([[0, 0], [0.03, 0], [0.034, 0.1], [0.031, 0.1], [0.027, 0.004], [0, 0.004]], 12, M.glass, { x: 1.5, y: 0.445, z: 2.75, static: false });
    makeProp(gl, { mass: 0.2, name: 'Glass', desc: 'A dried brown ring a third of the way up. It smells of nothing now.', sound: 'glassTink', breakable: true });
  }
  // the wall unit ("stenka"): veneer, glass, the good china, the television
  stenka(4.1, 2.1);
  // dining table by the window: dinner for three, never eaten; one chair thrown over
  {
    const tx = 2.4, tz = 1.35;
    const g = group({ x: tx, z: tz, ry: Math.PI / 2 });
    box(1.1, 0.035, 0.78, M.veneer, { y: 0.74, parent: g });
    for (const sx of [-0.5, 0.5]) for (const sz of [-0.33, 0.33]) box(0.05, 0.72, 0.05, M.veneer, { x: sx, y: 0, base: true, z: sz, parent: g });
    drape(1.2, 1.5, [{ x0: -0.39, x1: 0.39, z0: -0.55, z1: 0.55, top: 0.762 }], mat('tablecloth', { map: fabricTex('#d8d0b8', 141, 1).map, roughness: 1 }), { x: tx, z: tz, y: 0, seed: 4, wrinkle: 0.01, fall: 5, nx: 24, nz: 30 });
    solid(tx, 0, tz, 0.78, 0.78, 1.1);
    staticBox(tx, 0.765, tz, 0.78, 0.02, 1.1);
    const food = M.mould;
    plate(tx, 0.765, tz - 0.38, food, { bone: true }); plate(tx + 0.2, 0.765, tz + 0.12, food); plate(tx, 0.765, tz + 0.4, food);
    for (const [x, z] of [[tx - 0.15, tz - 0.38], [tx + 0.2, tz - 0.05], [tx - 0.15, tz + 0.4]]) box(0.17, 0.004, 0.012, M.chrome, { x, y: 0.768, z });
    const pot = cyl(0.1, 0.09, 0.12, 14, M.enamelCream, { x: tx - 0.15, y: 0.765, base: true, z: tz, static: false });
    cyl(0.1, 0.1, 0.012, 14, M.enamelCream, { y: 0.07, parent: pot, static: false });
    makeProp(pot, { mass: 1.2, name: 'Saucepan', desc: 'Buckwheat, set like cement. The lid was left on.', sound: 'metal' });
    const b = bottle(tx + 0.25, 0.765, tz + 0.42, M.greenGlass, { label: labelMat('mineral', '#d8d0a8', '#3a4a8a', 'BORJOMI', 'mineral water') });
    makeProp(b, { mass: 0.5, name: 'Bottle of mineral water', desc: 'Sealed. Water from a bottle, kept for the table. Nobody opened it.', sound: 'glassTink', breakable: true });
    const bread = rbox(0.18, 0.08, 0.1, 0.03, mat('bread', { color: 0x3a3a2a, roughness: 1, map: fabricTex('#4c4630', 142, 0).map }), { x: tx - 0.2, y: 0.765, base: true, z: tz + 0.15, ry: 1.3, static: false });
    makeProp(bread, { mass: 0.2, name: 'Bread', desc: 'Grey-green and light as pumice.', sound: 'soft' });
    // three chairs: two pushed back from the table, one thrown down by the window
    chair(tx + 0.62, tz + 0.1, -Math.PI / 2 + 0.25, false);
    chair(tx + 0.05, tz + 0.85, Math.PI + 0.15, false);
    chair(tx - 0.05, tz - 0.95, 0.4, true);
    // the cup from a fourth place: washed, upside-down, newer — someone came back and ate here
    const c4 = cup(tx + 0.25, 0.765, tz - 0.32, { mat: mat('cupBlue', { color: 0x3a5a8a, roughness: 0.3 }) }); c4.rotation.x = Math.PI; c4.position.y = 0.855;
    makeProp(c4, { mass: 0.25, name: 'Cup', desc: 'Clean. Turned upside down to keep the dust out. It’s not from this set.', sound: 'glassTink' });
  }
  // the bookcase that went over: lying across the floor, books spilled out of it
  {
    const g = carcass(0.8, 1.8, 0.3, M.veneerDull, { x: 0, y: 0, z: 0, shelves: [0.45, 0.9, 1.35], solid: false });
    g.position.set(1.15, 0.3, 0.75); g.rotation.set(Math.PI / 2 - 0.1, 0.0, Math.PI / 2 + 0.5, 'YXZ');
    g.rotation.set(-Math.PI / 2 + 0.12, 0.9, 0, 'YXZ');
    g.position.set(0.95, 0.3, 0.95);
    collider({ x: 0.75, z: 1.05, hx: 0.9, hz: 0.42, rot: 0.9 - Math.PI / 2, y0: 0, y1: 0.5 });
    staticBox(0.75, 0.15, 1.05, 1.8, 0.3, 0.8, 0.9 - Math.PI / 2);
    for (let i = 0; i < 22; i++) {
      const b = book(G.scene, 0.4 + r() * 1.6, 0.0, 0.3 + r() * 1.4, { seed: 500 + i, ry: r() * 6 });
      b.rotation.set(Math.PI / 2 * (r() < 0.6 ? 1 : 0) + (r() - 0.5) * 0.3, r() * 6.28, 0, 'YXZ'); b.position.y = 0.03;
      makeProp(b, { mass: 0.4, name: 'Book', desc: r() < 0.5 ? 'Swollen with damp, the pages fused into a block.' : pickR(r, BOOKS), sound: 'paper' });
    }
  }
  // the barricade: a heavy wardrobe pushed across the box-room door
  {
    const g = carcass(1.0, 1.9, 0.55, M.veneerDull, { x: 0, y: 0, z: 0, solid: false, shelves: [1.2] });
    cabDoor(g, -0.49, 0.95, 0.49, 1.84, M.veneerDull, 1, { z: 0.285, locked: 'Open', lockedMsg: 'Something heavy has slid down inside and wedged the doors.' });
    cabDoor(g, 0.49, 0.95, 0.49, 1.84, M.veneerDull, -1, { z: 0.285, locked: 'Open', lockedMsg: 'Something heavy has slid down inside and wedged the doors.' });
    g.position.set(1.95, 0.005, 4.84); g.rotation.y = Math.PI;
    const p = makeProp(g, { mass: 70, name: 'Wardrobe', push: true, pick: false, sound: 'woodHeavy', damp: 0.92, adamp: 0.99, size: [1.0, 1.9, 0.55] });
    p.body.fixedRotation = true; p.body.updateMassProperties();
    // scrape marks on the parquet where it was dragged into place
    for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.015), mat('scrape', { color: 0xa08a68, roughness: 1, transparent: true, opacity: 0.5 })); m.rotation.set(-Math.PI / 2, 0, 0.08); m.position.set(2.55, 0.004, 4.6 + i * 0.13); G.scene.add(m); }
    G.flags.barricade = p;
  }
  // the armchair under the collapse, smashed into the floor by the falling ceiling
  {
    const g = group({ x: 2.55, z: 3.85, ry: -2.4 });
    rbox(0.75, 0.3, 0.7, 0.06, M.chairFab, { y: 0.0, base: true, parent: g, rz: 0.12 });
    rbox(0.75, 0.5, 0.18, 0.06, M.chairFab, { y: 0.15, z: -0.3, base: true, parent: g, rx: -0.5 });
    rbox(0.14, 0.35, 0.7, 0.05, M.chairFab, { x: -0.36, y: 0.05, base: true, parent: g, rz: -0.3 });
  }
  // lampshade from the chandelier, on the floor
  {
    const sh = lathe([[0.01, 0], [0.05, -0.02], [0.07, -0.1], [0.072, -0.13], [0.06, -0.11]], 12, mat('tulip', {}), { x: 2.4, y: 0.07, z: 3.1, rz: 1.4, static: false });
    makeProp(sh, { mass: 0.2, name: 'Glass shade', desc: 'From the light over the table. Unbroken.', sound: 'glassTink', breakable: true });
  }
  // a floor lamp, a wall clock that stopped
  {
    const g = group({ x: 0.3, z: 1.05 });
    cyl(0.14, 0.16, 0.03, 16, M.bakelite, { y: 0.015, parent: g, static: false });
    cyl(0.012, 0.012, 1.45, 6, M.chrome, { y: 0.75, parent: g, static: false });
    lathe([[0.08, 0], [0.2, -0.24], [0.21, -0.25]], 16, mat('lampShade', { color: 0xc8a878, roughness: 1, side: THREE.DoubleSide, map: fabricTex('#c8a878', 143, 0).map }), { y: 1.7, parent: g, static: false });
    makeProp(g, { mass: 4, name: 'Standard lamp', sound: 'metal', pick: true, push: false, size: [0.32, 1.72, 0.32] });
    const clock = group({ x: 0.015, y: 2.05, z: 0.55, ry: Math.PI / 2 });
    cyl(0.16, 0.16, 0.04, 24, M.veneer, { rx: Math.PI / 2, parent: clock });
    const face = new THREE.Mesh(new THREE.CircleGeometry(0.135, 24), new THREE.MeshStandardMaterial({ map: clockFace(5, 52), roughness: 0.6 })); face.position.z = 0.021; clock.add(face);
    examine(face, 'Wall clock', 'Stopped at eight minutes to six. The battery has leaked white crust down the back.');
  }
  // the TV in the wall unit is wired in stenka(); rubbish blown in through the window
  for (let i = 0; i < 16; i++) { const leaf = new THREE.Mesh(new THREE.CircleGeometry(0.03 + r() * 0.03, 5), mat('leaf' + (i % 3), { color: [0x4a3a20, 0x5a4020, 0x3a3018][i % 3], roughness: 1, side: THREE.DoubleSide })); leaf.rotation.set(-Math.PI / 2, 0, r() * 6); leaf.scale.y = 0.6; leaf.position.set(0.7 + r() * 2.6, 0.006, 0.15 + r() * 0.9); G.scene.add(leaf); leaf.userData.static = true; }
  // the newspaper the wind keeps moving
  crumple(3.6, 3.3, 0.5, 0.4, M.paper, 31, { wrinkle: 0.03 });
  // a light shaft from the broken window, catching dust
  DUST.shafts.push({ min: V(0.75, 0.0, 0.0), max: V(2.55, 2.35, 1.5), col: V(0.16, 0.18, 0.22) });
}
const BOOKS = ['Tolstoy, Sevastopol Sketches. A bus ticket marking page 40.', 'A school atlas. Someone has drawn a ring round Kerzhansk in biro.', 'The Home Book of Preserving. A recipe page splashed and dried.', 'Collected Pushkin, volume 2. An inscription: "To Marta, from her class, 1986."', 'Repair Manual: ZIL refrigerators.', 'Russian–English dictionary. A pressed leaf at "water".'];
function pickR(r, a) { return a[(r() * a.length) | 0]; }

function clockFace(h, m) {
  const c = canvas(256, 256), g = c.getContext('2d');
  g.fillStyle = '#e8e0c8'; g.fillRect(0, 0, 256, 256);
  g.fillStyle = '#2a2420'; g.font = 'bold 26px Georgia'; g.textAlign = 'center'; g.textBaseline = 'middle';
  for (let i = 1; i <= 12; i++) { const a = i / 12 * 6.283 - 1.5708; g.fillText(String(i), 128 + Math.cos(a) * 96, 128 + Math.sin(a) * 96); }
  const hand = (a, len, w) => { g.lineWidth = w; g.beginPath(); g.moveTo(128, 128); g.lineTo(128 + Math.cos(a - 1.5708) * len, 128 + Math.sin(a - 1.5708) * len); g.stroke(); };
  g.strokeStyle = '#1a1410'; hand((h + m / 60) / 12 * 6.283, 55, 7); hand(m / 60 * 6.283, 82, 4);
  g.fillStyle = 'rgba(200,190,160,0.6)'; g.beginPath(); g.ellipse(170, 190, 60, 30, 0.4, 0, 6.28); g.fill(); // water got in
  return canvasTex(c);
}

export function radiator(x, z, n, ry, o = {}) {
  const g = group({ x, z, ry });
  const w = n * 0.065;
  for (let i = 0; i < n; i++) {
    const sx = -w / 2 + i * 0.065 + 0.032;
    rbox(0.055, 0.58, 0.1, 0.02, M.radiator, { x: sx, y: 0.16, base: true, parent: g });
  }
  cyl(0.016, 0.016, w + 0.15, 8, M.rust, { x: 0, y: 0.2, rz: Math.PI / 2, parent: g });
  cyl(0.016, 0.016, w + 0.15, 8, M.rust, { x: 0, y: 0.7, rz: Math.PI / 2, parent: g });
  // the riser up the wall
  cyl(0.016, 0.016, 2.6, 8, M.rust, { x: w / 2 + 0.12, y: 1.4, z: -0.02, parent: g });
  solid(x, 0, z, Math.abs(Math.cos(ry)) * w + Math.abs(Math.sin(ry)) * 0.12, 0.75, Math.abs(Math.sin(ry)) * w + Math.abs(Math.cos(ry)) * 0.12);
  // you can knock on the pipes. something knocks back
  const pipe = g.children[g.children.length - 1];
  interactive(pipe, { prompt: () => 'Knock on the pipe', use: () => knockOnPipe(pipe.getWorldPosition(new THREE.Vector3())), range: 1.5 });
  return g;
}

let knocks = 0, replyAt = 0;
function knockOnPipe(pos) {
  if (performance.now() < replyAt) return;
  const n = 3; for (let i = 0; i < n; i++) sfx('knock', pos, { vol: 0.9, delay: i * 0.3, room: G.playerRoom });
  knocks++;
  replyAt = performance.now() + 9000;
  if (!G.flags.knockHint && knocks === 1) G.flags.knockHint = true;
  // after a wait: an answer, from somewhere in the walls, a little different each time
  const answers = [[3, 3], [3], [1], [3, 3, 3]];
  const ans = knocks > 3 ? [1] : answers[(knocks - 1) % answers.length];
  const where = [V(9.9, 1.0, 0.3), V(-0.3, 1.5, 3.0), V(4.4, 3.4, 2.0), V(7.0, -0.4, 6.5)][knocks % 4];
  setTimeout(() => {
    const t = knockSeq(where, ans, 0.75);
    if (knocks === 2) setTimeout(() => sfx('stepAbove', V(G.camera.position.x, 3.2, G.camera.position.z), { vol: 1, room: 'above' }), (t + 1.5) * 1000);
    if (knocks === 4) setTimeout(() => G.ui.toast('Nothing answers. The flat feels listened to.'), (t + 2) * 1000);
  }, 2600 + Math.random() * 2200);
}

function chair(x, z, ry, fallen) {
  const g = group({ x, z, ry });
  box(0.42, 0.035, 0.42, M.veneer, { y: 0.44, parent: g, static: false });
  for (const sx of [-0.18, 0.18]) for (const sz of [-0.18, 0.18]) box(0.035, 0.44, 0.035, M.veneer, { x: sx, y: 0, base: true, z: sz, parent: g, static: false });
  for (const sx of [-0.18, 0.18]) box(0.035, 0.48, 0.035, M.veneer, { x: sx, y: 0.46, base: true, z: -0.19, parent: g, static: false });
  box(0.4, 0.12, 0.02, M.veneer, { y: 0.84, z: -0.19, parent: g, static: false });
  rbox(0.38, 0.05, 0.38, 0.015, M.chairFab, { y: 0.47, parent: g, static: false });
  if (fallen) { g.rotation.set(-Math.PI / 2 + 0.05, ry, 0, 'YXZ'); g.position.y = 0.2; }
  return makeProp(g, { mass: 5, name: 'Chair', sound: 'wood', push: true, pick: true, shapes: [{ size: [0.42, 0.48, 0.42], at: [0, 0.24, 0] }, { size: [0.42, 0.44, 0.06], at: [0, 0.7, -0.19] }], size: [0.44, 0.9, 0.44] });
}
export { chair };

// ---------------------------------------------------------------- the wall unit
function stenka(x, z) {
  const W = 2.4, Hh = 2.2, Dd = 0.45;
  const g = group({ x, z, ry: -Math.PI / 2 });
  // three tall carcasses side by side
  const sec = W / 3;
  const parts = [];
  for (let i = 0; i < 3; i++) {
    const cx = -W / 2 + sec / 2 + i * sec;
    const c = carcass(sec, Hh, Dd, M.veneer, { x: 0, y: 0, z: 0, plinth: 0.06, shelves: [0.75, 1.45], solid: false, parent: g });
    c.position.set(cx, 0, 0); parts.push(c);
  }
  solid(x, 0, z, Dd, Hh, W, 0);
  // static shelves for props (world frame: the unit runs along z, front faces -x)
  for (const y of [0.75, 1.45, 2.2, 0.08]) staticBox(x, y, z, Dd, 0.02, W);
  // lower cabinets: doors on the sides, drawers in the middle
  const [L, C, R] = parts;
  for (const p of [L, R]) {
    cabDoor(p, -sec / 2 + 0.01, 0.4, sec / 2 - 0.015, 0.66, M.veneer, 1, { z: Dd / 2 + 0.01 });
    cabDoor(p, sec / 2 - 0.01, 0.4, sec / 2 - 0.015, 0.66, M.veneer, -1, { z: Dd / 2 + 0.01 });
  }
  const dr1 = drawer(C, 0, 0.6, sec - 0.03, 0.26, Dd - 0.03, M.veneer, { z: Dd / 2 });
  const dr2 = drawer(C, 0, 0.27, sec - 0.03, 0.36, Dd - 0.03, M.veneer, { z: Dd / 2, stuck: 'It sticks, swollen. It comes out halfway.' });
  // drawer contents: the photo album (photos taken out of it), papers, a torch battery
  {
    const album = rbox(0.24, 0.05, 0.3, 0.01, mat('album', { color: 0x5a2a20, roughness: 0.8, map: fabricTex('#5a2a20', 150, 0).map }), { x: -0.05, y: -0.1, z: -0.18, parent: dr1, static: false });
    pickable(album, { name: 'Photo album', desc: 'Most of the pages are empty: grey card with little paper corners where the photographs were. Somebody took them out carefully, one by one.', mass: 0.6, sound: 'paper' });
    const docs = box(0.2, 0.02, 0.28, M.paper, { x: 0.08, y: -0.11, z: -0.2, parent: dr1, static: false });
    pickable(docs, { name: 'Papers', desc: 'Rent book, electricity book, Sonya’s birth certificate. The passports aren’t here.', mass: 0.2, sound: 'paper' });
    const candleBox = box(0.12, 0.04, 0.06, M.cardboard, { x: 0.0, y: -0.1, z: -0.25, parent: dr2, static: false });
    pickable(candleBox, { name: 'Box of candles', desc: 'Empty. There should be twelve.', mass: 0.1, sound: 'paper' });
  }
  // middle: TV niche in the centre, glass showcases either side
  tv(C, Dd);
  for (const [p, broken] of [[L, false], [R, true]]) {
    cabDoor(p, -sec / 2 + 0.01, 1.1, sec / 2 - 0.015, 0.68, M.veneer, 1, { z: Dd / 2 + 0.01, glass: true, broken, knob: false, open: broken ? 0.9 : 0 });
    cabDoor(p, sec / 2 - 0.01, 1.1, sec / 2 - 0.015, 0.68, M.veneer, -1, { z: Dd / 2 + 0.01, glass: true, knob: false });
    box(sec - 0.04, 0.005, Dd - 0.04, M.mirror, { y: 1.101, z: 0, parent: p }); // mirrored back shelf
  }
  // the good china and the crystal (on L), the rest looted or smashed (R)
  for (let i = 0; i < 4; i++) {
    const cp = cup(-0.2 + i * 0.13, 0.765, 0.05, { parent: L, mat: mat('china', { color: 0xe8e0d0, roughness: 0.25 }) });
    void cp;
  }
  for (let i = 0; i < 3; i++) lathe([[0, 0], [0.03, 0], [0.012, 0.06], [0.01, 0.12], [0.035, 0.18], [0.034, 0.2], [0, 0.14]], 10, M.glass, { x: -0.2 + i * 0.18, y: 0.765, z: -0.1, parent: L });
  const tureen = lathe([[0, 0], [0.06, 0], [0.11, 0.06], [0.12, 0.12], [0.1, 0.14], [0.02, 0.16], [0, 0.17]], 16, mat('chinaFlower', { color: 0xe8e0d0, roughness: 0.25 }), { x: 0, y: 1.465, z: 0, parent: L, static: false });
  makeProp(tureen, { mass: 1.4, name: 'Soup tureen', desc: 'Cobalt and gold, the wedding set. Too good ever to use.', sound: 'glassTink', breakable: true });
  // R: shelf swept clear, broken glass on its floor
  for (let i = 0; i < 8; i++) { const s = new THREE.Mesh(new THREE.CircleGeometry(0.02 + Math.random() * 0.03, 3), M.glass); s.rotation.x = -Math.PI / 2; s.position.set(-0.3 + Math.random() * 0.6, 0.77, Math.random() * 0.3 - 0.1); R.add(s); }
  // top: books, a small photo frame, a doll in national dress
  bookRow(L, -0.36, 0.36, 1.465, -0.05, 41);
  const f = frame(0.2, 1.62, -0.02, 0, 0.16, 0.2, 'sea', 15, { parent: R, frameMat: M.chrome }); f.rotation.x = -0.12;
  examine(f, 'Photograph', 'The three of them at the sea. Sonya on Ilya’s shoulders, both of them squinting. On the back: "Crimea. S. 5."');
  const doll = group({ x: -0.15, y: 1.465, z: 0, parent: R });
  lathe([[0, 0], [0.05, 0], [0.04, 0.12], [0.02, 0.15], [0, 0.15]], 10, mat('dollDress', { color: 0x9a2a22, roughness: 0.8 }), { parent: doll, static: false });
  sphere(0.025, mat('dollFace', { color: 0xe0c8a8, roughness: 0.6 }), { y: 0.17, parent: doll, static: false });
  makeProp(doll, { mass: 0.3, name: 'Doll', desc: 'A souvenir doll in a red sarafan. Her face has been turned to the wall — no: she has been put back facing the wall, carefully, more than once. The dust shows it.', sound: 'soft' });
  // upper cupboards
  for (const p of parts) {
    cabDoor(p, -sec / 2 + 0.01, 1.82, sec - 0.03, 0.7, M.veneer, 1, { z: Dd / 2 + 0.01 });
  }
  bookRow(C, -0.34, 0.34, 1.465, -0.05, 42, { gaps: 0.15 });
  const tins = can(0.15, 1.465, 0.05, labelMat('tea', '#2a5a3a', '#e8d890', 'ЧАЙ', 'Georgian No.1'), { parent: parts[1] });
  void tins;
}

// ---------------------------------------------------------------- the television
function tv(parent, Dd) {
  const g = group({ x: 0, y: 0.77, z: 0.02, parent });
  const body = box(0.62, 0.48, 0.42, mat('tvCase', { map: woodTex('#3a2618', 160, 1).map, roughness: 0.5 }), { y: 0.24, parent: g, static: false });
  box(0.56, 0.42, 0.02, M.black, { y: 0.24, z: 0.205, parent: g, static: false });
  // the screen: a curved-looking glass over a canvas we draw into
  const sc = canvas(160, 120), sg = sc.getContext('2d');
  sg.fillStyle = '#0a0c0c'; sg.fillRect(0, 0, 160, 120);
  const tex = canvasTex(sc); tex.minFilter = THREE.LinearFilter;
  const screenM = new THREE.MeshStandardMaterial({ color: 0x0c0e0e, roughness: 0.15, metalness: 0.2, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: 0 });
  const geo = new THREE.PlaneGeometry(0.44, 0.34, 8, 8); const p = geo.attributes.position;
  for (let i = 0; i < p.count; i++) p.setZ(i, 0.02 - (p.getX(i) ** 2 + p.getY(i) ** 2) * 0.18);
  geo.computeVertexNormals();
  const screen = new THREE.Mesh(geo, screenM); screen.position.set(-0.04, 0.26, 0.2); g.add(screen);
  const knob = cyl(0.018, 0.018, 0.02, 12, M.chrome, { x: 0.24, y: 0.32, z: 0.215, rx: Math.PI / 2, parent: g, static: false });
  const knob2 = cyl(0.018, 0.018, 0.02, 12, M.chrome, { x: 0.24, y: 0.22, z: 0.215, rx: Math.PI / 2, parent: g, static: false });
  void knob2;
  box(0.3, 0.004, 0.004, M.chrome, { x: -0.1, y: 0.5, z: 0.0, rz: 0.6, parent: g, static: false }); // rabbit ears
  box(0.3, 0.004, 0.004, M.chrome, { x: 0.1, y: 0.5, z: 0.0, rz: -0.6, parent: g, static: false });
  const glow = new THREE.PointLight(0x9fb8d8, 2.5, 5, 2); glow.position.set(0, 0, 0.6);
  const wp = new THREE.Vector3(); screen.getWorldPosition(wp);
  const L = addLight('tv', glow, { circuit: 'A', on: false, flicker: 'tv', fixtures: [screen], emissive: 1.0 });
  G.scene.updateMatrixWorld(true); screen.getWorldPosition(wp); glow.position.copy(wp).add(new THREE.Vector3(-0.5, 0, 0));
  let staticSnd = null, card = 0, cardT = 6 + Math.random() * 6, frameT = 0, tone = null;
  const img = sg.createImageData(160, 120);
  const draw = (dt) => {
    frameT -= dt; if (frameT > 0) return; frameT = 1 / 20;
    if (card > 0) {
      sg.fillStyle = '#1a2a4a'; sg.fillRect(0, 0, 160, 120); sg.fillStyle = '#e8e8e0'; sg.textAlign = 'center';
      sg.font = 'bold 11px Arial'; sg.fillText('CIVIL DEFENCE', 80, 22); sg.fillRect(20, 28, 120, 1);
      sg.font = 'bold 13px Arial'; sg.fillText('REMAIN INDOORS', 80, 52); sg.font = '10px Arial'; sg.fillText('DO NOT USE TAP WATER', 80, 72); sg.fillText('DO NOT ANSWER', 80, 88); sg.fillText('AWAIT INSTRUCTIONS', 80, 104);
      for (let y = 0; y < 120; y += 2) { sg.fillStyle = 'rgba(0,0,0,0.25)'; sg.fillRect(0, y, 160, 1); }
    } else {
      for (let i = 0; i < img.data.length; i += 4) { const v = Math.random() * 230; img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255; }
      sg.putImageData(img, 0, 0);
      const roll = (G.time * 40) % 120; sg.fillStyle = 'rgba(255,255,255,0.12)'; sg.fillRect(0, roll, 160, 10);
    }
    tex.needsUpdate = true;
  };
  onUpdate((dt) => {
    if (!powered(L)) { if (staticSnd) { staticSnd.stop(); staticSnd = null; } if (tone) { tone.stop(); tone = null; } return; }
    if (!staticSnd && AUDIO.ready) staticSnd = loopSource('static', wp, { vol: 0.12 });
    cardT -= dt;
    if (card > 0) { card -= dt; if (card <= 0) { cardT = 14 + Math.random() * 20; if (tone) { tone.stop(); tone = null; } staticSnd?.set(0.12); } }
    else if (cardT <= 0) { card = 4 + Math.random() * 2; staticSnd?.set(0.0); if (AUDIO.ready) { tone = loopSource('hum', wp, { vol: 0 }); tone.nodes[0].frequency.value = 1000; tone.nodes[1].frequency.value = 1000; tone.set(0.04); } G.flags.sawCard = true; }
    draw(dt);
  });
  interactive([body, knob, screen], {
    prompt: () => (L.switched ? 'Switch the television off' : 'Switch the television on'),
    use: () => {
      toggleLight(L);
      sfx(L.switched ? 'tvOn' : 'click', wp, { vol: 0.7 });
      if (L.switched && !powered(L)) G.ui.toast('The knob clicks round. No power.');
      if (!L.switched) { screenM.emissiveIntensity = 0; }
    },
  });
}

// ---------------------------------------------------------------- hallway
function hall() {
  const r = rng(2002);
  // coat hooks: his work jacket still here. hers and Sonya's are gone; one empty hook bent down
  {
    box(0.9, 0.08, 0.02, M.veneer, { x: 9.5, y: 1.72, z: 3.885 });
    for (let i = 0; i < 5; i++) { const hk = box(0.012, 0.05, 0.06, M.chrome, { x: 9.12 + i * 0.19, y: 1.72, z: 3.92 }); if (i === 3) hk.rotation.x = 0.8; }
    const jacket = group({ x: 9.12, y: 1.7, z: 3.95 });
    const jm = mat('workJacket', { map: fabricTex('#3a4034', 170, 0).map, roughness: 1 });
    rbox(0.42, 0.75, 0.14, 0.06, jm, { y: -0.4, parent: jacket });
    for (const s of [-1, 1]) rbox(0.1, 0.62, 0.11, 0.04, jm, { x: s * 0.2, y: -0.42, z: 0.01, rz: s * 0.06, parent: jacket });
    examine(jacket.children[0], 'Work jacket', 'A padded quilted jacket, the kind they give out at the plant. The pockets are empty except for the pass. It is dry, and it smells of the plant: hot oil and something chemical.', { prompt: 'Search the jacket', onUse: () => { if (!G.flags.pass) { G.flags.pass = true; givePass(jacket); } } });
    const scarf = drape(0.25, 0.7, [{ x0: -0.05, x1: 0.05, z0: -0.35, z1: -0.25, top: 1.74 }], M.cloth[2], { x: 9.5, z: 3.97, y: 0, seed: 3, fall: 6, nx: 6, nz: 16 });
    scarf.rotation.x = 0;
    // umbrella hooked by its handle
    const um = cyl(0.03, 0.012, 0.8, 8, M.cloth[4], { x: 9.88, y: 1.3, z: 3.97 });
    void um;
  }
  // shoe rack: his boots, wet; slippers; one small red shoe on its own
  {
    const g = group({ x: 9.45, z: 4.07 });
    box(0.8, 0.02, 0.3, M.pine, { y: 0.12, parent: g }); box(0.8, 0.02, 0.3, M.pine, { y: 0.32, parent: g });
    for (const s of [-0.39, 0.39]) box(0.02, 0.34, 0.3, M.pine, { x: s, y: 0, base: true, parent: g });
    solid(9.45, 0, 4.07, 0.8, 0.34, 0.3);
    const wetM = mat('wetBoot', { color: 0x1e1a16, roughness: 0.15, metalness: 0.1 });
    for (const s of [-0.06, 0.06]) { const b = group({ x: 9.15 + s, y: 0.02, z: 4.3 }); rbox(0.1, 0.07, 0.28, 0.03, wetM, { y: 0, base: true, parent: b }); rbox(0.1, 0.22, 0.12, 0.03, wetM, { y: 0.05, base: true, z: -0.08, parent: b }); makeProp(b, { mass: 1, name: 'Boot', desc: 'Rubber work boots. The mud on them is still wet.', sound: 'soft' }); }
    // a puddle round the boots
    const pud = new THREE.Mesh(new THREE.CircleGeometry(0.22, 16), mat('puddleShine', { color: 0x1a1612, roughness: 0.05, metalness: 0.3, transparent: true, opacity: 0.6 })); pud.rotation.x = -Math.PI / 2; pud.scale.set(1.3, 0.8, 1); pud.position.set(9.15, 0.003, 4.32); G.scene.add(pud);
    for (const [x, c] of [[9.45, 0x6a4a3a], [9.6, 0x6a4a3a]]) rbox(0.09, 0.04, 0.24, 0.02, mat('slipper', { color: c, roughness: 1, map: fabricTex('#6a4a3a', 171, 1).map }), { x, y: 0.14, base: true, z: 4.07, ry: (r() - 0.5) * 0.3 });
    const red = rbox(0.06, 0.05, 0.15, 0.02, mat('redShoe', { color: 0x9a1a14, roughness: 0.4 }), { x: 9.75, y: 0.34, base: true, z: 4.07, ry: 0.3, static: false });
    makeProp(red, { mass: 0.2, name: "Child's shoe", desc: 'A girl’s red buckle shoe, left foot. Only the one.', sound: 'soft' });
  }
  // the telephone, receiver off the hook, hanging on its cord
  {
    const t = group({ x: 5.8, z: 4.04 });
    box(0.5, 0.025, 0.32, M.veneer, { y: 0.78, parent: t });
    for (const sx of [-0.22, 0.22]) for (const sz of [-0.13, 0.13]) box(0.025, 0.78, 0.025, M.veneer, { x: sx, y: 0, base: true, z: sz, parent: t });
    box(0.46, 0.015, 0.28, M.veneer, { y: 0.25, parent: t });
    solid(5.8, 0, 4.04, 0.5, 0.8, 0.32);
    const phone = group({ x: 5.82, y: 0.795, z: 4.04 });
    const pm = mat('phoneBody', { color: 0x9a2a1e, roughness: 0.3 });
    rbox(0.22, 0.09, 0.17, 0.03, pm, { y: 0, base: true, parent: phone });
    const dial = cyl(0.06, 0.06, 0.01, 18, mat('dial', { color: 0xe8e0d0, roughness: 0.4 }), { y: 0.095, z: 0.02, rx: -0.3, parent: phone, static: false });
    void dial;
    const cradle = box(0.2, 0.02, 0.05, pm, { y: 0.1, z: -0.06, parent: phone, static: false });
    void cradle;
    // receiver hanging below the table edge
    const rec = group({ x: 5.64, y: 0.48, z: 4.22 });
    rbox(0.2, 0.045, 0.05, 0.02, pm, { rz: 1.2, parent: rec, static: false });
    const recOn = rbox(0.2, 0.045, 0.05, 0.02, pm, { x: 5.82, y: 0.91, z: 3.98, static: false }); recOn.visible = false;
    // the coiled cord
    const pts = []; for (let i = 0; i <= 40; i++) { const k = i / 40; pts.push(new THREE.Vector3(5.75 - k * 0.11 + Math.cos(i * 1.9) * 0.012, 0.82 - k * 0.32 - Math.sin(k * 3.1) * 0.08, 4.1 + k * 0.1 + Math.sin(i * 1.9) * 0.012)); }
    const cord = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 80, 0.004, 4), M.black); G.scene.add(cord);
    let onHook = false, ringing = false, toneSnd = null;
    const pos = V(5.8, 0.85, 4.05);
    onUpdate(() => { if (!toneSnd && AUDIO.ready && !onHook) toneSnd = loopSource('tone', V(5.64, 0.5, 4.22), { vol: 0.08, ref: 0.3 }); });
    const it = interactive([rec, phone, recOn], {
      range: 1.6,
      prompt: () => (ringing ? 'Answer the telephone' : onHook ? 'Pick up the receiver' : 'Hang up the telephone'),
      use: () => {
        sfx('click', pos, { vol: 0.8 });
        if (ringing) { ringing = false; answer(); return; }
        onHook = !onHook; rec.visible = cord.visible = !onHook; recOn.visible = onHook;
        if (onHook) { toneSnd?.stop(); toneSnd = null; if (!G.flags.phoneRang) { G.flags.phoneRang = true; setTimeout(ring, 35000 + Math.random() * 25000); } }
        else { G.ui.toast(G.flags.answered ? 'Dead. Not even the tone now.' : 'The engaged tone. Nobody is calling anybody.'); if (G.flags.answered) toneSnd = { stop() {} }; }
      },
    });
    void it;
    function ring() {
      if (!onHook) return;
      ringing = true; let n = 0;
      const bell = () => { if (!ringing || n >= 6) { ringing = false; return; } n++; sfx('chainRattle', pos, { vol: 1.2, rate: 3 }); sfx('chainRattle', pos, { vol: 1.2, rate: 3.1, delay: 0.25 }); sfx('chainRattle', pos, { vol: 1.2, rate: 3, delay: 0.5 }); setTimeout(bell, 3500); };
      bell();
    }
    function answer() {
      onHook = false; rec.visible = cord.visible = false; recOn.visible = false;
      G.flags.answered = true;
      G.ui.toast('…', 3);
      setTimeout(() => { sfx('plug', pos, { vol: 0.3 }); }, 800);
      setTimeout(() => { knockSeq(pos, [3, 3], 0.25); }, 3800);
      setTimeout(() => { G.ui.toast('Somebody on the line, knocking on a pipe. Then nothing.'); rec.visible = cord.visible = true; }, 8000);
    }
  }
  // the evacuation notice, glued to the inside of the front door
  {
    const d = DOORS.dEntry;
    const m = sheet(D.notice, 0.36, 0.5, { x: 0.45, y: 1.25, z: 0.037, parent: d.pivot, name: 'Notice' });
    void m;
  }
  // a single chair by the door, facing it
  chair(8.3, 4.93, Math.PI / 2 - 0.15, false);
  // a candle stub on the floor in the corner, a box of matches
  const c = candle(9.85, 0, 5.0, 0.03); void c;
  const matches = box(0.05, 0.015, 0.035, mat('matchbox', { color: 0xa88a4a, roughness: 0.9, map: labelMat('match', '#c8a050', '#2a2a2a', 'СПИЧКИ', '').map }), { x: 9.7, y: 0.008, z: 5.0, ry: 0.5, static: false });
  pickable(matches, { name: 'Matches', desc: 'Three left in the box.', mass: 0.02, sound: 'paper', onTake: () => { G.flags.matches = true; } });
}
function givePass(jacket) {
  const p = box(0.085, 0.055, 0.003, new THREE.MeshStandardMaterial({ map: canvasTex(D.workPass().canvas), roughness: 0.6 }), { x: 9.12, y: 1.25, z: 4.08, static: false });
  makeProp(p, { mass: 0.02, name: 'Plant pass', desc: 'Sokolov I. P. — night shift. It was in his jacket pocket. He came home, then: this jacket was not here in October.', sound: 'paper', doc: D.workPass, asleep: false });
  G.ui.toast('A laminated pass falls out of the inside pocket.');
  void jacket;
}

// ---------------------------------------------------------------- balcony
function balcony() {
  const B = BALCONY, y = B.y, r = rng(3003);
  const conc = mat('balConc', { map: metalTex('#7a766c', 0.3, 180).map, roughness: 0.95 });
  box(B.x1 - B.x0 + 0.1, 0.16, B.z1 - B.z0 + 0.05, conc, { x: (B.x0 + B.x1) / 2, y: y - 0.16, base: true, z: (B.z0 + B.z1) / 2 });
  staticBox((B.x0 + B.x1) / 2, y - 0.08, (B.z0 + B.z1) / 2, B.x1 - B.x0, 0.16, B.z1 - B.z0);
  // railing: steel posts, a rusted sheet panel, and a timber cap rail
  const rail = mat('balRail', { map: metalTex('#3e4a44', 1.4, 181).map, roughness: 0.8, metalness: 0.4 });
  for (let x = B.x0 + 0.05; x <= B.x1; x += 0.55) box(0.03, 1.0, 0.03, rail, { x, y, base: true, z: B.z0 + 0.03 });
  for (const z of [B.z0 + 0.3, B.z0 + 0.8]) for (const x of [B.x0 + 0.03, B.x1 - 0.03]) box(0.03, 1.0, 0.03, rail, { x, y, base: true, z });
  const panelM = mat('balPanel', { map: metalTex('#55605a', 1.8, 182).map, roughness: 0.85, metalness: 0.3, side: THREE.DoubleSide });
  box(B.x1 - B.x0, 0.75, 0.01, panelM, { x: (B.x0 + B.x1) / 2, y: y + 0.12, base: true, z: B.z0 + 0.04 });
  for (const x of [B.x0 + 0.02, B.x1 - 0.02]) box(0.01, 0.75, B.z1 - B.z0, panelM, { x, y: y + 0.12, base: true, z: (B.z0 + B.z1) / 2 });
  box(B.x1 - B.x0 + 0.06, 0.04, 0.08, M.pine, { x: (B.x0 + B.x1) / 2, y: y + 1.0, base: true, z: B.z0 + 0.03 });
  collider({ x: (B.x0 + B.x1) / 2, z: B.z0, hx: (B.x1 - B.x0) / 2 + 0.1, hz: 0.06, y0: -1, y1: 2 });
  collider({ x: B.x0, z: (B.z0 + B.z1) / 2, hx: 0.06, hz: (B.z1 - B.z0) / 2, y0: -1, y1: 2 });
  collider({ x: B.x1, z: (B.z0 + B.z1) / 2, hx: 0.06, hz: (B.z1 - B.z0) / 2, y0: -1, y1: 2 });
  for (const [x, z, sx, sz] of [[(B.x0 + B.x1) / 2, B.z0, B.x1 - B.x0, 0.05], [B.x0, (B.z0 + B.z1) / 2, 0.05, B.z1 - B.z0], [B.x1, (B.z0 + B.z1) / 2, 0.05, B.z1 - B.z0]]) staticBox(x, y + 0.6, z, sx, 1.2, sz);
  // the balcony above is our roof: its underside drips
  // dead plants in pots along the rail, soil cracked
  for (let i = 0; i < 4; i++) {
    const x = B.x0 + 0.35 + i * 0.32;
    const pot = lathe([[0, 0], [0.07, 0], [0.09, 0.15], [0.1, 0.16], [0, 0.14]], 12, mat('terracotta', { color: 0x8a4a30, roughness: 0.9 }), { x, y, z: B.z0 + 0.18, static: false });
    for (let k = 0; k < 4; k++) cyl(0.003, 0.002, 0.25 + r() * 0.2, 3, mat('deadStem', { color: 0x4a3a24, roughness: 1 }), { y: 0.25, x: (r() - 0.5) * 0.06, rz: (r() - 0.5) * 0.8, rx: (r() - 0.5) * 0.6, parent: pot, static: false });
    makeProp(pot, { mass: 2, name: 'Flowerpot', desc: i === 1 ? 'Geraniums, once. A cigarette end pushed into the dry soil — recent: the paper is still white.' : 'Dead and dry as paper.', sound: 'wood' });
  }
  // folding chair facing out over the courtyard, a tin of butts beside it
  {
    const g = group({ x: 2.9, y, z: -1.1, ry: Math.PI + 0.3 });
    const al = mat('alum', { color: 0x8a8a84, metalness: 0.8, roughness: 0.5 });
    for (const s of [-0.2, 0.2]) { box(0.02, 0.8, 0.02, al, { x: s, y: 0.4, z: -0.1, rx: 0.25, parent: g, static: false }); box(0.02, 0.5, 0.02, al, { x: s, y: 0.25, z: 0.12, rx: -0.3, parent: g, static: false }); }
    box(0.42, 0.02, 0.36, mat('chairStrap', { map: fabricTex('#3a5a7a', 183, 2).map, roughness: 1 }), { y: 0.45, parent: g, static: false });
    box(0.42, 0.3, 0.02, mat('chairStrap', {}), { y: 0.68, z: -0.18, rx: -0.15, parent: g, static: false });
    makeProp(g, { mass: 3, name: 'Folding chair', sound: 'metal', size: [0.44, 0.85, 0.44] });
    const tin = can(3.25, y, -0.9, labelMat('sprats', '#8a6a2a', '#1a1a1a', 'SPRATS', 'Riga'), { open: true });
    for (let i = 0; i < 5; i++) cyl(0.004, 0.004, 0.03, 4, mat('butt', {}), { x: (r() - 0.5) * 0.04, y: 0.1, z: (r() - 0.5) * 0.04, rx: 1.2, ry: r() * 3, parent: tin, static: false });
    makeProp(tin, { mass: 0.2, name: 'Tin of cigarette ends', desc: 'An old sprat tin used as an ashtray. The ash on top is pale and dry, but the rain hasn’t got to it. Somebody smoked out here after the rain stopped.', sound: 'can' });
  }
  // washing line down the west side: rags of shirts gone stiff
  {
    const lx = B.x0 + 0.28;
    cyl(0.002, 0.002, B.z1 - B.z0 - 0.1, 3, M.paper, { x: lx, y: y + 1.95, z: (B.z0 + B.z1) / 2, rx: Math.PI / 2 });
    for (const [z, w, h, m] of [[-0.7, 0.45, 0.6, M.cloth[3]], [-1.1, 0.3, 0.4, M.cloth[5]], [-1.45, 0.4, 0.55, M.sheet]]) {
      const geo = new THREE.PlaneGeometry(w, h, 6, 8); const p = geo.attributes.position;
      for (let i = 0; i < p.count; i++) p.setZ(i, Math.sin(p.getX(i) * 10 + p.getY(i) * 4) * 0.03);
      geo.computeVertexNormals();
      const cl = new THREE.Mesh(geo, m); cl.material.side = THREE.DoubleSide; cl.position.set(lx, y + 1.95 - h / 2, z); cl.rotation.y = Math.PI / 2; cl.castShadow = true; G.scene.add(cl);
      onUpdate((dt, t) => { cl.rotation.z = Math.sin(t * 1.3 + z) * 0.12; });
    }
  }
  // an old bicycle frame without wheels against the side wall; a crate of empty jars
  {
    const g = group({ x: B.x1 - 0.15, y, z: -1.0, ry: Math.PI / 2 });
    const fr = mat('bikeFrame', { map: metalTex('#2a4a6a', 1.2, 184).map, roughness: 0.6, metalness: 0.5 });
    const tube = (a, b) => { const v = new THREE.Vector3().subVectors(b, a), len = v.length(); const m = cyl(0.015, 0.015, len, 6, fr, { parent: g }); m.position.copy(a).add(b).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), v.normalize()); };
    const A = V(-0.45, 0.35, 0), Bq = V(0, 0.35, 0), C = V(0.45, 0.35, 0), Dq = V(-0.1, 0.85, 0), E = V(0.38, 0.82, 0);
    tube(A, Dq); tube(Dq, Bq); tube(A, Bq); tube(Dq, E); tube(E, C); tube(Bq, E);
    solid(B.x1 - 0.15, y, -1.0, 0.1, 1, 1.0);
    const crate = carcass(0.4, 0.28, 0.3, M.pine, { x: 0.9, y, z: -0.65, solid: false });
    for (let i = 0; i < 6; i++) jar(-0.13 + (i % 3) * 0.13, 0.02, -0.07 + Math.floor(i / 3) * 0.14, M.glass, { parent: crate, fill: 0 });
    makeProp(crate, { mass: 6, name: 'Crate of jars', push: true, sound: 'glassTink', size: [0.4, 0.3, 0.3] });
  }
  // cigarette-burn scorch and bird droppings on the slab, a puddle of rainwater
  const pud = new THREE.Mesh(new THREE.CircleGeometry(0.4, 20), mat('rainPuddle', { color: 0x222628, roughness: 0.02, metalness: 0.5, transparent: true, opacity: 0.75 })); pud.rotation.x = -Math.PI / 2; pud.scale.set(1.6, 0.7, 1); pud.position.set(1.6, y + 0.004, -1.3); G.scene.add(pud);
  // and the drip from the balcony above, positional
  addTimer({ t: 3, every: [2.5, 5], f: () => sfx('dripWater', V(1.6, y, -1.3), { vol: 0.6, room: 'outside' }) });
}
