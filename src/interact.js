// Looking at things and doing things to them: the crosshair prompt, using switches and
// doors, taking objects, carrying them, throwing them, turning them over in your hands,
// reading what's written on them.
import * as THREE from 'three';
import * as CANNON from 'cannon-es';
import { G } from './core.js';
import { P } from './player.js';
import { makeProp } from './props.js';
import { sfx } from './audio.js';

const ray = new THREE.Raycaster(); ray.far = 2.3;
const centre = new THREE.Vector2(0, 0);
export const I = { target: null, held: null, inspecting: false, reading: false, blockers: [] };

// ---------------------------------------------------------------- ui
const $ = (id) => document.getElementById(id);
let toastT = 0;
export const UI = {
  prompt(text) { const el = $('prompt'); if (el._t !== text + (G.glyph || '')) { el._t = text + (G.glyph || ''); el.innerHTML = text ? `<kbd>${G.glyph || 'E'}</kbd>${text}` : ''; } $('cross').classList.toggle('on', !!text); },
  toast(text, sec = 4.5) { const el = $('toast'); el.textContent = text; el.classList.add('on'); toastT = sec; },
  room(name) { const el = $('room'); if (el._t === name) return; el._t = name; el.textContent = name || ''; el.classList.toggle('on', !!name); clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove('on'), 2600); },
  read(doc) {
    I.reading = true;
    const el = $('doc'), cv = el.querySelector('canvas'), tx = el.querySelector('.docText');
    if (doc.canvas) { cv.style.display = ''; cv.width = doc.canvas.width; cv.height = doc.canvas.height; cv.getContext('2d').drawImage(doc.canvas, 0, 0); } else cv.style.display = 'none';
    tx.textContent = doc.text || ''; tx.style.display = doc.text ? '' : 'none';
    el.classList.remove('hidden');
    sfx('paper', null, { vol: 0.6 });
  },
  closeRead() { I.reading = false; $('doc').classList.add('hidden'); sfx('paper', null, { vol: 0.4 }); },
  tick(dt) { if (toastT > 0) { toastT -= dt; if (toastT <= 0) $('toast').classList.remove('on'); } },
  inspectCap(name, desc, hint) { const el = $('inspectCap'); if (!name) { el.style.display = 'none'; return; } el.style.display = 'block'; el.querySelector('b').textContent = name; el.querySelector('span').textContent = desc || ''; el.querySelector('i').textContent = hint || ''; },
};
G.ui = UI;

// ---------------------------------------------------------------- targets
function candidates() {
  const list = [];
  for (const it of G.interact) if (!it.disabled) for (const m of it.meshes) list.push(m);
  for (const m of G.pickables) if (!m.userData.taken) list.push(m);
  for (const p of G.props) if (p.pick && !p.dead && !p.held) list.push(p.mesh);
  return list;
}
function resolveTarget(obj) {
  for (let o = obj; o; o = o.parent) {
    if (o.userData.prop && o.userData.prop.pick) return { kind: 'prop', prop: o.userData.prop };
    if (o.userData.pickSpec && o.userData.pickRoot && !o.userData.pickRoot.userData.taken) return { kind: 'pick', root: o.userData.pickRoot, spec: o.userData.pickSpec };
    if (o.userData.it && !o.userData.it.disabled) return { kind: 'use', it: o.userData.it };
  }
  return null;
}

export function updateInteract(dt, camera) {
  if (I.inspecting) return updateInspect(dt, camera);
  if (I.held) holdUpdate(dt, camera);
  camera.updateMatrixWorld();
  ray.setFromCamera(centre, camera);
  const hits = ray.intersectObjects([...candidates(), ...I.blockers], true);
  I.target = null;
  for (const h of hits) {
    if (h.object.userData.blocker) break;
    if (!h.object.visible) continue;
    const t = resolveTarget(h.object);
    if (!t) continue;
    const range = t.kind === 'use' ? t.it.range : 1.8;
    if (h.distance > range) break;
    I.target = t; break;
  }
  if (I.held) { UI.prompt(''); $('cross').classList.add('on'); return; }
  const t = I.target;
  if (!t) UI.prompt('');
  else if (t.kind === 'use') UI.prompt(typeof t.it.prompt === 'function' ? t.it.prompt() : t.it.prompt);
  else if (t.kind === 'pick') UI.prompt((t.spec.verb || 'Take') + ' ' + t.spec.name.toLowerCase());
  else UI.prompt((t.prop.verb || 'Pick up') + ' ' + t.prop.name.toLowerCase());
}

