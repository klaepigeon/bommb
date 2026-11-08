// Bedroom, kitchen, Sonya's room, the bathroom, the box room.
import * as THREE from 'three';
import { G, mat, box, cyl, group, solid, collider, staticBox, interactive, onUpdate, solidMat, sphere } from './core.js';
import { M, rbox, lathe, drape, crumple, drawer, cabDoor, carcass, book, bookRow, bottle, jar, can, labelMat, plate, cup, candle, frame, makeProp, pickable } from './furniture.js';
import { addLight, wallSwitch, powered, toggleLight } from './lighting.js';
import { sfx, loopSource, knockSeq, AUDIO } from './audio.js';
import { woodTex, fabricTex, metalTex, enamelTex, rng, canvas } from './textures.js';
import * as D from './docs.js';
import { H } from './plan.js';
import { radiator, chair, sheet, examine, canvasTex } from './dress.js';
import { DUST } from './particles.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);

export function dressRest() {
  bedroom();
  kitchen();
  child();
  bath();
  storage();
}

// pendant with a fabric shade; bulb may be dead
function pendant(name, x, z, circuitName, o = {}) {
  cyl(0.004, 0.004, 0.45, 4, M.black, { x, y: H - 0.225, z });
  const shadeM = mat('shade' + name, { map: fabricTex(o.col || '#b89a70', 190 + name.length, 0).map, roughness: 1, side: THREE.DoubleSide, emissive: 0xffc890, emissiveIntensity: 0 });
  const sh = lathe([[0.04, 0], [0.18, -0.18], [0.2, -0.2]], 16, shadeM, { x, y: H - 0.42, z, static: false });
  const l = new THREE.PointLight(o.color || 0xffc890, o.k || 10, 7, 2); l.position.set(x, H - 0.6, z);
  return addLight(name, l, { circuit: circuitName, on: o.on ?? false, broken: o.broken, flicker: 'bulb', fixtures: [sh], emissive: 0.4, virtual: !!o.broken });
}

