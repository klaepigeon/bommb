// First-person body: mouse look, walking, crouching, collision against the flat's walls
// and furniture, pushing heavy things, footsteps that know what they're on.
import * as THREE from 'three';
import { G } from './core.js';
import { SPAWN, BALCONY, roomAt } from './plan.js';
import { sfx } from './audio.js';
import { propFootprint } from './props.js';

export const P = {
  pos: new THREE.Vector3(SPAWN.x, 0, SPAWN.z), vel: new THREE.Vector3(), yaw: SPAWN.yaw, pitch: -0.05,
  height: 1.62, eye: 1.62, crouch: false, radius: 0.24, speed: 0, bob: 0, stepPhase: 0, floorY: 0,
  keys: {}, sens: 1, invert: false, locked: false, frozen: false, moveTouch: { x: 0, y: 0 },
  room: 'hall', headClear: 2.75,
};

export function initPlayer(camera, dom) {
  camera.rotation.order = 'YXZ';
  addEventListener('keydown', (e) => { P.keys[e.code] = true; if (e.code === 'ControlLeft' || e.code === 'KeyC') P.crouch = !P.crouch; });
  addEventListener('keyup', (e) => { P.keys[e.code] = false; });
  addEventListener('blur', () => { P.keys = {}; });
  dom.addEventListener('mousemove', (e) => {
    if (!P.locked || P.frozen) return;
    look(e.movementX, e.movementY);
  });
}
export function look(dx, dy) {
  const k = 0.0022 * P.sens;
  P.yaw -= dx * k; P.pitch -= dy * k * (P.invert ? -1 : 1);
  P.pitch = Math.max(-1.5, Math.min(1.45, P.pitch));
}

// circle vs oriented rectangle push-out
function resolve(pos, c, r) {
  const dx = pos.x - c.x, dz = pos.z - c.z, cs = Math.cos(c.rot), sn = Math.sin(c.rot);
  const lx = dx * cs - dz * sn, lz = dx * sn + dz * cs;
  const qx = Math.max(-c.hx, Math.min(c.hx, lx)), qz = Math.max(-c.hz, Math.min(c.hz, lz));
  let ox = lx - qx, oz = lz - qz; const d2 = ox * ox + oz * oz;
  if (d2 >= r * r - 1e-7) return null;
  let px, pz;
  if (d2 > 1e-9) { const d = Math.sqrt(d2), k = (r - d) / d; px = ox * k; pz = oz * k; }
  else { // centre inside: out along the shallowest axis
    const ex = c.hx - Math.abs(lx), ez = c.hz - Math.abs(lz);
    if (ex < ez) { px = Math.sign(lx || 1) * (ex + r); pz = 0; } else { px = 0; pz = Math.sign(lz || 1) * (ez + r); }
  }
  // back to world
  const wx = px * cs + pz * sn, wz = -px * sn + pz * cs;
  pos.x += wx; pos.z += wz;
  return [wx, wz];
}

const SURF = { living: 'wood', bedroom: 'wood', child: 'wood', kitchen: 'lino', hall: 'lino', bath: 'tile', storage: 'concrete', balcony: 'concrete' };
function surfaceAt(x, z, room) {
  for (const s of G.surfaceSpots || []) if (Math.hypot(x - s.x, z - s.z) < s.r) return s.kind;
  return SURF[room] || 'concrete';
}

