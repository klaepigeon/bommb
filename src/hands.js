// Your hands, in front of you the whole time: coat sleeves, bare hands, the torch in the
// right one, whatever you've picked up held in it. The left one, after you wake on the box
// room floor, wears Socko. Hands sway with breathing and walking, lag behind your look, reach
// for whatever you use, and are drawn on top of the world so they never sink into a wall.
import * as THREE from 'three';
import { G, mat, onUpdate } from './core.js';
import { P } from './player.js';
import { VOICE } from './voice.js';
import { canvas, fabricTex } from './textures.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
export const HANDS = { root: null, right: null, left: null, sock: null };
const ORDER = 1000;
function own(m) { m.renderOrder = ORDER; m.castShadow = false; m.receiveShadow = false; m.frustumCulled = false; m.userData.static = false; m.traverse?.((c) => { c.renderOrder = ORDER; c.castShadow = false; c.frustumCulled = false; }); return m; }

// ---------------------------------------------------------------- materials
function skinTex(seed, base = '#c49a80') {
  const c = canvas(64, 64), g = c.getContext('2d'); g.fillStyle = base; g.fillRect(0, 0, 64, 64);
  for (let i = 0; i < 260; i++) { g.fillStyle = `rgba(${120 + Math.random() * 60},${70 + Math.random() * 40},${60},${Math.random() * 0.12})`; g.fillRect(Math.random() * 64, Math.random() * 64, 2, 2); }
  g.strokeStyle = 'rgba(90,100,140,0.18)'; for (let i = 0; i < 6; i++) { g.beginPath(); g.moveTo(Math.random() * 64, 0); g.bezierCurveTo(Math.random() * 64, 20, Math.random() * 64, 40, Math.random() * 64, 64); g.stroke(); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function sockTex() {
  const c = canvas(128, 128), g = c.getContext('2d');
  g.fillStyle = '#d8d2c4'; g.fillRect(0, 0, 128, 128);
  for (let x = 0; x < 128; x += 4) { g.fillStyle = 'rgba(0,0,0,0.07)'; g.fillRect(x, 0, 2, 128); } // ribbing
  for (let y = 0; y < 128; y += 3) { g.fillStyle = 'rgba(255,255,255,0.05)'; g.fillRect(0, y, 128, 1); }
  // a lifetime of floors
  for (let i = 0; i < 9; i++) { g.fillStyle = `rgba(${90 + Math.random() * 40},${70 + Math.random() * 30},${40},${0.12 + Math.random() * 0.2})`; g.beginPath(); g.ellipse(Math.random() * 128, 40 + Math.random() * 88, 6 + Math.random() * 16, 4 + Math.random() * 10, Math.random() * 3, 0, 6.28); g.fill(); }
  // cuff stripes, red and blue
  g.fillStyle = '#a8322a'; g.fillRect(0, 6, 128, 7); g.fillStyle = '#2c4a8a'; g.fillRect(0, 17, 128, 6);
  g.fillStyle = '#5a4a3a'; g.beginPath(); g.arc(90, 100, 4, 0, 6.28); g.fill(); // a hole, darned badly
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

// ---------------------------------------------------------------- a hand
// fingers are chains of capsules; curl 0 = flat, 1 = fist
function finger(parent, x, z, lens, r, m) {
  const segs = []; let p = parent, zz = z;
  lens.forEach((L, i) => {
    const j = new THREE.Group(); j.position.set(i ? 0 : x, 0, i ? -lens[i - 1] : zz); p.add(j);
    const s = own(new THREE.Mesh(new THREE.CapsuleGeometry(r * (1 - i * 0.12), L - r, 3, 8), m)); s.rotation.x = Math.PI / 2; s.position.z = -L / 2; j.add(s);
    segs.push(j); p = j;
  });
  return segs;
}
function makeHand(side) {
  // a little light of their own: your hands are always the thing you can see
  const skin = new THREE.MeshStandardMaterial({ map: skinTex(side), roughness: 0.62, color: 0xffffff, emissive: 0x6a5040, emissiveIntensity: 0.22 });
  const sleeve = mat('coatSleeve', { map: fabricTex('#4a3a2c', 240, 0).map, roughness: 1, emissive: 0x2a2018, emissiveIntensity: 0.35 });
  const cuff = mat('shirtCuff', { map: fabricTex('#b8b4a8', 241, 0).map, roughness: 1 });
  const arm = new THREE.Group();
  // forearm in a coat sleeve, the shirt cuff showing
  const fa = own(new THREE.Mesh(new THREE.CapsuleGeometry(0.048, 0.36, 4, 10), sleeve)); fa.rotation.x = Math.PI / 2; fa.position.z = 0.17; fa.scale.set(1, 1, 0.9); arm.add(fa);
  const cf = own(new THREE.Mesh(new THREE.CylinderGeometry(0.041, 0.043, 0.035, 12), cuff)); cf.rotation.x = Math.PI / 2; cf.position.z = -0.02; arm.add(cf);
  const wrist = new THREE.Group(); wrist.position.z = -0.045; arm.add(wrist);
  const palm = own(new THREE.Mesh(new THREE.CapsuleGeometry(0.03, 0.05, 4, 8), skin)); palm.rotation.x = Math.PI / 2; palm.scale.set(1.45, 0.62, 1); palm.position.z = -0.045; wrist.add(palm);
  const fingers = [-0.026, -0.009, 0.008, 0.025].map((x, i) => finger(wrist, x * side, -0.085, [0.043, 0.028, 0.022].map((l) => l * [0.95, 1.05, 1.0, 0.82][i]), 0.0085, skin));
  const thumbBase = new THREE.Group(); thumbBase.position.set(-0.033 * side, -0.006, -0.03); thumbBase.rotation.y = 0.7 * side; wrist.add(thumbBase);
  const thumb = finger(thumbBase, 0, 0, [0.032, 0.026], 0.0095, skin);
  return { arm, wrist, palm, fingers, thumb, thumbBase, skin, side, curl: 0.4, target: { pos: V(), curl: 0.4, rot: new THREE.Euler() } };
}
function curlHand(h, c, spread = 0) {
  h.fingers.forEach((f, i) => f.forEach((j, k) => { j.rotation.x = -c * [0.9, 1.3, 1.0][k] * (1 + i * 0.06); j.rotation.y = k === 0 ? (i - 1.5) * 0.07 * spread * h.side : 0; }));
  h.thumb.forEach((j, k) => { j.rotation.x = -c * 0.7 * (k + 1) * 0.6; });
}

// ---------------------------------------------------------------- Socko
function makeSock() {
  const tex = sockTex();
  const m = new THREE.MeshStandardMaterial({ map: tex, roughness: 0.95, emissive: 0x2a2620, emissiveIntensity: 0.6 });
  const g = new THREE.Group();
  // the body of the sock: over the wrist and hand, a soft tube
  const body = own(new THREE.Mesh(new THREE.LatheGeometry([[0.05, 0], [0.056, 0.06], [0.052, 0.14], [0.055, 0.2], [0.05, 0.24]].map(([r, y]) => new THREE.Vector2(r, y)), 14), m));
  body.rotation.x = -Math.PI / 2; body.position.z = 0.03; body.scale.set(1, 1, 0.8); g.add(body);
  // jaws: the fingers are the top, the thumb is the bottom
  const head = new THREE.Group(); head.position.z = -0.2; g.add(head);
  const top = own(new THREE.Mesh(new THREE.SphereGeometry(0.056, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2), m)); top.scale.set(1, 0.65, 1.35); head.add(top);
  const jaw = new THREE.Group(); jaw.position.set(0, -0.004, 0.035); head.add(jaw);
  const bot = own(new THREE.Mesh(new THREE.SphereGeometry(0.052, 14, 8, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), m)); bot.scale.set(1, 0.5, 1.3); bot.position.z = -0.035; jaw.add(bot);
  // inside the mouth: dark, and a red felt tongue someone sewed in
  const inside = own(new THREE.Mesh(new THREE.CircleGeometry(0.05, 14), new THREE.MeshBasicMaterial({ color: 0x1a0c0a }))); inside.rotation.x = -Math.PI / 2; inside.scale.y = 1.3; inside.position.set(0, -0.002, -0.03); jaw.add(inside);
  const tongue = own(new THREE.Mesh(new THREE.CircleGeometry(0.025, 10), new THREE.MeshStandardMaterial({ color: 0xb02a2a, roughness: 1 }))); tongue.rotation.x = -Math.PI / 2; tongue.scale.y = 1.6; tongue.position.set(0, 0.001, -0.045); jaw.add(tongue);
  // the googly eyes: too big, too white, pupils loose inside them
  const white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.15, emissive: 0xffffff, emissiveIntensity: 0.35 });
  const black = new THREE.MeshBasicMaterial({ color: 0x050505 });
  const eyes = [];
  for (const s of [-1, 1]) {
    const e = new THREE.Group(); e.position.set(s * 0.03, 0.036, -0.012); e.rotation.x = -0.35; e.rotation.y = s * 0.15; head.add(e);
    const ball = own(new THREE.Mesh(new THREE.SphereGeometry(0.031, 16, 10), white)); ball.scale.z = 0.45; e.add(ball);
    const rim = own(new THREE.Mesh(new THREE.TorusGeometry(0.031, 0.0025, 6, 20), new THREE.MeshStandardMaterial({ color: 0xd8d8d8, roughness: 0.2, transparent: true, opacity: 0.6 }))); e.add(rim);
    const pupil = own(new THREE.Mesh(new THREE.CircleGeometry(0.0135, 14), black)); pupil.position.z = 0.0145; e.add(pupil);
    eyes.push({ e, pupil, p: new THREE.Vector2(), v: new THREE.Vector2() });
  }
  g.visible = false;
  return { g, head, jaw, eyes };
}

// ---------------------------------------------------------------- build + animate
export function buildHands(camera) {
  const root = new THREE.Group(); camera.add(root); HANDS.root = root;
  // clear depth just before the hands draw, so they sit on top of everything
  const clearer = new THREE.Mesh(new THREE.PlaneGeometry(0.001, 0.001), new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false }));
  clearer.renderOrder = ORDER - 1; clearer.frustumCulled = false; clearer.position.z = -0.1;
  clearer.onBeforeRender = (r) => r.clearDepth(); root.add(clearer);
  const R = makeHand(1), L = makeHand(-1);
  root.add(R.arm, L.arm); HANDS.right = R; HANDS.left = L;
  // the torch, in the right hand
  const torch = new THREE.Group(); R.wrist.add(torch); torch.position.set(0.004, -0.004, -0.06);
  own(torch.add(new THREE.Mesh(new THREE.CylinderGeometry(0.017, 0.015, 0.15, 10), mat('torchBody', { color: 0x2a3a2a, roughness: 0.5, metalness: 0.3 }))));
  torch.children[0].rotation.x = Math.PI / 2;
  const lens = new THREE.Mesh(new THREE.CircleGeometry(0.016, 12), mat('torchLens', { color: 0xfff0d0, emissive: 0xffe8c0, emissiveIntensity: 0 })); lens.position.z = -0.076; lens.rotation.y = Math.PI; torch.add(lens);
  own(torch); HANDS.torch = torch; HANDS.lens = lens;
  // Socko, ready for when he's needed
  const S = makeSock(); L.wrist.add(S.g); S.g.position.set(0, 0, -0.04); HANDS.sock = S;
  return HANDS;
}