// ---------------------------------------------------------------- bedroom
function bedroom() {
  const r = rng(4004);
  radiator(6.0, 0.11, 11, 0);
  pendant('bedroom', 6.0, 1.9, 'C', { broken: true });
  wallSwitch(6.42, 1.4, 3.725, Math.PI, ['bedroom'], { brokenMsg: 'Click. The bulb went long ago.' });
  // the bed: unmade, the duvet dragged half off toward the door as if someone got up fast
  {
    const g = group({ x: 5.47, z: 1.85 });
    box(2.0, 0.25, 1.55, M.veneer, { y: 0.12, base: true, parent: g });
    box(0.05, 0.95, 1.6, M.veneer, { x: -1.0, y: 0, base: true, parent: g }); // headboard
    box(0.05, 0.5, 1.6, M.veneer, { x: 1.0, y: 0, base: true, parent: g });
    rbox(1.95, 0.18, 1.5, 0.06, M.sheet, { y: 0.37, base: true, parent: g });
    rbox(0.42, 0.12, 0.6, 0.05, M.sheet, { x: -0.72, y: 0.55, base: true, z: -0.36, parent: g, rz: 0.15 });
    const pil = rbox(0.42, 0.12, 0.6, 0.05, M.sheet, { x: -0.6, y: 0.0, base: true, z: 1.15, ry: 0.5, parent: g, static: false }); // knocked off
    makeProp(pil, { mass: 0.6, name: 'Pillow', desc: 'Still a hollow in it. Brown hair.', sound: 'soft' });
    drape(2.4, 2.1, [{ x0: -0.25, x1: 1.0, z0: -0.75, z1: 0.72, top: 0.58 }], M.blanket, { x: 5.6, z: 2.05, y: 0, seed: 11, wrinkle: 0.09, fall: 2.6, nx: 40, nz: 40 });
    solid(5.47, 0, 1.85, 2.0, 0.6, 1.55);
    staticBox(5.47, 0.55, 1.85, 2.0, 0.06, 1.55);
    examine(g.children[3], 'Bed', 'Their side, her side. The sheet on his side is still tucked tight — he was on nights. Hers has been pulled loose and kicked down.');
  }
  // bedside: lamp, a glass, a row of empty pill bottles
  for (const [z, hasPills] of [[0.75, true], [2.95, false]]) {
    const g = carcass(0.42, 0.5, 0.36, M.veneer, { x: 4.69, z, ry: Math.PI / 2, solid: false });
    const dr = drawer(g, 0, 0.38, 0.38, 0.14, 0.32, M.veneer, { z: 0.18 });
    solid(4.69, 0, z, 0.36, 0.5, 0.42);
    staticBox(4.69, 0.5, z, 0.36, 0.02, 0.42);
    if (hasPills) {
      const lamp = group({ x: 4.69, y: 0.5, z: z - 0.1 });
      lathe([[0, 0], [0.06, 0], [0.04, 0.03], [0.015, 0.06], [0.015, 0.25], [0, 0.25]], 12, mat('lampBase', { color: 0x6a8a7a, roughness: 0.3 }), { parent: lamp, static: false });
      const shade = lathe([[0.06, 0], [0.11, -0.14], [0.115, -0.15]], 14, mat('bedLampShade', { color: 0xd8c8a8, roughness: 1, side: THREE.DoubleSide, emissive: 0xffc080, emissiveIntensity: 0 }), { y: 0.38, parent: lamp, static: false });
      const l = new THREE.PointLight(0xffb870, 4, 4, 2); l.position.set(4.69, 0.8, z - 0.1);
      const L = addLight('bedside', l, { circuit: 'C', on: true, flicker: 'bulb', fixtures: [shade], emissive: 1.5 });
      interactive(lamp.children, { prompt: () => 'Lamp switch', use: () => { toggleLight(L); sfx('switch', l.position, { vol: 0.5, rate: 1.3 }); if (L.switched && !powered(L)) G.ui.toast('Click. Nothing.'); } });
      const names = ['Diazepam 5 mg — Sokolova M. A.', 'Diazepam 5 mg — Sokolova M. A.', 'Valerian drops', 'Analgin'];
      for (let i = 0; i < 4; i++) {
        const b = cyl(0.018, 0.018, 0.06, 10, i < 2 ? M.brownGlass : mat('pillWhite', { color: 0xe8e4d8, roughness: 0.4 }), { x: 4.6 + i * 0.045, y: 0.5, base: true, z: z + 0.1, static: false });
        cyl(0.019, 0.019, 0.012, 10, M.chrome, { y: 0.036, parent: b, static: false });
        if (i === 3) { b.rotation.z = Math.PI / 2; b.position.y = 0.52; }
        makeProp(b, { mass: 0.05, name: 'Pill bottle', desc: names[i] + '. Empty.', sound: 'glassTink' });
      }
      const pack = box(0.06, 0.01, 0.1, mat('blister', { color: 0xc8c8c0, metalness: 0.6, roughness: 0.4 }), { x: 0.05, y: -0.08, z: -0.12, parent: dr, static: false });
      pickable(pack, { name: 'Blister pack', desc: 'Every foil bubble pushed through.', mass: 0.01, sound: 'paper' });
    } else {
      const b = book(G.scene, 4.69, 0.5, z, { w: 0.03, h: 0.2, d: 0.14, rz: Math.PI / 2, seed: 77 });
      b.rotation.set(0, 0.3, Math.PI / 2); b.position.y = 0.515;
      makeProp(b, { mass: 0.3, name: 'Book', desc: 'A detective novel, open face-down at chapter nine. His.', sound: 'paper' });
      const gl = cup(4.6, 0.5, z + 0.12, { mat: M.glass }); makeProp(gl, { mass: 0.15, name: 'Glass', desc: 'Empty and dry. Dust inside it.', sound: 'glassTink', breakable: true });
    }
  }
  // wardrobe: one door hanging open, hangers mostly empty — packed in a hurry
  {
    const g = carcass(1.2, 2.0, 0.6, M.veneer, { x: 7.23, z: 0.9, ry: -Math.PI / 2, shelves: [1.7] });
    cabDoor(g, -0.59, 1.0, 0.59, 1.92, M.veneer, 1, { z: 0.31, open: 1.4 });
    cabDoor(g, 0.59, 1.0, 0.59, 1.92, M.veneer, -1, { z: 0.31 });
    cyl(0.01, 0.01, 1.12, 6, M.chrome, { y: 1.6, rz: Math.PI / 2, parent: g });
    for (let i = 0; i < 11; i++) {
      const x = -0.5 + i * 0.1, hang = new THREE.Group(); hang.position.set(x + (r() - 0.5) * 0.03, 1.58, 0); hang.rotation.y = Math.PI / 2 + (r() - 0.5) * 0.3; g.add(hang);
      const tri = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.004, 3, 3, Math.PI * 2), mat('hanger', { color: 0x8a7a5a, roughness: 0.6 })); tri.scale.set(1, 0.3, 1); tri.rotation.z = Math.PI / 2; tri.position.y = -0.05; hang.add(tri);
      if (i === 2 || i === 7 || i === 8) { // what was left: his good suit, an old dress, a school pinafore
        const m = [M.cloth[4], M.cloth[2], M.cloth[0]][[2, 7, 8].indexOf(i)];
        rbox(0.42, i === 8 ? 0.55 : 0.95, 0.06, 0.03, m, { y: i === 8 ? -0.35 : -0.55, parent: hang, static: false });
      }
    }
    // a drift of clothes at the bottom
    crumple(0.0, 0.1, 0.8, 0.45, M.cloth[1], 12, { y: 0.02 });
    g.children[g.children.length - 1].removeFromParent();
    crumple(7.15, 0.95, 0.9, 0.5, M.cloth[1], 12, { y: 0.03, ry: Math.PI / 2 });
    examine(g.children[1], 'Wardrobe', 'Bare hangers swinging together when you touch them. Winter coats gone. Her good boots gone. They had time to pack, then.');
  }
  // chest of drawers with a mirror; the mirror is cracked from one corner
  {
    const g = carcass(1.0, 0.85, 0.45, M.veneer, { x: 5.1, z: 3.5, ry: Math.PI });
    const drs = [0.7, 0.45, 0.18].map((y, i) => drawer(g, 0, y, 0.96, 0.22, 0.42, M.veneer, { z: 0.225, stuck: i === 2 ? 'The bottom drawer is jammed with something soft. It comes out a little.' : null }));
    crumple(0, -0.05, 0.7, 0.3, M.cloth[3], 21, { parent: drs[0], y: -0.08, z: -0.2 });
    drs[0].children[drs[0].children.length - 1].position.set(0, -0.08, -0.2);
    const letters = box(0.16, 0.03, 0.11, M.paper, { x: 0.2, y: -0.06, z: -0.15, parent: drs[1], static: false });
    pickable(letters, { name: 'Bundle of letters', desc: 'Tied with darning wool. Letters from Ilya’s mother in Kursk, the last one in September: "Come to us, all three of you, what is there to wait for."', mass: 0.1, sound: 'paper' });
    const sock = rbox(0.12, 0.06, 0.2, 0.03, M.cloth[0], { x: -0.2, y: -0.06, z: -0.2, parent: drs[2], static: false });
    pickable(sock, { name: 'Rolled socks', desc: 'Inside the socks, a roll of rouble notes, tight as a cigar. Their savings. They left their savings.', mass: 0.1, sound: 'soft' });
    // mirror on the wall above
    const mg = group({ x: 5.1, y: 1.4, z: 3.72, ry: Math.PI });
    box(0.7, 0.85, 0.03, M.veneer, { parent: mg });
    const mirrorTex = (() => { const c = canvas(256, 320), g2 = c.getContext('2d'); g2.fillStyle = '#ffffff'; g2.fillRect(0, 0, 256, 320); g2.strokeStyle = '#303030'; g2.lineWidth = 2; for (let i = 0; i < 7; i++) { g2.beginPath(); g2.moveTo(230, 30); let x = 230, y = 30; for (let k = 0; k < 6; k++) { x -= 15 + r() * 30; y += (r() - 0.2) * 50; g2.lineTo(x, y); } g2.stroke(); } const gr = g2.createRadialGradient(128, 160, 80, 128, 160, 200); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(80,70,50,0.7)'); g2.fillStyle = gr; g2.fillRect(0, 0, 256, 320); return canvasTex(c); })();
    const mm = new THREE.Mesh(new THREE.PlaneGeometry(0.62, 0.77), new THREE.MeshStandardMaterial({ color: 0x3a403c, map: mirrorTex, roughness: 0.3, metalness: 0.9 })); mm.position.z = 0.016; mg.add(mm);
    examine(mm, 'Mirror', 'Silvering gone to grey bloom. Your own shape in it, and the window behind you.');
    // hairbrush and a lipstick on top
    const brush = rbox(0.05, 0.03, 0.2, 0.012, M.bakelite, { x: 4.8, y: 0.86, base: true, z: 3.45, ry: 0.5, static: false });
    makeProp(brush, { mass: 0.1, name: 'Hairbrush', desc: 'Long brown hair wound in the bristles, and a few shorter fair ones. Sonya’s.', sound: 'wood' });
  }
  // half-packed suitcase open on the floor, things put in and then taken out again
  {
    const g = group({ x: 5.9, z: 2.95, ry: 0.25 });
    const sm = mat('suitcase', { map: fabricTex('#4a3a2a', 191, 0).map, roughness: 0.7 });
    box(0.7, 0.03, 0.45, sm, { y: 0.015, parent: g }); for (const [x, z, w, d] of [[0, 0.22, 0.7, 0.02], [0, -0.22, 0.7, 0.02], [0.34, 0, 0.02, 0.45], [-0.34, 0, 0.02, 0.45]]) box(w, 0.18, d, sm, { x, y: 0.09, z, parent: g });
    const lid = group({ x: 0, y: 0.18, z: -0.23, parent: g }); lid.rotation.x = -1.95;
    box(0.7, 0.03, 0.45, sm, { y: 0, z: 0.225, parent: lid });
    crumple(0, 0.07, 0.55, 0.35, M.cloth[5], 31, { parent: g, y: 0.05 }); g.children[g.children.length - 1].position.set(0, 0.06, 0);
    solid(5.9, 0, 2.95, 0.7, 0.2, 0.45, 0.25);
    examine(g.children[0], 'Suitcase', 'Half-packed: a cardigan, Sonya’s nightdress, a jar of honey wrapped in a towel. Then left. Maybe it was too heavy to carry with a child.');
  }
  chair(7.15, 2.3, -Math.PI / 2 - 0.3, false);
  drape(0.6, 0.6, [{ x0: -0.2, x1: 0.2, z0: -0.2, z1: 0.2, top: 0.52 }], M.cloth[3], { x: 7.15, z: 2.3, y: 0, seed: 33, fall: 4, nx: 12, nz: 12 });
  crumple(6.6, 1.2, 0.5, 0.35, M.cloth[0], 41);
  crumple(4.9, 2.9, 0.4, 0.3, M.cloth[5], 42);
  const shoe = rbox(0.08, 0.08, 0.22, 0.02, mat('womanShoe', { color: 0x2a1a14, roughness: 0.4 }), { x: 6.3, y: 0, base: true, z: 0.7, ry: 1.1, static: false });
  makeProp(shoe, { mass: 0.3, name: 'Shoe', sound: 'soft', desc: 'A woman’s court shoe, heel snapped off.' });
  DUST.shafts.push({ min: V(5.25, 0, 0), max: V(6.75, 2.35, 1.4), col: V(0.12, 0.14, 0.17) });
}

// ---------------------------------------------------------------- kitchen
function kitchen() {
  const r = rng(5005);
  radiator(8.85, 0.11, 8, 0);
  // the fluorescent tube: the one light in the flat that still works, more or less
  {
    const g = group({ x: 8.85, y: H - 0.04, z: 1.9 });
    box(1.25, 0.06, 0.16, mat('fluoroBody', { color: 0xd8d4c4, roughness: 0.6 }), { parent: g });
    const tube = cyl(0.014, 0.014, 1.15, 10, mat('tube', { color: 0xf0f4f0, emissive: 0xe8f4ff, emissiveIntensity: 0, roughness: 0.2 }), { y: -0.05, rz: Math.PI / 2, parent: g, static: false });
    box(1.2, 0.002, 0.13, mat('fluoroDiff', { color: 0xf0f0e8, roughness: 0.3, transparent: true, opacity: 0.35 }), { y: -0.075, parent: g, static: false }).rotation.z = 0.25; // diffuser hanging loose
    const p = new THREE.PointLight(0xdff0ff, 9, 7, 2); p.position.set(8.85, H - 0.2, 1.9);
    addLight('fluoro', p, { circuit: 'B', on: true, flicker: 'fluoro', fixtures: [tube], emissive: 2.5, buzzPos: V(8.85, H - 0.1, 1.9) });
    wallSwitch(7.98, 1.4, 3.725, Math.PI, ['fluoro']);
  }
  // the counter run along the east wall: cupboards, sink, worktop with drawers, cooker
  const top = mat('worktop', { map: enamelTex('#bab49c', 3, 200).map, roughness: 0.5 });
  const front = M.paintedWood;
  const unit = (z0, z1, kind) => {
    const w = z1 - z0, c = carcass(w, 0.85, 0.6, front, { x: 9.7, z: (z0 + z1) / 2, ry: -Math.PI / 2, plinth: 0.08, noTop: kind === 'sink' });
    if (kind === 'sink') { // worktop with a hole cut for the bowl (local x runs along the counter, z out from the wall)
      for (const [x, ww] of [[-(w / 2 + 0.25) / 2 - 0.005, w / 2 - 0.25 + 0.01], [(w / 2 + 0.25) / 2 + 0.005, w / 2 - 0.25 + 0.01]]) box(ww, 0.035, 0.62, top, { x, y: 0.87, parent: c });
      box(0.5, 0.035, 0.06, top, { y: 0.87, z: -0.28, parent: c }); box(0.5, 0.035, 0.06, top, { y: 0.87, z: 0.28, parent: c });
    } else box(w + 0.01, 0.035, 0.62, top, { y: 0.87, parent: c });
    if (kind === 'doors' || kind === 'sink') { cabDoor(c, -w / 2 + 0.01, 0.46, w / 2 - 0.012, 0.74, front, 1, { z: 0.31 }); cabDoor(c, w / 2 - 0.01, 0.46, w / 2 - 0.012, 0.74, front, -1, { z: 0.31, open: kind === 'doors' && z0 < 1 ? 0.6 : 0 }); }
    if (kind === 'drawers') { [0.72, 0.46, 0.2].forEach((y, i) => drawer(c, 0, y, w - 0.03, 0.22, 0.55, front, { z: 0.3, stuck: i === 1 ? 'Rust has glued the runners. It gives a few centimetres.' : null })); }
    staticBox(9.7, 0.88, (z0 + z1) / 2, 0.6, 0.04, w);
    return c;
  };
  const u1 = unit(0.35, 0.95, 'doors');
  const sinkU = unit(0.95, 1.75, 'sink');
  const drw = unit(1.75, 2.35, 'drawers');
  // contents: in the open cupboard, saucepans and a box of salt; jars of water hoarded everywhere
  jar(0.0, 0.1, 0.0, mat('waterJar', { color: 0x6a7a6a, roughness: 0.1, transparent: true, opacity: 0.5 }), { parent: u1, h: 0.25, r: 0.08, fill: 0.9 });
  const cutlery = drw.children.find((o) => o.userData.drawer);
  if (cutlery) for (let i = 0; i < 6; i++) box(0.16, 0.005, 0.015, M.chrome, { x: -0.1 + i * 0.04, y: -0.09, z: -0.25, ry: (r() - 0.5) * 0.3, parent: cutlery, static: false });
  // the sink: enamel bowl, a tap with a drip, scum, a pan soaking in dried water
  {
    const g = group({ x: 9.68, y: 0.905, z: 1.35 });
    const sm = M.enamel;
    box(0.5, 0.18, 0.02, sm, { y: -0.09, z: 0.24, parent: g }); box(0.5, 0.18, 0.02, sm, { y: -0.09, z: -0.24, parent: g });
    box(0.02, 0.18, 0.5, sm, { x: -0.24, y: -0.09, parent: g }); box(0.02, 0.18, 0.5, sm, { x: 0.24, y: -0.09, parent: g }); box(0.5, 0.02, 0.5, sm, { y: -0.18, parent: g });
    const tap = group({ x: 0.25, y: 0.0, z: 0, parent: g });
    cyl(0.012, 0.012, 0.25, 8, M.chrome, { y: 0.12, parent: tap }); box(0.2, 0.02, 0.02, M.chrome, { x: -0.1, y: 0.24, parent: tap });
    for (const s of [-1, 1]) { const h = cyl(0.02, 0.02, 0.03, 6, mat('tapHead', { color: 0x9a2a1a, roughness: 0.4 }), { x: 0, y: 0.06, z: s * 0.1, parent: tap, static: false }); void h; }
    const drip = sphere(0.004, M.glass, { x: 9.73, y: 1.1, z: 1.35, static: false });
    onUpdate((dt, t) => { const k = (t % 9) / 9; drip.position.y = k < 0.8 ? 1.135 : 1.135 - (k - 0.8) * 1.2; drip.scale.setScalar(k < 0.8 ? 0.5 + k : 1.3); });
    const pan = cyl(0.11, 0.1, 0.07, 14, M.chrome, { x: 9.65, y: 0.73, base: true, z: 1.3, static: false });
    makeProp(pan, { mass: 0.8, name: 'Saucepan', desc: 'Left to soak. The water evaporated a long time ago and left a brown ring.', sound: 'metal' });
    let tapOn = false, flow = null;
    interactive(tap, {
      prompt: () => (tapOn ? 'Turn the tap off' : 'Turn the tap on'),
      use: () => {
        tapOn = !tapOn; sfx('cabinet', g.position, { rate: 0.6 });
        if (tapOn) {
          sfx('plug', V(9.7, 1.0, 1.35), { vol: 0.8, rate: 1.4 });
          setTimeout(() => { if (tapOn) { knockSeq(V(9.95, 1.5, 0.3), [1], 0.9); G.ui.toast('The pipe shudders and thumps. Not a drop. Then, far down in the building, the same thump, answered.'); } }, 900);
          setTimeout(() => knockSeq(V(9.95, -2, 0.3), [1], 0.5), 3500);
        }
        void flow;
      },
    });
  }
  // the cooker: four rings, the oven door can drop open; kettle on the back ring
  {
    const c = group({ x: 9.7, z: 2.65, ry: -Math.PI / 2 });
    box(0.55, 0.85, 0.58, M.enamelCream, { y: 0.425, parent: c });
    box(0.55, 0.02, 0.58, mat('hob', { color: 0x1e1c1a, roughness: 0.6, metalness: 0.4 }), { y: 0.86, parent: c });
    for (const [x, z] of [[-0.14, -0.13], [0.14, -0.13], [-0.14, 0.13], [0.14, 0.13]]) { cyl(0.07, 0.07, 0.015, 12, M.iron, { x, y: 0.875, z, parent: c }); cyl(0.035, 0.035, 0.02, 10, mat('burner', { color: 0x1a1a1a, metalness: 0.6, roughness: 0.5 }), { x, y: 0.88, z, parent: c }); }
    for (let i = 0; i < 4; i++) cyl(0.015, 0.015, 0.025, 10, M.black, { x: -0.18 + i * 0.12, y: 0.78, z: 0.3, rx: Math.PI / 2, parent: c, static: false });
    const ov = group({ x: 0, y: 0.1, z: 0.295, parent: c });
    box(0.5, 0.5, 0.02, M.enamelCream, { y: 0.25, parent: ov, static: false });
    box(0.3, 0.2, 0.005, mat('ovenGlass', { color: 0x1a1a14, roughness: 0.1, metalness: 0.3 }), { y: 0.3, z: 0.012, parent: ov, static: false });
    box(0.35, 0.02, 0.03, M.chrome, { y: 0.46, z: 0.03, parent: ov, static: false });
    let ovOpen = false;
    onUpdate((dt) => { const tg = ovOpen ? 1.45 : 0; ov.rotation.x += (tg - ov.rotation.x) * Math.min(1, dt * 6); });
    interactive(ov, { prompt: () => (ovOpen ? 'Close the oven' : 'Open the oven'), use: () => { ovOpen = !ovOpen; sfx('cabinet', ov.getWorldPosition(V()), { rate: 0.7 }); if (ovOpen && !G.flags.oven) { G.flags.oven = true; G.ui.toast('A roasting tin, scrubbed clean, and inside it, wrapped in a tea towel, a kitchen knife. Put away like something hidden.'); } } });
    const knife = box(0.25, 0.006, 0.03, M.chrome, { x: 0, y: 0.25, z: 0, parent: c, static: false });
    pickable(knife, { name: 'Kitchen knife', desc: 'The big one, for bread. Sharpened recently on something rough: the edge is bright.', mass: 0.15, sound: 'can' });
    solid(9.7, 0, 2.65, 0.58, 0.9, 0.55);
    staticBox(9.7, 0.89, 2.65, 0.58, 0.02, 0.55);
    const kettle = group({ x: 9.82, y: 0.89, z: 2.52 });
    lathe([[0, 0], [0.09, 0], [0.1, 0.05], [0.09, 0.14], [0.05, 0.18], [0.02, 0.19], [0, 0.19]], 14, mat('kettle', { map: enamelTex('#3a6a8a', 20, 201).map, roughness: 0.35 }), { parent: kettle, static: false });
    box(0.12, 0.012, 0.012, M.black, { y: 0.22, parent: kettle, static: false });
    cyl(0.01, 0.015, 0.1, 6, mat('kettle', {}), { x: 0.1, y: 0.08, rz: -0.8, parent: kettle, static: false });
    makeProp(kettle, { mass: 1, name: 'Kettle', desc: 'Full. The water inside is clear and smells of nothing. Someone filled it from somewhere that wasn’t the tap.', sound: 'metal' });
  }
  // the fridge, a ZIL: the note under the magnet; inside, what's left
  {
    const g = group({ x: 9.68, z: 3.37, ry: -Math.PI / 2 });
    rbox(0.6, 1.5, 0.6, 0.06, M.enamel, { y: 0.75, parent: g });
    solid(9.68, 0, 3.37, 0.6, 1.5, 0.6);
    staticBox(9.68, 1.51, 3.37, 0.6, 0.02, 0.6);
    const door = group({ x: -0.3, y: 0, z: 0.31, parent: g });
    rbox(0.6, 1.45, 0.06, 0.03, M.enamel, { x: 0.3, y: 0.75, parent: door, static: false });
    box(0.04, 0.3, 0.03, M.chrome, { x: 0.55, y: 1.0, z: 0.04, parent: door, static: false });
    // inside
    box(0.52, 1.35, 0.01, mat('fridgeIn', { color: 0x4a4a3a, roughness: 0.9 }), { y: 0.75, z: -0.25, parent: g });
    for (const y of [0.45, 0.85, 1.15]) box(0.5, 0.01, 0.5, M.chrome, { y, z: 0, parent: g });
    const milk = bottle(0.12, 0.86, 0.05, mat('milkGlass', { color: 0x5a5a40, roughness: 0.2, transparent: true, opacity: 0.8 }), { s: 0.85, parent: g });
    void milk;
    jar(-0.12, 0.86, 0.0, M.mould, { parent: g, h: 0.12, r: 0.05 });
    jar(-0.1, 0.46, 0.05, mat('pickles', { color: 0x4a5a2a, roughness: 0.4 }), { parent: g, h: 0.22, r: 0.07, fill: 0.8 });
    let open = 0, tgt = 0;
    onUpdate((dt) => { open += (tgt - open) * Math.min(1, dt * 4); door.rotation.y = -open; });
    interactive(door.children, { prompt: () => (tgt ? 'Close the fridge' : 'Open the fridge'), use: () => { tgt = tgt ? 0 : 1.7; sfx('cabinet', door.getWorldPosition(V()), { rate: 0.5 }); if (tgt && !G.flags.fridge) { G.flags.fridge = true; G.ui.toast('The smell has been and gone. Black fur on everything. A jar of pickles, sealed.'); } } });
    // the note, under a magnet shaped like a strawberry
    const note = sheet(D.fridgeNote, 0.16, 0.2, { x: 0.32, y: 1.2, z: 0.035, parent: door, name: 'Note' });
    sphere(0.015, mat('magnet', { color: 0xc02020, roughness: 0.3 }), { x: 0.32, y: 1.29, z: 0.045, parent: door, static: false });
    void note;
  }
  // wall cupboards above the worktop
  for (const [z0, z1] of [[0.35, 0.95], [1.75, 2.35]]) {
    const w = z1 - z0, c = carcass(w, 0.6, 0.32, front, { x: 9.84, y: 1.55, z: (z0 + z1) / 2, ry: -Math.PI / 2, shelves: [0.3] });
    cabDoor(c, -w / 2 + 0.01, 0.3, w - 0.02, 0.58, front, 1, { z: 0.17, open: z0 > 1 ? 1.2 : 0 });
    for (let i = 0; i < 3; i++) cup(-0.15 + i * 0.15, 0.32, 0, { parent: c });
    if (z0 > 1) { for (let i = 0; i < 4; i++) { const p = plate(-0.12, 0.02 + i * 0.022, 0, null, { parent: c }); void p; } }
  }
  // table under the window wall, two stools, and the calendar
  {
    const g = group({ x: 8.0, z: 1.05 });
    box(0.65, 0.03, 0.9, mat('formica', { map: enamelTex('#b8b0a0', 6, 202).map, roughness: 0.45 }), { y: 0.73, parent: g });
    for (const sx of [-0.28, 0.28]) for (const sz of [-0.4, 0.4]) box(0.03, 0.72, 0.03, M.chrome, { x: sx, y: 0, base: true, z: sz, parent: g });
    solid(8.0, 0, 1.05, 0.65, 0.75, 0.9);
    staticBox(8.0, 0.735, 1.05, 0.65, 0.02, 0.9);
    for (const [x, z, fallen] of [[8.45, 0.7, false], [8.5, 1.65, true]]) {
      const s = group({ x, z });
      cyl(0.16, 0.16, 0.03, 14, mat('stoolTop', { color: 0x6a2a20, roughness: 0.5 }), { y: 0.47, parent: s, static: false });
      for (let i = 0; i < 3; i++) { const a = i * 2.09; box(0.02, 0.47, 0.02, M.chrome, { x: Math.cos(a) * 0.11, y: 0.235, z: Math.sin(a) * 0.11, parent: s, static: false }); }
      if (fallen) { s.rotation.z = Math.PI / 2; s.position.y = 0.17; }
      makeProp(s, { mass: 2.5, name: 'Stool', sound: 'metal', size: [0.32, 0.49, 0.32] });
    }
    // the radio on the table: tune it and the static carries a pattern
    radio(8.05, 0.75, 0.75);
    sheet(D.calendar, 0.3, 0.4, { x: 7.68, y: 1.6, z: 1.9, ry: Math.PI / 2, name: 'Calendar' });
    // a cup, a plate with one slice of bread long gone to dust
    const c1 = cup(7.9, 0.745, 1.25, {}); makeProp(c1, { mass: 0.25, name: 'Cup', desc: 'Tea, dried to a brown varnish.', sound: 'glassTink' });
  }
  // water hoarded: jars and plastic canisters along the wall, all filled before the 15th
  for (let i = 0; i < 7; i++) {
    const j = jar(7.85 + (i % 4) * 0.18, 0, 2.4 + Math.floor(i / 4) * 0.2, mat('waterJar', {}), { h: 0.32, r: 0.08, fill: i === 6 ? 0.1 : 0.85 });
    makeProp(j, { mass: 3, name: 'Three-litre jar', desc: i === 6 ? 'Almost empty. A tidemark at every level — someone drank this down over many days.' : 'Water, stored before the 15th. A skin of dust on the lid.', sound: 'glassTink', breakable: true });
  }
  for (let i = 0; i < 2; i++) { const cn = rbox(0.24, 0.38, 0.16, 0.03, mat('canister', { color: 0xd0c8a0, roughness: 0.5, transparent: true, opacity: 0.85 }), { x: 7.95 + i * 0.3, y: 0, base: true, z: 3.45, static: false }); makeProp(cn, { mass: 1.5, name: 'Water canister', desc: 'Ten litres, empty. "SOKOLOV 47" in marker on the side.', sound: 'soft' }); }
  // bin, overflowing; a mop; flies long dead on the sill
  {
    const bin = cyl(0.15, 0.13, 0.42, 14, M.rust, { x: 7.9, y: 0, base: true, z: 3.45 - 0.55, static: false });
    makeProp(bin, { mass: 2, name: 'Bin', sound: 'metal', desc: 'Peelings, tins, a broken thermometer.' });
    for (let i = 0; i < 4; i++) { const t = can(7.9 + (r() - 0.5) * 0.5, 0.04, 2.4 + (r() - 0.5) * 0.3, labelMat('stew', '#8a3a2a', '#e8e0c8', 'ТУШЁНКА', 'beef'), { rz: Math.PI / 2, ry: r() * 6, open: true }); makeProp(t, { mass: 0.15, name: 'Empty tin', desc: 'Tushonka — tinned beef. Opened with a knife.', sound: 'can' }); }
  }
  // pipes: the riser in the corner, rusted through at a joint, dripping
  cyl(0.045, 0.045, H, 10, M.rust, { x: 9.9, y: H / 2, z: 0.1 });
  cyl(0.025, 0.025, H, 8, M.rust, { x: 9.78, y: H / 2, z: 0.08 });
  box(0.12, 0.1, 0.12, M.rust, { x: 9.9, y: 1.4, z: 0.1 });
  cyl(0.012, 0.012, 2.3, 6, mat('gasPipe', { color: 0xc8a030, roughness: 0.6, metalness: 0.4 }), { x: 9.97, y: 1.15, z: 2.4, rx: Math.PI / 2 });
  // exposed wiring from a ripped-out socket
  { const pts = [V(7.69, 0.35, 3.1), V(7.71, 0.3, 3.2), V(7.75, 0.05, 3.25), V(7.9, 0.01, 3.3)]; const w = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 12, 0.004, 4), mat('wireRed', { color: 0x8a2a1a, roughness: 0.6 })); w.castShadow = true; G.scene.add(w); box(0.06, 0.06, 0.02, mat('socket', { color: 0x9a9480, roughness: 0.6 }), { x: 7.68, y: 0.35, z: 3.1, ry: Math.PI / 2 }); }
  DUST.shafts.push({ min: V(8.25, 0.0, 0.0), max: V(9.45, 2.35, 1.2), col: V(0.1, 0.12, 0.15) });
}

