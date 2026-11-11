// Your hands. Drawn in their own pass over the finished frame (so they never sink into a
// wall, and nothing in the world is drawn over or through them), lit by a light that follows
// how bright it is where you're standing.
//
// Each arm is a proper two-bone limb: the shoulder is fixed just off the bottom corner of the
// screen, the wrist goes where the pose wants it, the elbow finds itself (two-bone IK), so the
// coat sleeve always runs back out of frame to you. Poses blend on springs, with follow-through.
//
// The left hand, later, wears Socko: not a rigid shape but a soft tube grown along a bending
// spine every frame. He holds himself up like a puppet, turns to look at you when he talks,
// nods along with his words, sags when he's quiet, and his head lags and bobs as you move.
import * as THREE from 'three';
import { G, onUpdate } from './core.js';
import { P } from './player.js';
import { VOICE } from './voice.js';
import { canvas, fabricTex } from './textures.js';
import { LIGHTS } from './lighting.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
export const HANDS = { scene: null, root: null, right: null, left: null, sock: null };

// ---------------------------------------------------------------- materials
function skinTex() {
  const c = canvas(64, 64), g = c.getContext('2d'); g.fillStyle = '#c49a80'; g.fillRect(0, 0, 64, 64);
  for (let i = 0; i < 260; i++) { g.fillStyle = `rgba(${120 + Math.random() * 60},${70 + Math.random() * 40},60,${Math.random() * 0.12})`; g.fillRect(Math.random() * 64, Math.random() * 64, 2, 2); }
  g.strokeStyle = 'rgba(90,100,140,0.18)'; for (let i = 0; i < 6; i++) { g.beginPath(); g.moveTo(Math.random() * 64, 0); g.bezierCurveTo(Math.random() * 64, 20, Math.random() * 64, 40, Math.random() * 64, 64); g.stroke(); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function sockTex() {
  const c = canvas(128, 256), g = c.getContext('2d');
  g.fillStyle = '#d6d0c2'; g.fillRect(0, 0, 128, 256);
  for (let x = 0; x < 128; x += 4) { g.fillStyle = 'rgba(0,0,0,0.08)'; g.fillRect(x, 0, 2, 256); } // ribbing runs along the sock
  for (let y = 0; y < 256; y += 3) { g.fillStyle = 'rgba(255,255,255,0.05)'; g.fillRect(0, y, 128, 1); }
  for (let i = 0; i < 12; i++) { g.fillStyle = `rgba(${90 + Math.random() * 40},${70 + Math.random() * 30},40,${0.12 + Math.random() * 0.22})`; g.beginPath(); g.ellipse(Math.random() * 128, 60 + Math.random() * 196, 6 + Math.random() * 18, 6 + Math.random() * 20, Math.random() * 3, 0, 6.28); g.fill(); }
  // cuff stripes at the open end (v = 0, the wrist)
  g.fillStyle = '#a8322a'; g.fillRect(0, 10, 128, 9); g.fillStyle = '#2c4a8a'; g.fillRect(0, 26, 128, 7); g.fillStyle = '#a8322a'; g.fillRect(0, 38, 128, 4);
  g.fillStyle = '#6a5a48'; g.beginPath(); g.arc(30, 170, 5, 0, 6.28); g.fill(); g.strokeStyle = '#8a3a2a'; g.lineWidth = 1; for (let i = 0; i < 5; i++) { g.beginPath(); g.moveTo(24, 165 + i * 2.5); g.lineTo(36, 167 + i * 2.5); g.stroke(); } // a darn
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.wrapS = THREE.RepeatWrapping; return t;
}
let MATS;
function mats() {
  if (MATS) return MATS;
  MATS = {
    skin: new THREE.MeshStandardMaterial({ map: skinTex(), roughness: 0.6 }),
    sleeve: new THREE.MeshStandardMaterial({ map: fabricTex('#4a3a2c', 240, 0).map, roughness: 1 }),
    cuff: new THREE.MeshStandardMaterial({ map: fabricTex('#c0bcb0', 241, 0).map, roughness: 1 }),
    sock: new THREE.MeshStandardMaterial({ map: sockTex(), roughness: 0.95, side: THREE.DoubleSide }),
    torch: new THREE.MeshStandardMaterial({ color: 0x2a3a2a, roughness: 0.45, metalness: 0.35 }),
    lens: new THREE.MeshStandardMaterial({ color: 0xfff0d0, emissive: 0xffe8c0, emissiveIntensity: 0 }),
  };
  return MATS;
}

// ---------------------------------------------------------------- a limb segment: a capsule between two points
function segment(r, m) { const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(r, 1, 4, 12), m); mesh.userData.r = r; return mesh; }
const UP = V(0, 1, 0);
function placeSeg(mesh, a, b) {
  const len = a.distanceTo(b), r = mesh.userData.r;
  mesh.position.copy(a).add(b).multiplyScalar(0.5);
  mesh.quaternion.setFromUnitVectors(UP, tmpA.copy(b).sub(a).normalize());
  mesh.scale.set(1, Math.max(0.01, (len) / (1 + 2 * r) ), 1);
}
const tmpA = V(), tmpB = V(), tmpC = V();

// two-bone IK: shoulder -> elbow -> wrist, elbow pushed toward `pole`
function solveIK(sh, target, l1, l2, pole, outElbow, outWrist) {
  const d = tmpA.copy(target).sub(sh); let dist = d.length();
  dist = Math.min(l1 + l2 - 0.002, Math.max(Math.abs(l1 - l2) + 0.01, dist));
  const dir = d.normalize();
  const a = (l1 * l1 + dist * dist - l2 * l2) / (2 * dist), h = Math.sqrt(Math.max(0, l1 * l1 - a * a));
  const bend = tmpB.copy(pole).addScaledVector(dir, -pole.dot(dir)).normalize();
  outElbow.copy(sh).addScaledVector(dir, a).addScaledVector(bend, h);
  outWrist.copy(sh).addScaledVector(dir, dist);
}

// ---------------------------------------------------------------- a hand
function finger(parent, x, z, lens, r, m) {
  const segs = []; let p = parent;
  lens.forEach((L, i) => {
    const j = new THREE.Group(); j.position.set(i ? 0 : x, 0, i ? -lens[i - 1] : z); p.add(j);
    const s = new THREE.Mesh(new THREE.CapsuleGeometry(r * (1 - i * 0.12), L - r, 3, 8), m); s.rotation.x = Math.PI / 2; s.position.z = -L / 2; j.add(s);
    segs.push(j); p = j;
  });
  return segs;
}
function makeArm(side) {
  const m = mats();
  const A = { side, upper: segment(0.056, m.sleeve), fore: segment(0.049, m.sleeve), cuffM: new THREE.Mesh(new THREE.CylinderGeometry(0.042, 0.044, 0.04, 14), m.cuff), hand: new THREE.Group() };
  // shoulder just below and behind the bottom corner of the view
  A.shoulder = V(side * 0.3, -0.47, 0.1);
  A.pole = V(side * 0.7, -1, 0.35).normalize();
  A.l1 = 0.31; A.l2 = 0.31;
  A.elbow = V(); A.wrist = V(); A.target = V(side * 0.22, -0.26, -0.33); A.vel = V(); A.cur = A.target.clone();
  A.aim = V(0, 0, -1); A.aimCur = V(0, 0, -1); A.roll = 0; A.rollCur = 0; A.curl = 0.4; A.curlCur = 0.4;
  // the hand: palm, four fingers in three joints, a thumb in two
  const palm = new THREE.Mesh(new THREE.CapsuleGeometry(0.03, 0.05, 4, 8), m.skin); palm.rotation.x = Math.PI / 2; palm.scale.set(1.45, 0.62, 1); palm.position.z = -0.05; A.hand.add(palm);
  A.palm = palm;
  A.fingers = [-0.026, -0.009, 0.008, 0.025].map((x, i) => finger(A.hand, x * side, -0.09, [0.043, 0.028, 0.022].map((l) => l * [0.95, 1.05, 1.0, 0.82][i]), 0.0085, m.skin));
  const tb = new THREE.Group(); tb.position.set(-0.033 * side, -0.006, -0.035); tb.rotation.y = 0.7 * side; A.hand.add(tb);
  A.thumb = finger(tb, 0, 0, [0.032, 0.026], 0.0095, m.skin);
  return A;
}
function curlHand(A, c, spread) {
  A.fingers.forEach((f, i) => f.forEach((j, k) => { j.rotation.x = -c * [0.9, 1.3, 1.0][k] * (1 + i * 0.06); j.rotation.y = k === 0 ? (i - 1.5) * 0.07 * spread * A.side : 0; }));
  A.thumb.forEach((j, k) => { j.rotation.x = -c * 0.45 * (k + 1); });
}

// ---------------------------------------------------------------- Socko: a tube grown along a bending spine
const SN = 12, SR = 16; // spine points, ring segments
function makeSock() {
  const m = mats();
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array((SN + 1) * (SR + 1) * 3), uv = new Float32Array((SN + 1) * (SR + 1) * 2), idx = [];
  for (let i = 0; i <= SN; i++) for (let j = 0; j <= SR; j++) { const k = i * (SR + 1) + j; uv[k * 2] = j / SR; uv[k * 2 + 1] = i / SN; }
  for (let i = 0; i < SN; i++) for (let j = 0; j < SR; j++) { const a = i * (SR + 1) + j, b = a + SR + 1; idx.push(a, b, a + 1, b, b + 1, a + 1); }
  geo.setIndex(idx); geo.setAttribute('position', new THREE.BufferAttribute(pos, 3)); geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
  const tube = new THREE.Mesh(geo, m.sock); tube.frustumCulled = false;
  const g = new THREE.Group(); g.add(tube);
  // the head at the end of the spine: upper jaw shell, hinged lower jaw, mouth, tongue, eyes
  const head = new THREE.Group(); g.add(head);
  const top = new THREE.Mesh(new THREE.SphereGeometry(0.054, 18, 10, 0, Math.PI * 2, 0, Math.PI / 2), m.sock); top.scale.set(1, 0.72, 1.25); top.position.z = -0.005; head.add(top);
  const jaw = new THREE.Group(); jaw.position.set(0, -0.006, 0.03); head.add(jaw);
  const bot = new THREE.Mesh(new THREE.SphereGeometry(0.05, 18, 8, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), m.sock); bot.scale.set(0.96, 0.5, 1.2); bot.position.z = -0.035; jaw.add(bot);
  const inside = new THREE.Mesh(new THREE.CircleGeometry(0.048, 16), new THREE.MeshBasicMaterial({ color: 0x1a0c0a })); inside.rotation.x = -Math.PI / 2; inside.scale.y = 1.25; inside.position.set(0, 0.001, -0.033); jaw.add(inside);
  const roof = new THREE.Mesh(new THREE.CircleGeometry(0.05, 16), new THREE.MeshBasicMaterial({ color: 0x2a1210 })); roof.rotation.x = Math.PI / 2; roof.scale.y = 1.25; roof.position.set(0, -0.001, -0.005); head.add(roof);
  const tongue = new THREE.Mesh(new THREE.SphereGeometry(0.024, 10, 6), new THREE.MeshStandardMaterial({ color: 0xb02a2a, roughness: 1 })); tongue.scale.set(1, 0.25, 1.6); tongue.position.set(0, 0.004, -0.045); jaw.add(tongue);
  const white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.12, emissive: 0xffffff, emissiveIntensity: 0.3 });
  const black = new THREE.MeshBasicMaterial({ color: 0x050505 });
  const eyes = [];
  for (const s of [-1, 1]) {
    const e = new THREE.Group(); e.position.set(s * 0.027, 0.034, 0.012); e.rotation.set(-1.0, s * 0.25, 0); head.add(e);
    const ball = new THREE.Mesh(new THREE.SphereGeometry(0.03, 18, 10), white); ball.scale.z = 0.42; e.add(ball);
    const pupil = new THREE.Mesh(new THREE.CircleGeometry(0.013, 16), black); pupil.position.z = 0.0135; e.add(pupil);
    const glint = new THREE.Mesh(new THREE.CircleGeometry(0.004, 8), new THREE.MeshBasicMaterial({ color: 0xffffff })); glint.position.set(-0.01, 0.012, 0.0136); e.add(glint);
    eyes.push({ e, pupil, p: new THREE.Vector2(0, -0.01), v: new THREE.Vector2() });
  }
  return { g, tube, geo, pos, head, jaw, eyes, pitch: 0.5, yaw: 0, lagV: V(), lag: V(), nod: 0 };
}
// rebuild the tube along a spine bent by `pitch` (up) and `yaw` (across), with the head lagging
const spine = Array.from({ length: SN + 1 }, () => V()), tang = Array.from({ length: SN + 1 }, () => V());
function shapeSock(S, t) {
  const L = 0.27;
  const p = V(0, 0, 0.05), d = V(0, 0, -1), q = new THREE.Quaternion();
  for (let i = 0; i <= SN; i++) {
    const s = i / SN;
    spine[i].copy(p); tang[i].copy(d);
    // the bend is a wrist bend (around a third of the way) and a neck bend near the head
    const wB = Math.exp(-((s - 0.35) ** 2) / 0.02), nB = Math.exp(-((s - 0.78) ** 2) / 0.015);
    const pitchStep = (S.pitch * 0.62 * wB + (S.pitch * 0.38 + S.nod) * nB) / (SN * 0.27);
    const yawStep = (S.yaw * (0.4 * wB + 0.6 * nB)) / (SN * 0.27);
    q.setFromEuler(new THREE.Euler(pitchStep, yawStep, 0, 'YXZ')); d.applyQuaternion(q).normalize();
    // follow-through: the far end of the sock trails behind movement
    p.addScaledVector(d, L / SN).addScaledVector(S.lag, s * s * (1 / SN) * 2.2);
  }
  // rings, framed by parallel transport so it never twists
  let N = V(0, 1, 0);
  const arr = S.pos;
  for (let i = 0; i <= SN; i++) {
    if (i) { const qq = new THREE.Quaternion().setFromUnitVectors(tang[i - 1], tang[i]); N.applyQuaternion(qq); }
    const T = tang[i], B = V().crossVectors(T, N).normalize(), Nn = V().crossVectors(B, T).normalize(); N = Nn;
    const s = i / SN;
    // radius: snug at the cuff, knuckle bulge, slimmer neck, round head
    let r = 0.047 + 0.009 * Math.sin(s * Math.PI * 0.9) + 0.004 * Math.exp(-((s - 0.55) ** 2) / 0.01);
    r *= 1 + Math.sin(t * 1.4 + s * 3) * 0.01;
    for (let j = 0; j <= SR; j++) {
      const a = (j / SR) * Math.PI * 2, k = (i * (SR + 1) + j) * 3;
      const flat = 0.86; // a sock with a hand in it is wider than it is tall
      arr[k] = spine[i].x + (Math.cos(a) * B.x + Math.sin(a) * flat * N.x) * r;
      arr[k + 1] = spine[i].y + (Math.cos(a) * B.y + Math.sin(a) * flat * N.y) * r;
      arr[k + 2] = spine[i].z + (Math.cos(a) * B.z + Math.sin(a) * flat * N.z) * r;
    }
    if (i === SN) { // the head sits on the end of the spine, oriented with it
      const z = T.clone().negate(), x = V().crossVectors(N, z).normalize();
      S.head.matrix.makeBasis(x, N, z).setPosition(spine[i].clone().addScaledVector(T, -0.012)); S.head.matrixAutoUpdate = false;
    }
  }
  S.geo.attributes.position.needsUpdate = true; S.geo.computeVertexNormals(); S.geo.computeBoundingSphere();
}