const tmp = V(), lastCam = new THREE.Euler(); let lagX = 0, lagY = 0, reach = 0;
onUpdate((dt, t) => {
  const H = HANDS; if (!H.root) return;
  const hide = G.cutscene || G.peeping || G.I?.reading || G.I?.inspecting || G.hideHands;
  H.root.visible = !hide && !G.handsOff;
  if (!H.root.visible) return;
  const cam = G.camera;
  // look lag: the hands trail behind a fast turn
  const dyaw = Math.atan2(Math.sin(cam.rotation.y - lastCam.y), Math.cos(cam.rotation.y - lastCam.y)), dp = cam.rotation.x - lastCam.x;
  lastCam.copy(cam.rotation);
  lagX += (-dyaw * 0.6 - lagX) * Math.min(1, dt * 8); lagY += (dp * 0.6 - lagY) * Math.min(1, dt * 8);
  lagX = Math.max(-0.08, Math.min(0.08, lagX)); lagY = Math.max(-0.06, Math.min(0.06, lagY));
  const walk = Math.min(1, P.speed / 2.2), bob = Math.sin(P.bob * 2) * 0.012 * walk, sway = Math.cos(P.bob) * 0.01 * walk, br = Math.sin(t * 1.3) * 0.004;
  if (G.handReach > 0) G.handReach -= dt;
  reach += ((G.handReach > 0 ? 1 : 0) - reach) * Math.min(1, dt * 14);
  const held = G.I?.held, torchOn = G.torch?.on;
  // right: torch, holding, reaching, or at rest
  const R = H.right;
  let rp = V(0.22, -0.25, -0.22), rc = 0.35, rr = new THREE.Euler(-0.05, 0.08, -0.15);
  if (torchOn) { rp = V(0.16, -0.18, -0.25); rc = 0.82; rr = new THREE.Euler(0.02, 0.05, -0.1); }
  if (held) { rp = V(0.13, -0.17, -0.3); rc = 0.45; rr = new THREE.Euler(0.25, 0.1, -0.6); }
  if (reach > 0.01) { rp.lerp(V(0.09, -0.15, -0.42), reach); rc = rc * (1 - reach) + 0.15 * reach; rr.x += reach * 0.15; }
  if (G.handPose) { rp = G.handPose.pos.clone(); rc = G.handPose.curl; rr = G.handPose.rot || new THREE.Euler(0.1, 0, -0.2); }
  R.arm.position.lerp(tmp.copy(rp).add(V(lagX + sway, lagY + bob + br, 0)), Math.min(1, dt * 12));
  R.arm.rotation.set(R.arm.rotation.x + (rr.x - R.arm.rotation.x) * Math.min(1, dt * 10), R.arm.rotation.y + (rr.y - R.arm.rotation.y) * Math.min(1, dt * 10), R.arm.rotation.z + (rr.z - R.arm.rotation.z) * Math.min(1, dt * 10));
  R.curl += (rc - R.curl) * Math.min(1, dt * 10); curlHand(R, R.curl, 1 - R.curl);
  H.torch.visible = !!torchOn && !held && !G.handPose;
  H.lens.material.emissiveIntensity = G.torch?.k > 0.1 ? 2 : 0;
  // the torch light comes out of the torch in your hand
  if (G.torch && H.torch.visible) { const sp = G.torch.light; H.lens.getWorldPosition(tmp); cam.worldToLocal(tmp); sp.position.copy(tmp); }
  // left: bare, or Socko — who comes up into view to talk
  const Lh = H.left, S = H.sock, sock = !!G.flags.socko;
  S.g.visible = sock; Lh.palm.visible = !sock; Lh.fingers.forEach((f) => f.forEach((j) => { j.visible = !sock; })); Lh.thumb.forEach((j) => { j.visible = !sock; });
  const talking = sock && VOICE.talking > 0;
  let lp = sock ? V(-0.2, -0.2, -0.3) : V(-0.24, -0.26, -0.2), lr = sock ? new THREE.Euler(0.35, -1.15, 0.2) : new THREE.Euler(-0.08, -0.06, 0.18);
  if (talking) { lp = V(-0.13, -0.11, -0.34); lr = new THREE.Euler(0.38, -0.85, 0.12); }
  if (G.wakePose) { lp = G.wakePose.pos; lr = G.wakePose.rot; }
  Lh.arm.position.lerp(tmp.copy(lp).add(V(lagX - sway, lagY - bob + br, 0)), Math.min(1, dt * (talking ? 6 : 10)));
  Lh.arm.rotation.set(Lh.arm.rotation.x + (lr.x - Lh.arm.rotation.x) * Math.min(1, dt * 7), Lh.arm.rotation.y + (lr.y - Lh.arm.rotation.y) * Math.min(1, dt * 7), Lh.arm.rotation.z + (lr.z - Lh.arm.rotation.z) * Math.min(1, dt * 7));
  if (!sock) { Lh.curl += (0.4 - Lh.curl) * Math.min(1, dt * 8); curlHand(Lh, Lh.curl, 0.3); }
  if (sock) {
    // the mouth works with the words; a little idle chew otherwise
    const open = talking ? 0.1 + VOICE.mouth * 0.55 : 0.04 + Math.max(0, Math.sin(t * 0.7)) * 0.03;
    S.jaw.rotation.x += (open - S.jaw.rotation.x) * Math.min(1, dt * 18);
    S.head.rotation.z = talking ? Math.sin(t * 7) * 0.05 : Math.sin(t * 0.9) * 0.02;
    // googly pupils: loose, sliding to the bottom, rattled by movement
    for (const e of S.eyes) {
      e.v.x += (-lagX * 40 - sway * 30 - e.p.x * 3) * dt; e.v.y += (-1.6 - bob * 80 + (talking ? Math.sin(t * 9) * 4 : 0) - e.p.y * 2) * dt;
      e.v.multiplyScalar(0.9); e.p.add(e.v.clone().multiplyScalar(dt * 6));
      if (e.p.length() > 0.015) { e.p.setLength(0.015); e.v.multiplyScalar(-0.4); }
      e.pupil.position.x = e.p.x; e.pupil.position.y = e.p.y;
    }
  }
});