function radio(x, y, z) {
  const g = group({ x, y, z, ry: 0.3 });
  box(0.3, 0.17, 0.12, mat('radioCase', { map: woodTex('#4a2a18', 210, 1).map, roughness: 0.45 }), { y: 0.085, parent: g, static: false });
  box(0.16, 0.12, 0.005, mat('radioGrille', { map: fabricTex('#a89868', 211, 0).map, roughness: 1 }), { x: -0.05, y: 0.085, z: 0.061, parent: g, static: false });
  box(0.08, 0.03, 0.005, mat('dialGlass', { color: 0xe8d8a0, emissive: 0xffb050, emissiveIntensity: 0, roughness: 0.3 }), { x: 0.08, y: 0.12, z: 0.061, parent: g, static: false });
  const dialLamp = g.children[2];
  cyl(0.015, 0.015, 0.02, 10, M.bakelite, { x: 0.09, y: 0.05, z: 0.065, rx: Math.PI / 2, parent: g, static: false });
  let on = false, st = null, beepT = 4;
  const L = { switched: false };
  const pos = V(x, y + 0.1, z);
  onUpdate((dt) => {
    const live = on && G.circuits.B?.on;
    dialLamp.material.emissiveIntensity = live ? 0.8 : 0;
    if (!live) { if (st) { st.stop(); st = null; } return; }
    if (!st && AUDIO.ready) st = loopSource('static', pos, { vol: 0.05 });
    beepT -= dt;
    if (beepT <= 0) { // between stations: a carrier, pips in threes
      beepT = 11 + Math.random() * 8;
      for (let i = 0; i < 6; i++) sfx('click', pos, { vol: 0.5, rate: 0.35, delay: i * 0.33 + (i >= 3 ? 0.7 : 0), jitter: false });
    }
  });
  interactive(g.children, { prompt: () => (on ? 'Switch the radio off' : 'Switch the radio on'), use: () => { on = !on; L.switched = on; sfx('switch', pos, { vol: 0.5 }); if (on && !G.circuits.B?.on) G.ui.toast('The dial stays dark.'); if (on && G.circuits.B?.on && !G.flags.radio) { G.flags.radio = true; setTimeout(() => G.ui.toast('Every station is hiss. Under the hiss, somewhere, pips: three, then three.'), 4000); } } });
}

