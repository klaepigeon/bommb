// Marta Sokolova, in the box room. Alive. Coral has come up out of her — out of her shoulders
// and arms and the side of her face and through her cardigan — and gone on into the wall and
// down into the floor, so that she is rooted where she sits. She breathes. Her fingers move.
//
// Built the way an old console would have drawn her: few polygons, flat-shaded, textures a
// handful of pixels across, vertices that snap to a coarse screen grid and swim when you move.
// Touch her face and she wakes, takes hold of you, and asks about the boxes. Then nothing; then
// the box room floor, and something on your left hand, and she isn't there any more.
import * as THREE from 'three';
import { G, mat, box, collider, interactive, onUpdate } from './core.js';
import { P } from './player.js';
import { canvas, rng } from './textures.js';
import { sfx, knockSeq, loopSource, AUDIO } from './audio.js';
import { say, startSocko, socko } from './voice.js';
import { HANDS } from './hands.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);

// ---------------------------------------------------------------- PS1 look
function psx(m, res = 160) {
  m.flatShading = true;
  const prev = m.onBeforeCompile;
  m.onBeforeCompile = (sh, r) => {
    prev?.call(m, sh, r);
    sh.vertexShader = sh.vertexShader.replace('#include <project_vertex>', `#include <project_vertex>
      { vec2 g = vec2(${res}.0, ${(res * 0.75) | 0}.0); gl_Position.xy = floor(gl_Position.xy / gl_Position.w * g + 0.5) / g * gl_Position.w; }`);
  };
  m.customProgramCacheKey = () => 'psx' + res;
  return m;
}
function pixTex(w, h, draw) {
  const c = canvas(w, h), g = c.getContext('2d'); draw(g, w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter; t.generateMipmaps = false;
  t.userData.canvas = c; return t;
}
const r = rng(4747);
const skinT = pixTex(32, 32, (g) => {
  g.fillStyle = '#9c9488'; g.fillRect(0, 0, 32, 32);
  for (let i = 0; i < 90; i++) { g.fillStyle = ['#8a8478', '#a8a094', '#7c8088', '#94887a'][(r() * 4) | 0]; g.fillRect((r() * 32) | 0, (r() * 32) | 0, 1 + (r() * 2 | 0), 1); }
  g.fillStyle = '#5c6a84'; for (let i = 0; i < 5; i++) { let x = (r() * 32) | 0; for (let y = 0; y < 32; y += 2) { g.fillRect(x, y, 1, 2); x += r() < 0.5 ? -1 : 1; } } // veins under it
  g.fillStyle = '#c86a5c'; for (let i = 0; i < 14; i++) g.fillRect((r() * 32) | 0, (r() * 32) | 0, 1, 1); // polyps starting
});
const cardiganT = pixTex(32, 32, (g) => { g.fillStyle = '#3c5470'; g.fillRect(0, 0, 32, 32); for (let y = 0; y < 32; y += 2) { g.fillStyle = 'rgba(0,0,0,0.18)'; g.fillRect(0, y, 32, 1); } for (let i = 0; i < 20; i++) { g.fillStyle = 'rgba(60,40,30,0.4)'; g.fillRect((r() * 32) | 0, (r() * 32) | 0, 2, 2); } });
const dressT = pixTex(32, 32, (g) => { g.fillStyle = '#c4bca8'; g.fillRect(0, 0, 32, 32); for (let i = 0; i < 24; i++) { g.fillStyle = ['#a87070', '#7a9070', '#b09060'][i % 3]; g.fillRect((r() * 30) | 0, (r() * 30) | 0, 2, 2); } for (let i = 0; i < 10; i++) { g.fillStyle = 'rgba(80,60,30,0.35)'; g.fillRect((r() * 28) | 0, (r() * 28) | 0, 4, 3); } });
const hairT = pixTex(16, 16, (g) => { g.fillStyle = '#3a2a20'; g.fillRect(0, 0, 16, 16); for (let x = 0; x < 16; x++) { g.fillStyle = r() < 0.5 ? '#2a1e16' : '#4a3628'; g.fillRect(x, 0, 1, 16); } g.fillStyle = '#7a7268'; g.fillRect(5, 0, 1, 16); });
function faceTex(awake) {
  return pixTex(32, 32, (g) => {
    g.fillStyle = '#a49c90'; g.fillRect(0, 0, 32, 32);
    g.fillStyle = '#7e7668'; g.fillRect(6, 10, 8, 5); g.fillRect(18, 10, 8, 5); // sunken sockets
    if (awake) { g.fillStyle = '#e8e6dc'; g.fillRect(8, 11, 5, 3); g.fillRect(19, 11, 5, 3); g.fillStyle = '#20242a'; g.fillRect(10, 12, 1, 1); g.fillRect(21, 12, 1, 1); }
    else { g.fillStyle = '#3e3832'; g.fillRect(7, 12, 6, 1); g.fillRect(19, 12, 6, 1); }
    g.fillStyle = '#8a8276'; g.fillRect(15, 13, 2, 7); g.fillStyle = '#6a6258'; g.fillRect(14, 19, 4, 1); // nose
    if (awake) { g.fillStyle = '#1a1010'; g.fillRect(12, 23, 8, 5); g.fillStyle = '#6a4a50'; g.fillRect(12, 22, 8, 1); }
    else { g.fillStyle = '#6a5a62'; g.fillRect(12, 24, 8, 1); g.fillStyle = '#585058'; g.fillRect(13, 25, 6, 1); }
    // coral breaking through her right cheek
    g.fillStyle = '#d07060'; g.fillRect(24, 16, 5, 6); g.fillStyle = '#f0dccc'; g.fillRect(26, 15, 2, 2); g.fillRect(28, 19, 1, 2);
    g.fillStyle = 'rgba(40,30,30,0.35)'; g.fillRect(0, 28, 32, 4);
  });
}

// ---------------------------------------------------------------- coral
// a branching growth from a point along a direction: tapering, forking, tips bleached white
function coral(parent, from, dir, len, rad, depth, m, tip, rr, bias = V(0, 0, 0)) {
  const to = from.clone().addScaledVector(dir, len);
  const geo = new THREE.CylinderGeometry(rad * 0.66, rad, len, 5, 1); const seg = new THREE.Mesh(geo, depth <= 1 ? tip : m);
  seg.position.copy(from).add(to).multiplyScalar(0.5); seg.quaternion.setFromUnitVectors(V(0, 1, 0), dir.clone().normalize());
  seg.castShadow = true; parent.add(seg);
  if (depth <= 0) { const knob = new THREE.Mesh(new THREE.IcosahedronGeometry(rad * 0.9, 0), tip); knob.position.copy(to); parent.add(knob); return; }
  const n = rr() < 0.35 ? 3 : 2;
  for (let i = 0; i < n; i++) {
    const d = dir.clone().add(V((rr() - 0.5) * 1.3, (rr() - 0.3) * 0.9, (rr() - 0.5) * 1.3)).add(bias).normalize();
    coral(parent, to, d, len * (0.6 + rr() * 0.25), rad * 0.66, depth - 1, m, tip, rr, bias);
  }
}

// ---------------------------------------------------------------- her
export function buildMarta() {
  const g = new THREE.Group(); G.scene.add(g); g.userData.noBake = true;
  const skin = psx(new THREE.MeshStandardMaterial({ map: skinT, roughness: 0.8 }));
  const card = psx(new THREE.MeshStandardMaterial({ map: cardiganT, roughness: 1 }));
  const dress = psx(new THREE.MeshStandardMaterial({ map: dressT, roughness: 1 }));
  const hair = psx(new THREE.MeshStandardMaterial({ map: hairT, roughness: 0.9 }));
  const faceA = faceTex(false), faceB = faceTex(true);
  const face = psx(new THREE.MeshStandardMaterial({ map: faceA, roughness: 0.8 }));
  const cor = psx(new THREE.MeshStandardMaterial({ color: 0xd8705e, roughness: 0.7, emissive: 0x401810, emissiveIntensity: 0.3 }));
  const cor2 = psx(new THREE.MeshStandardMaterial({ color: 0xb84a58, roughness: 0.7 }));
  const tip = psx(new THREE.MeshStandardMaterial({ color: 0xf2e6d4, roughness: 0.5, emissive: 0x3a3028, emissiveIntensity: 0.25 }));
  const parts = [];
  const limb = (a, b, r0, r1, m, segs = 6, par = g) => {
    const len = a.distanceTo(b), geo = new THREE.CylinderGeometry(r1, r0, len, segs, 1);
    const mesh = new THREE.Mesh(geo, m); mesh.position.copy(a).add(b).multiplyScalar(0.5);
    mesh.quaternion.setFromUnitVectors(V(0, 1, 0), b.clone().sub(a).normalize()); mesh.castShadow = true; mesh.receiveShadow = true; par.add(mesh); parts.push(mesh); return mesh;
  };
  const joint = (p, r0, m, par = g) => { const s = new THREE.Mesh(new THREE.IcosahedronGeometry(r0, 1), m); s.position.copy(p); par.add(s); parts.push(s); return s; };
  // proportions of a woman of about 1.65 m, sitting on the floor with her back to the wall,
  // facing into the room, under the rows of scratched days
  const W = 2.71, Z = 5.95;
  // torso: hips, waist, ribs, shoulders — a lathe, flattened front to back
  const torso = new THREE.Group(); torso.position.set(2.5, 0.1, Z); torso.rotation.z = 0.32; g.add(torso); // leaning back against the wall
  const prof = [[0.0, 0.0], [0.16, 0.0], [0.175, 0.08], [0.15, 0.2], [0.125, 0.27], [0.15, 0.36], [0.16, 0.43], [0.17, 0.49], [0.13, 0.53], [0.05, 0.56], [0.0, 0.56]];
  const torsoM = new THREE.Mesh(new THREE.LatheGeometry(prof.map(([x, y]) => new THREE.Vector2(x, y)), 8), card); torsoM.scale.z = 0.7; torsoM.rotation.y = Math.PI / 2; torso.add(torsoM); parts.push(torsoM);
  const chest = torsoM; // breathes
  // the nightdress hem across the lap
  const hem = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.22, 0.12, 8, 1, true), dress); hem.position.set(-0.02, 0.04, 0); hem.scale.z = 0.8; torso.add(hem);
  // neck and head, hanging forward and to one side
  const neckBase = V(0, 0.56, 0), headP = new THREE.Group(); headP.position.copy(neckBase); torso.add(headP);
  headP.rotation.set(0.15, 0, -0.75); // chin down on the chest
  limb(V(0, 0, 0), V(0, 0.09, 0), 0.045, 0.04, skin, 6, headP);
  const head = new THREE.Group(); head.position.y = 0.16; headP.add(head);
  const skull = new THREE.Mesh(new THREE.IcosahedronGeometry(0.095, 1), face); skull.scale.set(0.9, 1.12, 0.95); head.add(skull); parts.push(skull);
  skull.rotation.y = -Math.PI / 2; // face texture forward (-x, into the room)
  const jaw = new THREE.Mesh(new THREE.IcosahedronGeometry(0.06, 1), skin); jaw.position.set(-0.03, -0.07, 0); jaw.scale.set(0.9, 0.6, 1.1); head.add(jaw);
  // hair: a cap and lank strands across the face
  const cap = new THREE.Mesh(new THREE.SphereGeometry(0.1, 7, 5, 0, Math.PI * 2, 0, Math.PI * 0.55), hair); cap.position.set(0.012, 0.02, 0); cap.scale.set(0.95, 1.1, 1.0); head.add(cap);
  for (let i = 0; i < 9; i++) { const s = new THREE.Mesh(new THREE.BoxGeometry(0.008, 0.16 + r() * 0.14, 0.02), hair); s.position.set(-0.07 + r() * 0.03, -0.06 - r() * 0.05, (i - 4) * 0.02); s.rotation.z = (r() - 0.5) * 0.3; head.add(s); }
  // arms: the left in her lap, the right lying along the floor, palm up, rooted in coral
  const sh = (s) => V(2.62, 0.58, Z + s * 0.17);
  const lEl = V(2.36, 0.33, Z + 0.22), lWr = V(2.1, 0.26, Z + 0.08);
  limb(sh(1), lEl, 0.045, 0.04, card); joint(lEl, 0.04, card); limb(lEl, lWr, 0.037, 0.03, card);
  const rEl = V(2.5, 0.2, Z - 0.3), rWr = V(2.2, 0.04, Z - 0.48);
  limb(sh(-1), rEl, 0.045, 0.04, card); joint(rEl, 0.04, card); const rFore = limb(rEl, rWr, 0.037, 0.03, skin);
  // hands with five fingers each, knuckles and all
  const hand = (wr, dir, up, side) => {
    const h = new THREE.Group(); h.position.copy(wr); g.add(h);
    h.quaternion.setFromUnitVectors(V(1, 0, 0), dir.clone().normalize());
    const palm = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.022, 0.07), skin); palm.position.x = 0.04; h.add(palm); parts.push(palm);
    const fingers = [];
    [-0.027, -0.009, 0.009, 0.027].forEach((z, i) => {
      const f = new THREE.Group(); f.position.set(0.08, 0, z * side); h.add(f);
      const L = [0.04, 0.045, 0.042, 0.033][i];
      limb(V(0, 0, 0), V(L, -0.01, 0), 0.008, 0.007, skin, 4, f); limb(V(L, -0.01, 0), V(L * 1.6, -0.03, 0), 0.007, 0.006, skin, 4, f);
      fingers.push(f);
    });
    const th = new THREE.Group(); th.position.set(0.03, 0, 0.04 * side); th.rotation.y = -0.7 * side; h.add(th);
    limb(V(0, 0, 0), V(0.04, 0, 0), 0.009, 0.008, skin, 4, th);
    return { h, fingers };
  };
  const lHand = hand(lWr, V(-1, -0.4, -0.5), 0, 1);
  const rHand = hand(rWr, V(-1, -0.15, -0.3), 0, -1);
  // legs: thighs along the floor, knees a little up, shins, bare feet
  for (const s of [1, -1]) {
    const hip = V(2.48, 0.12, Z + s * 0.1), knee = V(2.05, 0.24, Z + s * 0.14), ank = V(1.66, 0.05, Z + s * 0.16);
    limb(hip, knee, 0.075, 0.055, dress); joint(knee, 0.052, skin); limb(knee, ank, 0.05, 0.035, skin);
    const foot = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.05, 0.2), skin); foot.position.set(ank.x - 0.02, 0.035, ank.z); foot.rotation.set(0, Math.PI / 2, 0.5); g.add(foot);
  }
  // the coral. Out of the left shoulder and on up the wall; down the right arm and into the floor;
  // through the cardigan at the ribs; along the jaw; out of both knees; spreading over the tally marks
  const cg = new THREE.Group(); g.add(cg);
  const rr = rng(4748);
  coral(cg, sh(1).add(V(0.02, 0.04, 0)), V(0.25, 1, 0.2).normalize(), 0.2, 0.042, 5, cor, tip, rr, V(0.5, 0.4, 0));
  coral(cg, sh(1).add(V(0.05, 0.1, 0.05)), V(0.6, 1, -0.3).normalize(), 0.24, 0.045, 4, cor2, tip, rr, V(0.7, 0.2, 0));
  for (let i = 0; i < 6; i++) coral(cg, V(W - 0.02, 0.95 + i * 0.16, Z - 0.3 + rr() * 0.7), V(0.15, 1, (rr() - 0.5)).normalize(), 0.14, 0.026, 3, i % 2 ? cor : cor2, tip, rr, V(0.6, 0, 0));
  coral(cg, rEl.clone(), V(-0.3, 0.6, -0.5).normalize(), 0.15, 0.032, 4, cor, tip, rr);
  coral(cg, rWr.clone(), V(-0.2, -0.3, -0.6).normalize(), 0.1, 0.02, 3, cor2, tip, rr, V(0, -1.2, 0)); // rooting her hand to the floor
  for (let i = 0; i < 7; i++) coral(cg, V(2.3 - rr() * 0.5, 0.0, Z - 0.35 - rr() * 0.25), V((rr() - 0.5), 0.25, (rr() - 0.5)).normalize(), 0.11, 0.022, 3, cor, tip, rr, V(0, -0.3, 0));
  coral(cg, V(2.42, 0.38, Z - 0.1), V(-0.6, 0.6, -0.4).normalize(), 0.14, 0.03, 4, cor2, tip, rr);
  for (const s of [1, -1]) coral(cg, V(2.05, 0.28, Z + s * 0.14), V(-0.2, 1, s * 0.3).normalize(), 0.12, 0.028, 3, cor, tip, rr);
  // more: out of her neck and jaw, her left forearm, her shins, her left hand in her lap
  coral(cg, V(2.55, 0.72, Z - 0.05), V(-0.3, 1, -0.6).normalize(), 0.1, 0.022, 3, cor2, tip, rr);
  coral(cg, lEl.clone().lerp(lWr, 0.5), V(-0.2, 1, 0.5).normalize(), 0.11, 0.024, 3, cor, tip, rr);
  coral(cg, lWr.clone(), V(-0.6, 0.8, 0.1).normalize(), 0.09, 0.02, 3, cor2, tip, rr);
  for (const s of [1, -1]) coral(cg, V(1.85, 0.16, Z + s * 0.15), V(-0.3, 0.8, s * 0.5).normalize(), 0.08, 0.02, 2, cor, tip, rr);
  // polyps: little knots of it all over her
  const polG = new THREE.IcosahedronGeometry(0.016, 0); const pol = new THREE.InstancedMesh(polG, cor, 260); const mm = new THREE.Matrix4();
  for (let i = 0; i < 260; i++) { const p = parts[(rr() * parts.length) | 0]; const v = new THREE.Vector3((rr() - 0.5) * 0.08, (rr() - 0.5) * 0.15, (rr() - 0.5) * 0.08); p.updateWorldMatrix(true, false); v.applyMatrix4(p.matrixWorld); mm.makeTranslation(v.x, v.y, v.z); pol.setMatrixAt(i, mm); }
  g.add(pol);
  // the floor round her: an old stain, and the coral feeding into the cracks
  const st = new THREE.Mesh(new THREE.CircleGeometry(0.6, 12), psx(new THREE.MeshStandardMaterial({ color: 0x3a2a24, roughness: 1, transparent: true, opacity: 0.7, depthWrite: false }))); st.rotation.x = -Math.PI / 2; st.scale.set(1.3, 0.9, 1); st.position.set(2.25, 0.004, Z - 0.1); g.add(st);
  const col = collider({ x: 2.47, z: Z, hx: 0.25, hz: 0.33, y0: 0, y1: 1.3 });
  g.updateMatrixWorld(true);

  // ---- alive: she breathes; her fingers move; the coral listens
  let breath = null;
  const M = { g, head, headP, skull, face, faceA, faceB, chest, lHand, rHand, rFore, cg, col, awake: 0, state: 'asleep' };
  onUpdate((dt, t) => {
    if (!g.visible) return;
    const b = Math.sin(t * 0.75);
    chest.scale.set(1 + b * 0.025, 1 + b * 0.012, 0.7 * (1 + b * 0.04));
    if (M.state === 'asleep') {
      headP.rotation.z = -0.75 + Math.sin(t * 0.37) * 0.015;
      if (Math.random() < dt * 0.25) { const f = lHand.fingers[(Math.random() * 4) | 0]; f.rotation.z = -0.4; setTimeout(() => { f.rotation.z = 0; }, 140); }
    }
    cg.scale.setScalar(1 + Math.sin(t * 0.75 + 0.6) * 0.012);
    if (AUDIO.ready && !breath && G.playerZone === 'storage') breath = loopSource('flame', V(2.4, 0.9, Z), { vol: 0.045, ref: 0.6 });
    if (breath) breath.set(G.playerZone === 'storage' || G.playerZone === 'living' ? 0.02 + Math.max(0, b) * 0.05 : 0, 0.3);
  });
  M.stopBreath = () => { breath?.stop(); breath = null; };

  // ---- first sight
  let seen = false, inRoomT = 0;
  const to = new THREE.Vector3(), fwd = new THREE.Vector3();
  onUpdate((dt) => {
    if (seen || G.cutscene || !g.visible) return;
    if (G.playerZone !== 'storage') { inRoomT = 0; return; }
    inRoomT += dt;
    G.camera.getWorldDirection(fwd); to.set(2.45, 0.8, Z).sub(G.camera.position);
    if (inRoomT > 0.25 && (fwd.dot(to.clone().normalize()) > 0.55 || inRoomT > 2.5)) { seen = true; firstSight(); }
  });
  // ---- looking, and touching
  let looks = 0;
  M.it = interactive(parts.concat([cg]), {
    range: 2.2,
    prompt: () => (M.state !== 'asleep' ? '' : looks === 0 ? 'Look at her' : 'Touch her face'),
    use: () => {
      if (M.state !== 'asleep') return;
      if (looks === 0) {
        looks++;
        G.ui.read({ text: 'Marta Sokolova. The blue cardigan, the nightdress with the little flowers, the photographs in the hall: it’s her.\n\nShe is sitting on the floor with her back to the wall, under the rows of scratched days, her chin on her chest. Coral has come up out of her. Out of her left shoulder in a thick branching fan that has gone on up the wall and over the tally marks. Down her right arm, and out through the palm of her right hand, and into the cracks in the floor, so that she is held where she sits. Through the cardigan at her ribs. Along her jaw, through her cheek. Out of both knees. Little pink knots of it all over her skin, like goose-flesh.\n\nShe is breathing. Slowly. You can hear it, wet, from the doorway.\n\nShe is warm.' });
        return;
      }
      touch(M);
    },
  });
  G.marta = M;
  return M;
}