// ---------------------------------------------------------------- actions
export function use() {
  if (I.reading) { UI.closeRead(); return; }
  if (I.inspecting) { endInspect(); return; }
  if (I.held) { drop(0.6); return; }
  const t = I.target; if (!t) return;
  if (t.kind === 'use') { t.it.use(); return; }
  if (t.kind === 'pick') {
    const { root, spec } = t;
    if (spec.read && !spec.take) { UI.read(spec.read()); spec.onRead?.(); return; }
    root.userData.taken = true;
    const prop = makeProp(root, { ...spec, asleep: false });
    spec.onTake?.(prop);
    grab(prop);
    return;
  }
  if (t.kind === 'prop') grab(t.prop);
}
function grab(prop) {
  if (prop.mass > 12) { UI.toast('Too heavy to lift. You could push it.'); return; }
  I.held = prop; prop.held = true; prop.body.wakeUp();
  prop.holdQ = new THREE.Quaternion().copy(prop.mesh.quaternion);
  prop.yaw0 = P.yaw;
  prop.body.angularDamping = 0.9;
  prop.body.collisionFilterMask = 1; // still hits the world
  sfx('pickup', prop.mesh.position, { vol: 0.6 });
  if (!prop.seen && prop.desc) { prop.seen = true; UI.toast(prop.desc, 6); }
  prop.onPick?.(prop);
}
export function drop(force = 0) {
  const p = I.held; if (!p) return;
  I.held = null; p.held = false; p.body.angularDamping = 0.25;
  if (force) {
    const d = new THREE.Vector3(); G.camera.getWorldDirection(d);
    const k = force * Math.min(8, 6 / Math.sqrt(p.mass));
    p.body.velocity.set(d.x * k + P.vel.x, d.y * k + 0.5, d.z * k + P.vel.z);
    p.body.angularVelocity.set((Math.random() - 0.5) * 4, (Math.random() - 0.5) * 4, (Math.random() - 0.5) * 4);
  }
}
export function throwHeld() { if (I.held) drop(2.2); }

const tgt = new THREE.Vector3(), dir = new THREE.Vector3(), q = new THREE.Quaternion(), yq = new THREE.Quaternion();
function holdUpdate(dt, camera) {
  const p = I.held;
  camera.getWorldDirection(dir);
  const dist = 0.55 + Math.max(p.size.x, p.size.z) * 0.6;
  tgt.copy(camera.position).addScaledVector(dir, dist); tgt.y -= 0.12;
  // body position is the mesh origin; aim the centre of the bounds at the target
  const cw = p.centre.clone().applyQuaternion(p.mesh.quaternion);
  const b = p.body;
  const ex = tgt.x - cw.x - b.position.x, ey = tgt.y - cw.y - b.position.y, ez = tgt.z - cw.z - b.position.z;
  if (Math.hypot(ex, ey, ez) > 1.4) { drop(0); return; } // snagged on something
  const kk = 14;
  b.velocity.set(ex * kk, ey * kk, ez * kk);
  // turn with the player's yaw
  yq.setFromAxisAngle(new THREE.Vector3(0, 1, 0), P.yaw - p.yaw0);
  q.copy(yq).multiply(p.holdQ);
  const cq = new THREE.Quaternion(b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w).slerp(q, Math.min(1, dt * 10));
  b.quaternion.set(cq.x, cq.y, cq.z, cq.w); b.angularVelocity.set(0, 0, 0);
}

// ---------------------------------------------------------------- inspect: turn it over in your hands
let insp = null;
export function beginInspect() {
  const p = I.held; if (!p || I.inspecting) return;
  I.inspecting = true; P.frozen = true;
  p.body.type = CANNON.Body.KINEMATIC; p.body.velocity.setZero(); p.body.angularVelocity.setZero();
  insp = { p, rotX: 0, rotY: 0, q: p.mesh.quaternion.clone(), pos: p.mesh.position.clone() };
  UI.inspectCap(p.name, p.desc, (p.doc ? 'E read · ' : '') + 'mouse turn · right mouse put back');
  sfx('pickup', null, { vol: 0.3 });
}
export function endInspect() {
  if (!insp) return;
  const p = insp.p; p.body.type = CANNON.Body.DYNAMIC; p.body.mass = p.mass; p.body.updateMassProperties();
  p.yaw0 = P.yaw; p.holdQ.copy(p.mesh.quaternion);
  I.inspecting = false; P.frozen = false; insp = null; UI.inspectCap(null);
}
export function inspectLook(dx, dy) { if (insp) { insp.rotY += dx * 0.008; insp.rotX += dy * 0.008; } }
export function inspectRead() { if (insp && insp.p.doc) UI.read(insp.p.doc()); }
function updateInspect(dt, camera) {
  const p = insp.p;
  camera.getWorldDirection(dir);
  const s = Math.max(p.size.x, p.size.y, p.size.z);
  tgt.copy(camera.position).addScaledVector(dir, 0.22 + s * 1.1);
  const qq = new THREE.Quaternion().setFromEuler(new THREE.Euler(insp.rotX, insp.rotY, 0, 'YXZ'));
  const camQ = camera.quaternion.clone();
  const final = camQ.multiply(qq).multiply(insp.q.clone().premultiply(camera.quaternion.clone().invert()));
  p.mesh.quaternion.slerp(final, Math.min(1, dt * 12));
  const cw = p.centre.clone().applyQuaternion(p.mesh.quaternion);
  p.mesh.position.lerp(tgt.clone().sub(cw), Math.min(1, dt * 12));
  p.body.position.set(p.mesh.position.x, p.mesh.position.y, p.mesh.position.z);
  p.body.quaternion.set(p.mesh.quaternion.x, p.mesh.quaternion.y, p.mesh.quaternion.z, p.mesh.quaternion.w);
  UI.prompt('');
}