// ---------------------------------------------------------------- build
export function buildHands() {
  const scene = new THREE.Scene(); HANDS.scene = scene;
  const root = new THREE.Group(); root.matrixAutoUpdate = false; scene.add(root); HANDS.root = root;
  // light: a soft fill that follows how bright it is where you are, a key from above, and the torch's spill
  HANDS.hemi = new THREE.HemisphereLight(0xe0d8c8, 0x2a2018, 0.6); scene.add(HANDS.hemi);
  HANDS.key = new THREE.DirectionalLight(0xfff0e0, 0.5); HANDS.key.position.set(0.3, 1, 0.4); root.add(HANDS.key); root.add(HANDS.key.target);
  HANDS.spill = new THREE.PointLight(0xffe8c8, 0, 0.8, 2); root.add(HANDS.spill);
  const R = makeArm(1), Lf = makeArm(-1); HANDS.right = R; HANDS.left = Lf;
  for (const A of [R, Lf]) root.add(A.upper, A.fore, A.cuffM, A.hand);
  // the torch, in the right hand
  const m = mats();
  const torch = new THREE.Group(); R.hand.add(torch); torch.position.set(0.003, -0.006, -0.07);
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.017, 0.015, 0.16, 12), m.torch); body.rotation.x = Math.PI / 2; torch.add(body);
  const lens = new THREE.Mesh(new THREE.CircleGeometry(0.016, 12), m.lens); lens.position.z = -0.081; lens.rotation.y = Math.PI; torch.add(lens);
  HANDS.torch = torch; HANDS.lens = lens;
  // Socko, on the left hand when he's there
  const S = makeSock(); Lf.hand.add(S.g); HANDS.sock = S; S.g.visible = false;
  return HANDS;
}