// ---------------------------------------------------------------- Sonya's room
function child() {
  const r = rng(6006);
  pendant('childLamp', 4.6, 6.6, 'C', { col: '#c8d8e0', k: 6 });
  wallSwitch(5.15, 1.1, 5.275, 0, ['childLamp']); // low: where she could reach it
  // night light in a socket: a little moon
  {
    const m = new THREE.Mesh(new THREE.CircleGeometry(0.035, 16, 0.6, 5.1), mat('moonLight', { color: 0xe8e0b0, emissive: 0xffe8a0, emissiveIntensity: 0, roughness: 0.4 }));
    m.position.set(6.325, 0.32, 7.6); m.rotation.y = -Math.PI / 2; G.scene.add(m);
    const l = new THREE.PointLight(0xffe0a0, 0.25, 2, 2); l.position.set(6.25, 0.33, 7.6);
    addLight('moon', l, { circuit: 'C', on: true, fixtures: [m], emissive: 2, virtual: true });
  }
  // the bed: the only bed in the flat that's made. Tightly. The bear tucked in.
  {
    const g = group({ x: 3.28, z: 7.05 });
    box(0.82, 0.3, 1.85, M.paintedBlue, { y: 0, base: true, parent: g });
    box(0.86, 0.75, 0.04, M.paintedBlue, { y: 0, base: true, z: 0.93, parent: g });
    rbox(0.78, 0.14, 1.8, 0.05, M.childBlanket, { y: 0.3, base: true, parent: g });
    rbox(0.5, 0.1, 0.3, 0.04, M.sheet, { y: 0.44, base: true, z: 0.7, parent: g });
    // a fold of sheet turned down over the blanket, square
    box(0.79, 0.02, 0.18, M.sheet, { y: 0.445, base: true, z: 0.45, parent: g });
    solid(3.28, 0, 7.05, 0.82, 0.48, 1.85);
    staticBox(3.28, 0.45, 7.05, 0.82, 0.04, 1.85);
    const bear = group({ x: 3.28, y: 0.45, z: 7.45 });
    const fur = mat('bearFur', { map: fabricTex('#8a6a42', 212, 0).map, roughness: 1 });
    sphere(0.1, fur, { y: 0.07, parent: bear, static: false }).scale.set(1, 0.7, 1.2);
    sphere(0.07, fur, { y: 0.1, z: 0.13, parent: bear, static: false });
    for (const s of [-1, 1]) sphere(0.025, fur, { x: s * 0.05, y: 0.16, z: 0.13, parent: bear, static: false });
    makeProp(bear, { mass: 0.3, name: 'Teddy bear', desc: 'Tucked in up to the chin, the sheet folded square over him. Somebody did this with great care, after she had gone.', sound: 'soft' });
    examine(g.children[2], 'Bed', 'Made. Hospital corners. Everything else in the flat has been left as it fell, but this bed has been made, and recently: there is no dust on it at all.');
  }
  // desk under the boarded window: the notebook, crayons, a mug of pencils
  {
    const g = group({ x: 4.6, z: 7.7 });
    box(1.1, 0.03, 0.55, M.pine, { y: 0.66, parent: g });
    for (const sx of [-0.52, 0.52]) box(0.03, 0.66, 0.55, M.pine, { x: sx, y: 0, base: true, parent: g });
    solid(4.6, 0, 7.7, 1.1, 0.7, 0.55);
    staticBox(4.6, 0.67, 7.7, 1.1, 0.02, 0.55);
    const nb = box(0.17, 0.01, 0.21, mat('notebook', { color: 0x3a6a9a, roughness: 0.8 }), { x: 4.45, y: 0.68, base: true, z: 7.65, ry: 0.2, static: false });
    makeProp(nb, { mass: 0.1, name: 'Exercise book', desc: 'Sonya Sokolova, class 2B.', sound: 'paper', doc: D.sonyaBook });
    const cols = [0xc02020, 0x2040c0, 0xe0c020, 0x208040, 0x2a2a2a, 0xe07020];
    for (let i = 0; i < 6; i++) { const c = cyl(0.005, 0.005, 0.09, 6, mat('crayon' + i, { color: cols[i], roughness: 0.7 }), { x: 4.8 + (r() - 0.5) * 0.15, y: 0.69, z: 7.6 + (r() - 0.5) * 0.1, rz: Math.PI / 2, ry: r() * 3, static: false }); void c; }
    chair(4.6, 7.25, Math.PI + 0.2, false);
  }
  // drawings pinned along the wall
  {
    const kinds = ['house', 'cat', 'sea', 'pipes'];
    kinds.forEach((k, i) => {
      const c = canvas(200, 150), g = c.getContext('2d');
      g.fillStyle = '#f2eee0'; g.fillRect(0, 0, 200, 150); g.lineWidth = 3; g.lineCap = 'round';
      if (k === 'house') { g.strokeStyle = '#3040a0'; g.strokeRect(60, 50, 80, 90); g.beginPath(); g.moveTo(55, 50); g.lineTo(100, 15); g.lineTo(145, 50); g.stroke(); g.fillStyle = '#e0c020'; g.fillRect(75, 70, 18, 18); g.fillRect(108, 70, 18, 18); }
      if (k === 'cat') { g.strokeStyle = '#e07020'; g.beginPath(); g.arc(100, 90, 35, 0, 6.28); g.stroke(); g.beginPath(); g.moveTo(75, 65); g.lineTo(80, 40); g.lineTo(92, 58); g.moveTo(108, 58); g.lineTo(120, 40); g.lineTo(125, 65); g.stroke(); }
      if (k === 'sea') { g.strokeStyle = '#2060c0'; for (let y = 80; y < 140; y += 15) { g.beginPath(); for (let x = 0; x < 200; x += 10) g.lineTo(x, y + Math.sin(x / 10) * 5); g.stroke(); } g.fillStyle = '#e0c020'; g.beginPath(); g.arc(160, 35, 18, 0, 6.28); g.fill(); }
      if (k === 'pipes') { g.strokeStyle = '#2a2a2a'; g.lineWidth = 6; g.beginPath(); g.moveTo(30, 0); g.lineTo(30, 150); g.moveTo(30, 75); g.lineTo(170, 75); g.lineTo(170, 150); g.stroke(); g.fillStyle = '#2a2a2a'; g.font = 'bold 22px sans-serif'; g.fillText('3', 60, 60); g.fillText('3', 120, 60); g.fillText('3', 60, 110); g.fillText('?', 120, 110); }
      const m = new THREE.Mesh(new THREE.PlaneGeometry(0.28, 0.21), new THREE.MeshStandardMaterial({ map: canvasTex(c), roughness: 0.9, side: THREE.DoubleSide }));
      m.position.set(6.322, 1.25 + (i % 2) * 0.08, 6.3 + i * 0.32); m.rotation.y = -Math.PI / 2; m.rotation.z = (r() - 0.5) * 0.12; G.scene.add(m);
      if (k === 'pipes') examine(m, 'Drawing', 'Pipes, in black crayon, drawn hard enough to tear the paper. Numbers by the joints: 3, 3, 3, and a question mark.');
      else examine(m, 'Drawing', ['A house with yellow windows.', 'Mittens? A cat, anyway, orange.', 'The sea and a big sun.'][i]);
    });
  }
  // toy box with a lid; toys on the floor
  {
    const g = carcass(0.75, 0.4, 0.45, M.paintedBlue, { x: 6.1, z: 7.05, ry: -Math.PI / 2 });
    const lid = group({ x: 0, y: 0.4, z: -0.22, parent: g });
    box(0.75, 0.025, 0.46, M.paintedBlue, { z: 0.23, parent: lid, static: false });
    let open = false;
    onUpdate((dt) => { lid.rotation.x += ((open ? -1.6 : 0) - lid.rotation.x) * Math.min(1, dt * 5); });
    interactive(lid.children, { prompt: () => (open ? 'Close the toy box' : 'Open the toy box'), use: () => { open = !open; sfx('cabinet', lid.getWorldPosition(V()), { rate: 0.6 }); } });
    for (let i = 0; i < 6; i++) { const b = box(0.05, 0.05, 0.05, mat('block' + (i % 3), { color: [0xc03020, 0x2050b0, 0xd0a020][i % 3], roughness: 0.6 }), { x: (r() - 0.5) * 0.5, y: 0.05, z: (r() - 0.5) * 0.25, ry: r(), parent: g, static: false }); pickable(b, { name: 'Wooden block', desc: 'A painted letter on each face.', mass: 0.05, sound: 'wood' }); }
    const doll = group({ x: 0.1, y: 0.06, z: 0, parent: g });
    rbox(0.08, 0.2, 0.05, 0.02, M.cloth[5], { y: 0.1, parent: doll, static: false }); sphere(0.04, mat('dollFace', {}), { y: 0.23, parent: doll, static: false });
    pickable(doll, { name: 'Rag doll', desc: 'One button eye. The other has been sewn back on with black thread, by an adult hand.', mass: 0.1, sound: 'soft' });
  }
  for (let i = 0; i < 5; i++) { const b = box(0.05, 0.05, 0.05, mat('block' + (i % 3), {}), { x: 4.8 + r() * 1.2, y: 0.025, z: 6.0 + r() * 1.2, ry: r() * 3, static: false }); makeProp(b, { mass: 0.05, name: 'Wooden block', desc: 'A painted letter on each face.', sound: 'wood' }); }
  const ball = sphere(0.09, mat('ball', { map: fabricTex('#c03030', 213, 2).map, roughness: 0.5 }), { x: 5.4, y: 0.09, z: 6.4, static: false });
  makeProp(ball, { mass: 0.2, shape: 'sphere', radius: 0.09, name: 'Ball', desc: 'Soft. It rolls a long way on these floors.', sound: 'soft', damp: 0.3, adamp: 0.2 });
  // a round rag rug
  const rug = new THREE.Mesh(new THREE.CircleGeometry(0.7, 28), mat('rugRound', { map: fabricTex('#8a6a5a', 214, 2).map, roughness: 1 })); rug.rotation.x = -Math.PI / 2; rug.position.set(4.6, 0.005, 6.6); rug.receiveShadow = true; G.scene.add(rug);
  // the streetlight outside coming through the slats of the boarded window, orange
  {
    const s = new THREE.SpotLight(0xffa850, 38, 22, 0.32, 0.5, 1.4);
    s.position.set(4.6, 3.2, 12); s.target.position.set(4.4, 0.4, 6.4);
    s.castShadow = true; s.userData.shadowTier = 'medium'; s.shadow.mapSize.set(1024, 1024); s.shadow.bias = -0.0008; s.shadow.camera.near = 3;
    addLight('street', s, { on: true, flicker: 'bulb', target: s.target.position });
    G.scene.add(s.target);
    DUST.shafts.push({ min: V(3.85, 0.5, 6.5), max: V(5.35, 2.4, 8.0), col: V(0.25, 0.14, 0.05), k: () => (G.lights.street?.k ?? 1) * 0.8 });
  }
  // her coat hook: empty. her school satchel: gone. one slipper under the bed
  const sl = rbox(0.07, 0.035, 0.16, 0.015, mat('childSlipper', { color: 0xc06080, roughness: 1 }), { x: 3.75, y: 0, base: true, z: 6.5, ry: 0.4, static: false });
  makeProp(sl, { mass: 0.05, name: 'Slipper', desc: 'Pink, with a rabbit face. Small.', sound: 'soft' });
}