const fwd = new THREE.Vector3(), right = new THREE.Vector3(), wish = new THREE.Vector3();
export function updatePlayer(dt, camera) {
  const k = P.keys;
  let mx = 0, mz = 0;
  if (!P.frozen) {
    if (k.KeyW || k.ArrowUp) mz += 1; if (k.KeyS || k.ArrowDown) mz -= 1;
    if (k.KeyA || k.ArrowLeft) mx -= 1; if (k.KeyD || k.ArrowRight) mx += 1;
    mx += P.moveTouch.x; mz += P.moveTouch.y;
  }
  const run = (k.ShiftLeft || k.ShiftRight) && !P.crouch;
  const maxV = P.crouch ? 0.85 : run ? 2.9 : 1.55;
  fwd.set(-Math.sin(P.yaw), 0, -Math.cos(P.yaw)); right.set(-fwd.z, 0, fwd.x);
  wish.set(0, 0, 0).addScaledVector(fwd, mz).addScaledVector(right, mx);
  if (wish.lengthSq() > 1) wish.normalize();
  wish.multiplyScalar(maxV * (P.pushing ? P.pushing : 1));
  const acc = wish.lengthSq() > 0 ? 9 : 11;
  P.vel.x += (wish.x - P.vel.x) * Math.min(1, acc * dt);
  P.vel.z += (wish.z - P.vel.z) * Math.min(1, acc * dt);
  const before = P.pos.clone();
  P.pos.x += P.vel.x * dt; P.pos.z += P.vel.z * dt;

  // collide: static colliders in the body's height band
  const feet = P.floorY, head = feet + P.height;
  P.pushing = false;
  for (let it = 0; it < 3; it++) {
    for (const c of G.colliders) {
      if (!c.on || c.y1 < feet + 0.2 || c.y0 > head) continue;
      resolve(P.pos, c, P.radius);
    }
    // heavy props block and get shoved; light ones get kicked
    for (const p of G.props) {
      if (p.dead || p.held) continue;
      const f = propFootprint(p);
      if (f.y1 < feet + (p.push ? 0.12 : 0.02) || f.y0 > head) continue;
      const push = resolve(P.pos, f, P.radius * (p.push ? 1 : 0.8));
      if (!push) continue;
      const len = Math.hypot(push[0], push[1]) || 1;
      if (p.push) {
        if (p.body.sleepState) p.body.wakeUp();
        const v = Math.hypot(P.vel.x, P.vel.z), k2 = Math.min(1, 20 / p.mass);
        p.body.velocity.x = -push[0] / len * v * k2 * 2.0; p.body.velocity.z = -push[1] / len * v * k2 * 2.0;
        P.pushing = Math.max(0.35, Math.min(1, 1.2 - p.mass / 60));
        if (!p.scrapeT || performance.now() - p.scrapeT > 600) { p.scrapeT = performance.now(); if (v > 0.2) sfx(p.mass > 30 ? 'drag' : 'doorScrape', p.mesh.position, { vol: Math.min(0.7, v * 0.4) }); }
      } else {
        p.body.wakeUp();
        const v = Math.hypot(P.vel.x, P.vel.z);
        p.body.velocity.x = -push[0] / len * v * 1.4 + P.vel.x * 0.5; p.body.velocity.z = -push[1] / len * v * 1.4 + P.vel.z * 0.5;
        p.body.velocity.y = 0.6 * v;
      }
    }
  }
  const moved = Math.hypot(P.pos.x - before.x, P.pos.z - before.z) / Math.max(dt, 1e-4);
  P.speed += (moved - P.speed) * Math.min(1, dt * 10);

  // floor height: the balcony slab is a step down
  const onBal = P.pos.z < -0.25 && P.pos.x > BALCONY.x0 && P.pos.x < BALCONY.x1;
  const fy = onBal ? BALCONY.y : 0;
  P.floorY += (fy - P.floorY) * Math.min(1, dt * 12);
  P.room = roomAt(P.pos.x, P.pos.z) || (onBal ? 'balcony' : P.room);

  // crouch (and can't stand up under something low)
  const target = P.crouch ? 1.05 : 1.62;
  P.height += (target - P.height) * Math.min(1, dt * 8);

  // head bob + footsteps
  const moving = P.speed > 0.25;
  if (moving) {
    const rate = P.speed * (P.crouch ? 2.2 : 1.85);
    P.stepPhase += dt * rate;
    if (P.stepPhase >= 1) {
      P.stepPhase -= 1;
      const surf = surfaceAt(P.pos.x, P.pos.z, P.room);
      const vol = (P.crouch ? 0.25 : run ? 0.9 : 0.55);
      sfx('step_' + surf, { x: P.pos.x, y: P.floorY + 0.05, z: P.pos.z }, { vol, room: P.room });
      if (surf === 'wood' && Math.random() < 0.18) sfx('boardCreak', { x: P.pos.x, y: 0, z: P.pos.z }, { vol: 0.5, room: P.room });
      G.onNoise?.(P.pos, vol * 0.5);
    }
  } else P.stepPhase = Math.min(P.stepPhase, 0.5);
  P.bob += dt * (moving ? P.speed * 5.8 : 1.2);
  const bobAmt = moving ? Math.min(1, P.speed / 2) * (P.crouch ? 0.012 : 0.028) : 0.003;
  const breathe = Math.sin(G.time * 1.3) * 0.004;
  P.eye = P.height - 0.08 + Math.sin(P.bob * 2) * bobAmt + breathe;

  camera.position.set(P.pos.x + Math.cos(P.bob) * bobAmt * 0.4 * right.x, P.floorY + P.eye, P.pos.z + Math.cos(P.bob) * bobAmt * 0.4 * right.z);
  camera.rotation.set(P.pitch, P.yaw, Math.cos(P.bob) * bobAmt * 0.25);
}