// ---------------------------------------------------------------- how bright is it here?
const camPos = V(), probe = V();
function lightLevel() {
  let sum = 0;
  for (const L of LIGHTS) { const l = L.l; if (!l.isPointLight || l.intensity <= 0) continue; l.getWorldPosition(probe); const d2 = Math.max(0.6, probe.distanceToSquared(camPos)); sum += l.intensity / d2; }
  // (the building's pooled fittings count too)
  for (const l of G.poolLights || []) { if (l.intensity <= 0) continue; const d2 = Math.max(0.6, l.position.distanceToSquared(camPos)); sum += l.intensity / d2; }
  const sky = (G.lights.sky?.l?.intensity || 0) * (P.zone ? 0.1 : 0.25);
  return Math.min(1.6, 0.06 + sum * 0.28 + sky);
}

// ---------------------------------------------------------------- animate
// critically-damped spring toward a target
function spring(cur, vel, target, k, dt) { const f = tmpC.copy(target).sub(cur).multiplyScalar(k * k * dt); vel.add(f).multiplyScalar(Math.max(0, 1 - 2 * k * dt)); cur.addScaledVector(vel, dt); }
let lastYaw = 0, lastPitch = 0, lagX = 0, lagY = 0, reach = 0, lvl = 0.5;
const wobble = V();
onUpdate((dt, t) => {
  const H = HANDS; if (!H.root) return;
  const cam = G.camera;
  cam.updateMatrixWorld(); H.root.matrix.copy(cam.matrixWorld); H.root.updateMatrixWorld(true);
  const hide = G.cutscene || G.peeping || G.I?.reading || G.I?.inspecting || G.hideHands;
  H.root.visible = !hide;
  if (hide) return;
  cam.getWorldPosition(camPos);
  lvl += (lightLevel() - lvl) * Math.min(1, dt * 4);
  H.hemi.intensity = lvl; H.key.intensity = lvl * 0.6; H.spill.intensity = G.torch?.k > 0.1 ? 0.25 : 0;
  // look lag: the hands trail a fast turn
  const dyaw = Math.atan2(Math.sin(P.yaw - lastYaw), Math.cos(P.yaw - lastYaw)), dp = P.pitch - lastPitch; lastYaw = P.yaw; lastPitch = P.pitch;
  lagX += (dyaw * 0.9 - lagX) * Math.min(1, dt * 6); lagY += (-dp * 0.7 - lagY) * Math.min(1, dt * 6);
  lagX = Math.max(-0.07, Math.min(0.07, lagX)); lagY = Math.max(-0.05, Math.min(0.05, lagY));
  const walk = Math.min(1, P.speed / 2.2), ph = P.bob, br = Math.sin(t * 1.3) * 0.005;
  if (G.handReach > 0) G.handReach -= dt;
  reach += ((G.handReach > 0 ? 1 : 0) - reach) * Math.min(1, dt * 12);
  const held = G.I?.held, torchOn = G.torch?.on;
  // ---- right arm targets
  const R = H.right;
  R.target.set(0.21, -0.27, -0.33); R.aim.set(0.05, 0.25, -1); R.roll = -0.25; R.curl = 0.38;
  if (torchOn) { R.target.set(0.15, -0.19, -0.37); R.aim.set(-0.06, 0.03, -1); R.roll = -0.1; R.curl = 0.85; }
  if (held) { R.target.set(0.11, -0.2, -0.38); R.aim.set(-0.2, 0.35, -1); R.roll = -1.2; R.curl = 0.45; }
  if (reach > 0.01) { R.target.lerp(V(0.07, -0.13, -0.5), reach); R.aim.lerp(V(0, 0.1, -1), reach); R.curl = R.curl * (1 - reach) + 0.1 * reach; }
  if (G.handPose) { R.target.copy(G.handPose.pos); R.curl = G.handPose.curl; R.aim.set(0, 0.15, -1); R.roll = -0.6; }
  // ---- left arm targets
  const Lf = H.left, S = H.sock, sock = !!G.flags.socko, talking = sock && VOICE.talking > 0;
  Lf.target.set(-0.23, -0.29, -0.31); Lf.aim.set(-0.05, 0.25, -1); Lf.roll = 0.25; Lf.curl = 0.42;
  if (sock) { Lf.target.set(-0.2, -0.24, -0.34); Lf.aim.set(0.2, 0.1, -1); Lf.roll = 0.15; }
  if (talking) { Lf.target.set(-0.15, -0.17, -0.37); Lf.aim.set(0.6, 0.4, -1); Lf.roll = 0.1; }
  if (G.wakePose) { Lf.target.copy(G.wakePose.pos); Lf.aim.set(0.5, 0.6, -1); }
  // ---- walking: the arms swing a little, in opposite phase; breathing lifts them
  const sway = V(Math.cos(ph) * 0.012 * walk, Math.abs(Math.sin(ph)) * -0.014 * walk + br, 0);
  for (const A of [R, Lf]) {
    const goal = tmpB.copy(A.target).add(V(lagX * (A === R ? 1 : 0.8), lagY, 0)).add(A === R ? sway : V(-sway.x, sway.y, 0));
    spring(A.cur, A.vel, goal.clone(), A === Lf && sock ? 11 : 14, dt);
    solveIK(A.shoulder, A.cur, A.l1, A.l2, A.pole, A.elbow, A.wrist);
    placeSeg(A.upper, A.shoulder, A.elbow); placeSeg(A.fore, A.elbow, tmpA.copy(A.wrist).addScaledVector(tmpC.copy(A.wrist).sub(A.elbow).normalize(), -0.02));
    // the cuff and the hand at the wrist; the hand points between the forearm and where it's aimed
    const fdir = tmpC.copy(A.wrist).sub(A.elbow).normalize();
    A.aimCur.lerp(A.aim.clone().normalize(), Math.min(1, dt * 8)).normalize();
    const hdir = fdir.clone().lerp(A.aimCur, 0.55).normalize();
    A.rollCur += (A.roll - A.rollCur) * Math.min(1, dt * 8);
    const look = new THREE.Matrix4().lookAt(V(0, 0, 0), hdir, V(0, 1, 0));
    A.hand.quaternion.setFromRotationMatrix(look).multiply(new THREE.Quaternion().setFromAxisAngle(V(0, 0, 1), A.rollCur));
    A.hand.position.copy(A.wrist);
    A.cuffM.position.copy(A.wrist).addScaledVector(fdir, 0.0); A.cuffM.quaternion.setFromUnitVectors(UP, fdir);
    A.curlCur += (A.curl - A.curlCur) * Math.min(1, dt * 10);
  }
  curlHand(R, R.curlCur, 1 - R.curlCur);
  H.torch.visible = !!torchOn && !held && !G.handPose;
  H.lens.material.emissiveIntensity = G.torch?.k > 0.1 ? 2.2 : 0;
  // the beam comes out of the torch in your hand: put the real spotlight there (in camera space)
  if (G.torch && H.torch.visible) { H.lens.getWorldPosition(tmpA); cam.worldToLocal(tmpA); G.torch.light.position.copy(tmpA); }
  // ---- left hand: bare, or Socko
  Lf.palm.visible = !sock; Lf.fingers.forEach((f) => f.forEach((j) => { j.visible = !sock; })); Lf.thumb.forEach((j) => { j.visible = !sock; });
  S.g.visible = sock;
  if (!sock) curlHand(Lf, Lf.curlCur, 0.3);
  else {
    // posture: sagging when quiet, sitting up and turning to you when he talks; nods with his words
    const wantPitch = talking ? 1.4 : G.wakePose ? 1.3 : 0.6 + Math.sin(t * 0.5) * 0.08;
    const wantYaw = talking ? 0.9 : 0.3 + Math.sin(t * 0.31) * 0.2;
    S.pitch += (wantPitch - S.pitch) * Math.min(1, dt * 4); S.yaw += (wantYaw - S.yaw) * Math.min(1, dt * 3);
    S.nod += ((talking ? VOICE.mouth * 0.35 - 0.1 : Math.sin(t * 2.1) * 0.03) - S.nod) * Math.min(1, dt * 14);
    // the head lags behind your movement, then catches up (local to the hand)
    wobble.set(-lagX * 6 - sway.x * 4, -lagY * 5 + (P.speed > 0.3 ? Math.sin(ph * 2) * 0.02 : 0), 0);
    spring(S.lag, S.lagV, wobble, 9, dt);
    shapeSock(S, t);
    const open = talking ? 0.12 + VOICE.mouth * 0.6 : 0.05 + Math.max(0, Math.sin(t * 0.8)) * 0.04;
    S.jaw.rotation.x += (open - S.jaw.rotation.x) * Math.min(1, dt * 20);
    // googly pupils roll to the bottom of the eye and rattle about
    for (const e of S.eyes) {
      e.v.x += (-lagX * 60 - S.lagV.x * 3 - e.p.x * 2) * dt; e.v.y += (-1.4 + S.lagV.y * 3 + (talking ? Math.sin(t * 11) * 3 : 0) - e.p.y * 1.5) * dt;
      e.v.multiplyScalar(0.92); e.p.addScaledVector(e.v, dt * 6);
      if (e.p.length() > 0.015) { e.p.setLength(0.015); e.v.multiplyScalar(-0.45); }
      e.pupil.position.x = e.p.x; e.pupil.position.y = e.p.y;
    }
  }
});