// ---------------------------------------------------------------- bathroom
function bath() {
  const r = rng(7007);
  pendant('bathLamp', 9.0, 6.6, 'B', { broken: true, col: '#d8d8d0' });
  wallSwitch(9.6, 1.4, 5.13, Math.PI, ['bathLamp'], { brokenMsg: 'Click. Somewhere in there, glass tinkles. The fitting came down with the ceiling.', label: 'Bathroom light' });
  // the bath, full to within a hand of the rim with black water
  {
    const g = group({ x: 7.35, z: 7.62 });
    const e = M.enamel;
    box(1.7, 0.55, 0.05, e, { y: 0, base: true, z: 0.36, parent: g }); box(1.7, 0.55, 0.05, e, { y: 0, base: true, z: -0.36, parent: g });
    box(0.05, 0.55, 0.72, e, { x: -0.83, y: 0, base: true, parent: g }); box(0.05, 0.55, 0.72, e, { x: 0.83, y: 0, base: true, parent: g });
    box(1.62, 0.04, 0.64, e, { y: 0.08, parent: g });
    rbox(1.76, 0.04, 0.78, 0.02, e, { y: 0.55, base: true, parent: g, static: false }).visible = false;
    for (const [x, z] of [[-0.75, 0.3], [0.75, 0.3], [-0.75, -0.3], [0.75, -0.3]]) sphere(0.04, M.iron, { x, y: 0.03, z, parent: g });
    solid(7.35, 0, 7.62, 1.7, 0.55, 0.76);
    const water = box(1.6, 0.01, 0.64, M.water, { y: 0.46, parent: g, static: false, cast: false });
    // under it, at the bottom, once the water's gone
    const shoe = rbox(0.06, 0.05, 0.15, 0.02, mat('redShoe', {}), { x: 0.3, y: 0.1, base: true, z: 0.05, ry: 2.4, parent: g, static: false });
    const hair = new THREE.Mesh(new THREE.CircleGeometry(0.08, 10), mat('hairClump', { color: 0x2a2018, roughness: 1 })); hair.rotation.x = -Math.PI / 2; hair.position.set(-0.6, 0.101, 0); g.add(hair);
    shoe.visible = false;
    const keys = group({ x: -0.2, y: 0.1, z: -0.1, parent: g }); keys.visible = false;
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.018, 0.003, 4, 12), M.chrome); ring.rotation.x = Math.PI / 2; keys.add(ring);
    for (let i = 0; i < 3; i++) box(0.05 - i * 0.01, 0.003, 0.014, mat('keyBrass', { color: 0x9a8450, metalness: 0.8, roughness: 0.4 }), { x: 0.03 + i * 0.004, y: 0.003, z: (i - 1) * 0.012, ry: (i - 1) * 0.4, parent: keys, static: false });
    box(0.05, 0.006, 0.025, mat('fob', { color: 0x2a5a8a, roughness: 0.5 }), { x: -0.04, parent: keys, static: false });
    box(0.14, 0.05, 0.1, mat('hitbox', { transparent: true, opacity: 0, depthWrite: false }), { y: 0.02, parent: keys, static: false, cast: false }); // something to aim at
    const chain = [];
    for (let i = 0; i < 8; i++) { const ln = new THREE.Mesh(new THREE.TorusGeometry(0.006, 0.0015, 3, 6), M.chrome); ln.position.set(-0.78 + i * 0.008, 0.52 - i * 0.05, 0); ln.rotation.y = i % 2 * 1.5; g.add(ln); chain.push(ln); }
    let level = 0.46, drain = false;
    onUpdate((dt) => {
      if (!drain || level <= 0.105) return;
      level -= dt * 0.012; water.position.y = level; water.scale.y = 1;
      if (level < 0.16) shoe.visible = true;
      if (level <= 0.105) {
        water.visible = false; keys.visible = true;
        G.ui.toast('At the bottom, in the silt: the other red shoe. Right foot. And a ring of keys.');
        pickable(shoe, { name: "Child's shoe", desc: 'A girl’s red buckle shoe, right foot. The pair to the one in the hall.', mass: 0.2, sound: 'soft' });
        pickable(keys, { name: 'Keys', desc: 'His keys, on a plastic fob from the plant. Flat key, letterbox key, and a little brass one for a padlock. Somebody dropped them in the bath, or hid them there.', mass: 0.05, sound: 'can', onTake: () => { G.flags.key = true; } });
      }
    });
    // the overflow plate the chain hangs from: easier to find with a cold hand than the chain
    const plateO = cyl(0.03, 0.03, 0.01, 12, M.chrome, { x: -0.8, y: 0.56, z: 0, rz: Math.PI / 2, parent: g, static: false });
    const pull = () => {
      if (drain) { G.ui.toast('It’s draining. Slowly.'); return; }
      drain = true; sfx('plug', V(6.6, 0.3, 7.62), { vol: 1 }); setTimeout(() => sfx('plug', V(6.6, 0.3, 7.62), { vol: 0.8, rate: 0.8 }), 2600); setTimeout(() => sfx('plug', V(6.6, -1, 7.62), { vol: 0.6, rate: 0.6 }), 7000);
      G.ui.toast('You put your arm into the cold to the elbow and find the chain. Something gives. The water begins to turn.');
    };
    let looked = false;
    interactive([...chain, plateO], { prompt: () => (drain ? 'The plug chain' : 'Pull the plug'), range: 1.6, use: pull });
    interactive(water, {
      range: 1.8,
      prompt: () => (drain ? 'The bath' : looked ? 'Reach into the water' : 'Look at the bath'),
      use: () => {
        if (!looked) { looked = true; G.ui.toast('Full, to a hand’s width from the rim. Black and perfectly still. You can’t see the bottom. Someone filled it before the water went off — that’s what you did, here, when they warned you.', 7); return; }
        pull();
      },
    });
  }
  // basin, mirror cabinet, and on the mirror, drawn in soap: ||| |||
  {
    const g = group({ x: 9.75, z: 6.55, ry: -Math.PI / 2 });
    lathe([[0, 0], [0.08, 0], [0.06, 0.6], [0.0, 0.6]], 10, M.enamel, { parent: g });
    const basin = lathe([[0, 0.6], [0.2, 0.62], [0.26, 0.75], [0.27, 0.8], [0.24, 0.8], [0.18, 0.67], [0, 0.65]], 16, M.enamel, { parent: g });
    basin.scale.z = 0.75;
    cyl(0.01, 0.01, 0.12, 6, M.chrome, { y: 0.86, z: -0.18, parent: g });
    solid(9.75, 0, 6.55, 0.4, 0.8, 0.55);
    const cab = carcass(0.5, 0.6, 0.14, mat('cabWhite', { map: enamelTex('#dcd8cc', 18, 203).map, roughness: 0.5 }), { x: 0, y: 1.3, z: -0.18, parent: g, solid: false, shelves: [0.3] });
    const mirrorC = canvas(256, 300), mg = mirrorC.getContext('2d');
    mg.fillStyle = '#ffffff'; mg.fillRect(0, 0, 256, 300); mg.strokeStyle = 'rgba(240,240,230,1)'; mg.lineWidth = 8; mg.lineCap = 'round';
    mg.fillStyle = 'rgba(120,120,110,0.9)'; mg.fillRect(0, 0, 256, 300);
    mg.strokeStyle = 'rgba(230,228,215,0.85)'; for (const x of [50, 75, 100, 156, 181, 206]) { mg.beginPath(); mg.moveTo(x, 110); mg.lineTo(x + 3, 190); mg.stroke(); }
    const gr = mg.createRadialGradient(128, 150, 60, 128, 150, 190); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(40,40,30,0.8)'); mg.fillStyle = gr; mg.fillRect(0, 0, 256, 300);
    const d = cabDoor(cab, -0.24, 0.3, 0.48, 0.58, new THREE.MeshStandardMaterial({ map: canvasTex(mirrorC), roughness: 0.3, metalness: 0.85, color: 0x5a605c }), 1, { z: 0.075 });
    void d;
    examine(cab.children[0], 'Mirror', 'Six strokes drawn in soap on the glass: three, a gap, three.', { prompt: 'Look at the mirror' });
    const razor = box(0.1, 0.01, 0.04, M.chrome, { x: -0.1, y: 0.32, z: 0, parent: cab, static: false });
    pickable(razor, { name: 'Razor', desc: 'His. Rusted shut.', mass: 0.05, sound: 'can' });
    const inh = rbox(0.03, 0.09, 0.05, 0.01, mat('inhaler', { color: 0x3a6aaa, roughness: 0.4 }), { x: 0.1, y: 0.03, z: 0, parent: cab, static: false });
    pickable(inh, { name: 'Inhaler', desc: 'Sonya’s salbutamol. Empty — shake it and nothing moves. The prescription is folded round it.', mass: 0.05, sound: 'soft', doc: D.prescription, take: true });
  }
  // the WC: you don't need to lift the lid. you can
  {
    const g = group({ x: 9.5, z: 7.7, ry: Math.PI });
    lathe([[0, 0], [0.15, 0], [0.12, 0.25], [0.19, 0.38], [0.2, 0.4], [0, 0.4]], 14, M.enamel, { parent: g }).scale.z = 1.3;
    rbox(0.42, 0.35, 0.18, 0.03, M.enamel, { y: 0.55, z: -0.25, parent: g });
    const lid = group({ y: 0.41, z: -0.18, parent: g });
    rbox(0.38, 0.02, 0.48, 0.02, mat('wcLid', { color: 0x4a3a2a, roughness: 0.5 }), { z: 0.24, parent: lid, static: false });
    solid(9.5, 0, 7.7, 0.42, 0.75, 0.6);
    let open = false, opened = 0;
    onUpdate((dt) => { lid.rotation.x += ((open ? -1.5 : 0) - lid.rotation.x) * Math.min(1, dt * 6); });
    interactive(lid.children, {
      prompt: () => (open ? 'Close the lid' : 'Lift the lid'),
      use: () => {
        open = !open; sfx('cabinet', lid.getWorldPosition(V()), { rate: 0.5 });
        if (open) { opened++; setTimeout(() => { sfx('plug', V(9.5, 0, 7.7), { vol: 0.5, rate: 1.6 }); G.ui.toast(opened === 1 ? 'Dark water, low in the bowl. As you look, its surface shivers — something struck the pipe, a long way down.' : 'The water trembles.'); knockSeq(V(9.5, -3, 7.8), [1], 0.6); }, 700); }
      },
    });
  }
  // the old washing machine, a Riga, top-loading
  {
    const g = group({ x: 6.85, z: 5.65 });
    rbox(0.55, 0.75, 0.55, 0.05, M.enamelCream, { y: 0.375, parent: g });
    cyl(0.2, 0.2, 0.02, 18, M.chrome, { y: 0.76, parent: g });
    solid(6.85, 0, 5.65, 0.55, 0.78, 0.55);
    staticBox(6.85, 0.77, 5.65, 0.55, 0.02, 0.55);
    const bucket = cyl(0.13, 0.11, 0.26, 14, M.rust, { x: 7.6, y: 0, base: true, z: 6.2, static: false, open: true });
    bucket.rotation.z = Math.PI / 2 - 0.1; bucket.position.y = 0.13;
    makeProp(bucket, { mass: 1, name: 'Bucket', desc: 'It was put here to catch the drip. Then the ceiling came down on it.', sound: 'metal' });
  }
  // towels stiff on a rail; pipes; a hot-water geyser with its flue
  box(0.6, 0.02, 0.02, M.chrome, { x: 6.48, y: 1.3, z: 6.6, ry: Math.PI / 2 });
  drape(0.08, 0.5, [{ x0: -0.04, x1: 0.04, z0: -0.25, z1: 0.25, top: 1.31 }], M.cloth[3], { x: 6.5, z: 6.6, y: 0, seed: 9, fall: 8, nx: 4, nz: 10 });
  { const t = new THREE.Mesh(new THREE.PlaneGeometry(0.45, 0.55, 4, 6), mat('towel', { map: fabricTex('#7a9a9a', 215, 1).map, roughness: 1, side: THREE.DoubleSide })); t.position.set(6.505, 1.05, 6.6); t.rotation.y = Math.PI / 2; G.scene.add(t); }
  cyl(0.03, 0.03, H, 8, M.rust, { x: 9.93, y: H / 2, z: 7.93 });
  cyl(0.018, 0.018, 3.4, 8, M.rust, { x: 8.2, y: 0.12, z: 7.95, rz: Math.PI / 2 });
  // the geyser: dead
  { const g = group({ x: 9.92, y: 1.6, z: 7.3, ry: -Math.PI / 2 }); rbox(0.38, 0.6, 0.22, 0.04, M.enamel, { parent: g }); cyl(0.06, 0.06, 0.8, 10, M.chrome, { y: 0.7, parent: g }); examine(g.children[0], 'Water heater', 'A gas geyser. The pilot is out. The gas is off at the main, the tap taped over with electrical tape — a neat, careful job.'); }
  // the dark: in here a little light falls through the hole from the flat above
  { const l = new THREE.PointLight(0x8a96a8, 0.35, 4, 2); l.position.set(7.75, H + 0.2, 6.3); addLight('aboveSpill', l, { on: true }); }
}