function firstSight() {
  G.flags.foundMarta = true;
  sfx('sting', V(2.4, 1.0, 5.95), { vol: 1.1, jitter: false }); G.shake = 0.55; G.rumble?.(0.9, 600);
  G.forceLook = { target: V(2.45, 0.8, 5.95), t: 0.9 };
  for (let i = 0; i < 9; i++) sfx('heart', null, { vol: 0.55 - i * 0.04, delay: 0.8 + i * (0.75 + i * 0.03), jitter: false });
  G.ui.toast('Christ.', 2.2);
  setTimeout(() => G.ui.toast('She’s breathing.', 4), 2600);
  setTimeout(() => { G.lightsKill = 0.6; }, 3400);
  setTimeout(() => knockSeq(V(9.9, 1.5, 0.3), [3, 3], 0.6), 4400);
  G.addDecay?.(0.08);
}

// ---------------------------------------------------------------- touch her face
function touch(M) {
  M.state = 'touching'; G.lockPlayer = true;
  const face = new THREE.Vector3(); M.skull.getWorldPosition(face);
  G.forceLook = { target: face.clone(), t: 1.6 };
  const cam = G.camera, local = () => cam.worldToLocal(face.clone());
  // your hand goes out, slowly, fingers open
  let t = 0;
  const step = (dt) => {
    t += dt;
    if (t < 1.6) { const k = Math.min(1, t / 1.5), p = local(); G.handPose = { pos: new THREE.Vector3(0.22, -0.3, -0.2).lerp(p.add(new THREE.Vector3(0.02, -0.03, 0.12)), k * k * (3 - 2 * k)), curl: 0.15, rot: new THREE.Euler(0.2, 0.3, -0.4) }; return; }
    if (M.removed) { if (t > 7.6) { G.updates.splice(G.updates.indexOf(step), 1); wake(); } return; }
    if (M.state === 'touching') {
      // she wakes
      M.state = 'awake'; M.face.map = M.faceB; M.face.needsUpdate = true;
      sfx('sting', face, { vol: 1.3, rate: 1.15, jitter: false }); sfx('doorStuck', face, { vol: 1 }); G.shake = 1.0; G.rumble?.(1, 900);
      G.lightsKill = 0.25;
    }
    // head snaps up to you; her hand comes off the floor, tearing coral, and takes your wrist
    const k = Math.min(1, (t - 1.6) / 0.18);
    M.headP.rotation.z = -0.75 + k * 0.95; M.headP.rotation.y = k * 0.35;
    const wrist = new THREE.Vector3(); HANDS.right.wrist.getWorldPosition(wrist);
    M.rHand.h.position.lerp(wrist, Math.min(1, (t - 1.6) * 5));
    M.rFore.visible = false;
    for (const f of M.rHand.fingers) f.rotation.z = -1.1;
    // pulled toward her
    const pull = Math.min(1, (t - 1.6) / 0.5) * 0.28;
    G.pullTo = { target: face.clone(), k: pull };
    if (G.handPose) { G.handPose.pos.x += (Math.random() - 0.5) * 0.01; G.handPose.pos.y += (Math.random() - 0.5) * 0.01; G.handPose.curl = 0.6; }
    if (t > 2.2 && !M.spoke) { M.spoke = true; showHer('Have you seen the boxes?'); say('Have you seen the boxes?', 'marta'); }
    if (t > 4.4 && !M.spoke2) { M.spoke2 = true; showHer('The boxes.'); say('The boxes.', 'marta'); G.lightsKill = 0.15; }
    if (t > 5.6 && !M.gone) { M.gone = true; G.blackout = 4.2; G.audioDuck?.(4); }
    if (t > 6.6 && !M.removed) { M.removed = true; remove(M); }
  };
  G.updates.push(step);
}
function showHer(text) {
  const el = document.getElementById('socko'); el.querySelector('b').textContent = ''; el.querySelector('span').textContent = text; el.classList.add('on', 'her');
  clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove('on', 'her'), 2600);
}
function remove(M) {
  // she isn't there. Not the coral, not the stain. Only the rows of days on the wall
  M.g.visible = false; M.col.on = false; M.stopBreath();
  if (M.it) M.it.disabled = true;
  G.handPose = null; G.pullTo = null; G.forceLook = null;
  const c = G.lights.candle; if (c) { c.switched = false; c.fixtures.forEach((f) => { f.visible = false; }); }
}