// ---------------------------------------------------------------- the box room
function storage() {
  const r = rng(8008);
  // steel shelving along the west wall: preserves, paint, tools, the hammer
  {
    const g = group({ x: 0.22, z: 6.65 });
    const st = mat('shelfSteel', { map: metalTex('#5a5a54', 1.0, 220).map, roughness: 0.7, metalness: 0.5 });
    for (const [x, z] of [[-0.18, -0.65], [0.18, -0.65], [-0.18, 0.65], [0.18, 0.65]]) box(0.03, 1.9, 0.03, st, { x, y: 0.95, z, parent: g });
    const levels = [0.15, 0.6, 1.05, 1.5, 1.85];
    for (const y of levels) box(0.4, 0.015, 1.35, st, { y, parent: g });
    solid(0.22, 0, 6.65, 0.4, 1.9, 1.35);
    for (const y of levels) staticBox(0.22, y + 0.01, 6.65, 0.4, 0.02, 1.35);
    const preserve = [mat('jam', { color: 0x5a1a1a, roughness: 0.3 }), mat('pickles', {}), mat('tomato', { color: 0x8a2a14, roughness: 0.3 }), mat('apricot', { color: 0xb8701a, roughness: 0.3 })];
    for (const [y, n] of [[0.615, 7], [1.065, 5]]) for (let i = 0; i < n; i++) {
      const j = jar(0.22 + (r() - 0.5) * 0.1, y, 6.05 + i * 0.18, preserve[(r() * 4) | 0], { h: 0.13 + r() * 0.08, r: 0.04 + r() * 0.02 });
      makeProp(j, { mass: 0.7, name: 'Jar of preserves', desc: pickL(r, ['Cherry jam, Marta’s writing on the lid: 2019.', 'Pickled cucumbers, dill, garlic.', 'Tomatoes in their juice.', 'Apricot. The lid has blown — rust and sugar crust.']), sound: 'glassTink', breakable: true });
    }
    // a gap in the rows where jars have been taken and eaten: empty jars, washed, upside down
    for (let i = 0; i < 4; i++) { const j = jar(0.22, 1.515, 6.1 + i * 0.16, M.glass, { fill: 0 }); j.rotation.x = Math.PI; j.position.y = 1.65; makeProp(j, { mass: 0.4, name: 'Empty jar', desc: 'Washed out and turned upside down to dry.', sound: 'glassTink', breakable: true }); }
    const hammer = group({ x: 0.2, y: 0.165, z: 7.1 });
    box(0.3, 0.025, 0.025, M.pine, { parent: hammer, static: false }); box(0.03, 0.03, 0.1, M.iron, { x: 0.15, parent: hammer, static: false });
    makeProp(hammer, { mass: 0.6, name: 'Hammer', desc: 'A claw hammer and, under it, a paper bag of nails, mostly used. Fresh sawdust in the bag.', sound: 'metal' });
    for (let i = 0; i < 3; i++) { const p = cyl(0.08, 0.08, 0.12, 12, M.rust, { x: 0.22, y: 1.865, base: true, z: 6.2 + i * 0.3, static: false }); makeProp(p, { mass: 1, name: 'Paint tin', desc: 'Floor paint, brown. Rusted solid.', sound: 'metal' }); }
  }
  // the den: a sleeping bag, a crate for a table, candles, the stove, the cans
  {
    const bag = drape(0.75, 1.9, [{ x0: -0.3, x1: 0.3, z0: -0.9, z1: 0.9, top: 0.09 }], mat('sleepingBag', { map: fabricTex('#3a4a32', 221, 2).map, roughness: 0.9 }), { x: 1.5, z: 7.55, y: 0, ry: Math.PI / 2, seed: 15, wrinkle: 0.07, fall: 1.5 });
    void bag;
    rbox(0.42, 0.1, 0.28, 0.04, M.cloth[3], { x: 0.75, y: 0.0, base: true, z: 7.6, ry: 0.1 }); // a rolled jumper for a pillow
    const crate = carcass(0.5, 0.36, 0.38, M.pine, { x: 2.35, z: 6.6, ry: -Math.PI / 2 });
    box(0.5, 0.02, 0.38, M.pine, { y: 0.37, parent: crate });
    // candle: if you've found matches, light it
    const cnd = candle(2.35, 0.38, 6.55, 0.06);
    const flameM = mat('flame', { color: 0xffc060, emissive: 0xffa030, emissiveIntensity: 0, transparent: true, opacity: 0.9 });
    const flame = new THREE.Mesh(new THREE.SphereGeometry(0.008, 8, 6), flameM); flame.scale.set(1, 2.2, 1); flame.position.y = cnd.userData.top + 0.006; flame.visible = false; cnd.add(flame);
    const l = new THREE.PointLight(0xff9a40, 2.2, 5, 2); l.position.set(2.35, 0.55, 6.55); l.userData.shadowTier = 'high';
    const L = addLight('candle', l, { on: false, flicker: 'candle', fixtures: [flame], emissive: 3 });
    let fire = null;
    interactive(cnd.children, {
      prompt: () => (L.switched ? 'Pinch out the candle' : G.flags.matches ? 'Light the candle' : 'Candle'),
      use: () => {
        if (L.switched) { L.switched = false; flame.visible = false; fire?.stop(); fire = null; return; }
        if (!G.flags.matches) { G.ui.toast('A candle burnt almost to nothing. The wax round it is soft. You’d need something to light it.'); return; }
        L.switched = true; flame.visible = true; sfx('click', l.position, { rate: 0.5 }); if (AUDIO.ready) fire = loopSource('flame', l.position, { vol: 0.03 });
        if (!G.flags.lit) { G.flags.lit = true; G.ui.toast('The match flares and the room comes up out of the dark around you.'); }
      },
    });
    const stove = group({ x: 2.25, y: 0.38, z: 6.8 });
    cyl(0.06, 0.07, 0.08, 12, mat('campStove', { color: 0x4a6a3a, roughness: 0.6, metalness: 0.4 }), { y: 0.04, parent: stove, static: false });
    for (let i = 0; i < 3; i++) box(0.12, 0.008, 0.008, M.iron, { y: 0.085, ry: i * 1.05, parent: stove, static: false });
    makeProp(stove, { mass: 0.6, name: 'Camping stove', desc: 'The gas cartridge is light — nearly used up. These were sold at the army surplus shop by the station.', sound: 'metal' });
    for (let i = 0; i < 9; i++) { const t = can(1.9 + (r() - 0.5) * 0.7, 0, 6.2 + r() * 0.8, labelMat('stew2', '#5a6a3a', '#e8e0c8', 'ТУШЁНКА', 'army'), { open: true, rz: r() < 0.5 ? Math.PI / 2 : 0, ry: r() * 6 }); if (t.rotation.z) t.position.y = 0.037; makeProp(t, { mass: 0.15, name: 'Empty tin', desc: 'Army tushonka, the newer label. Scraped clean with a spoon.', sound: 'can' }); }
    sheet(D.denNote, 0.18, 0.23, { x: 2.42, y: 0.385, z: 6.72, rx: -Math.PI / 2, rz: 0.4, name: 'Note in pencil' });
    // Sonya's drawing for her dad, pinned to the wall above the bag where he could see it lying down
    sheet(D.drawing, 0.4, 0.29, { x: 2.725, y: 0.9, z: 7.5, ry: -Math.PI / 2, name: 'Drawing' });
    const torchB = cyl(0.015, 0.015, 0.05, 8, M.chrome, { x: 2.5, y: 0.385, z: 6.45, rz: Math.PI / 2, static: false });
    makeProp(torchB, { mass: 0.05, name: 'Battery', desc: 'Flat. Licked, the old way, to test it: nothing.', sound: 'can' });
    const blanketGone = null; void blanketGone;
  }
  // canisters and the smell of paraffin; an axe behind the door
  { const ax = group({ x: 2.55, y: 0.0, z: 5.45 }); box(0.04, 0.7, 0.03, M.pine, { y: 0.35, parent: ax, static: false }); box(0.15, 0.1, 0.02, M.iron, { y: 0.68, x: 0.05, parent: ax, static: false }); ax.rotation.z = 0.25; ax.position.x = 2.6; makeProp(ax, { mass: 1.5, name: 'Axe', desc: 'A hatchet from the dacha. Pale splinters of new pine stuck in the blade, the same wood as the boards over Sonya’s window.', sound: 'metal' }); }
}
function pickL(r, a) { return a[(r() * a.length) | 0]; }