// ---------------------------------------------------------------- waking up
function wake() {
  // on the floor of the box room, looking at the ceiling, getting up
  P.pos.set(1.35, 0, 6.7); P.floorY = 0; P.yaw = Math.PI * 0.5; P.vel.set(0, 0, 0);
  G.flags.socko = true;
  let t = 0;
  const step = (dt) => {
    t += dt;
    const k = Math.min(1, t / 4.2), e = k * k * (3 - 2 * k);
    // lying -> sitting -> standing; the camera follows
    P.pitch = 1.25 * (1 - e) + -0.05 * e;
    G.eyeOverride = 0.25 + e * (P.height - 0.33);
    G.rollOverride = (1 - e) * 0.5;
    // the left hand comes up into view first: what's on it
    G.wakePose = t < 3.2 ? { pos: new THREE.Vector3(-0.12, -0.12 + (1 - e) * 0.06, -0.32), rot: new THREE.Euler(0.4, -1.0, 0.2) } : null;
    if (t > 0.3 && !step.s1) { step.s1 = true; sfx('breath', null, { vol: 0.5 }); }
    if (t > 1.6 && !step.s2) { step.s2 = true; startSocko(); }
    if (t > 4.4) { G.updates.splice(G.updates.indexOf(step), 1); G.eyeOverride = null; G.rollOverride = null; G.wakePose = null; G.lockPlayer = false; G.ui.toast('The box room. She isn’t there. Nothing is, where she was.', 5); }
  };
  G.updates.push(step);
  void socko; void mat; void box;
}
