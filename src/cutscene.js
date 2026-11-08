// The opening: Lebedev, a private investigator, comes to Building 14 on a wellness check
// for Marta Sokolova's sister. The courtyard, the lobby, the stairs, the door of 47 standing
// open. He knocks, goes in, and the door shuts behind him — with the chain on, from inside.
//
// A cutscene is a list of shots. Each moves the camera along a path of points while it
// looks along another, shows lines of subtitle at set times, and can fire events.
import * as THREE from 'three';
import { G } from './core.js';
import { P } from './player.js';
import { floorY, GROUND } from './plan.js';
import { sfx, knockSeq } from './audio.js';
import { roomAt } from './plan.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
const $ = (id) => document.getElementById(id);
const Y1 = floorY(1), Y3 = floorY(3);

// path helpers: catmull-rom through points, eased
const curve = (pts) => new THREE.CatmullRomCurve3(pts, false, 'centripetal');
const ease = (t) => t * t * (3 - 2 * t);

function shots() {
  return [
    { // the courtyard, looking up at Building 14
      dur: 9, pos: curve([V(-2, GROUND + 1.7, -24), V(1, GROUND + 1.7, -21)]), look: curve([V(4, GROUND + 6, -0.4), V(3, 2.5, -0.4)]),
      lines: [[0.6, 'Kerzhansk. The twenty-third of October.'], [3.4, 'The Leninsky district was emptied on the fifteenth. Buses from the school yard at six.'], [6.4, 'Marta Sokolova’s sister in Kursk hasn’t heard from her since. She paid me to knock on a door.']],
    },
    { // inside the lobby, the street door white behind, walking to the stairs
      dur: 7, pos: curve([V(13.1, Y1 + 1.62, 7.4), V(12.6, Y1 + 1.62, 5.6), V(12.0, Y1 + 1.62, 4.2)]), look: curve([V(12.2, Y1 + 1.4, 2.5), V(11.4, Y1 + 0.6, 1.0), V(11.2, Y1 - 0.4, 0.6)]),
      lines: [[0.5, 'Building 14. The lift is dead. Post still in the boxes, eight days of it.'], [4.2, 'Fourth floor. Flat forty-seven.']], steps: true,
    },
    { // up the last flights to the fourth floor
      dur: 7.5, pos: curve([V(13.2, Y3 + 1.62, 4.6), V(13.2, Y3 + 1.62 + 0.8, 2.4), V(12.6, Y3 + 1.62 + 1.55, 0.7), V(11.2, Y3 + 1.62 + 2.3, 2.0), V(11.3, 1.62, 3.7), V(11.9, 1.62, 4.6)]),
      look: curve([V(13.2, Y3 + 2.4, 1.0), V(12.5, Y3 + 3.2, 0.4), V(10.6, Y3 + 3.0, 1.2), V(11.2, 0.6, 5.2), V(10.5, 1.4, 4.6), V(10.1, 1.35, 4.56)]),
      lines: [[4.6, 'Every bulb on the stairs dying at once, as if they’d agreed it.']], steps: true,
    },
    { // the door of 47: open
      dur: 7, pos: curve([V(11.9, 1.62, 4.62), V(11.4, 1.6, 4.58)]), look: curve([V(10.1, 1.4, 4.56), V(10.1, 1.3, 4.5)]),
      lines: [[0.6, 'The door’s been left open.'], [2.6, '“Mrs Sokolova? Lebedev. Your sister sent me. Hello?”']],
      events: [[0.0, () => { G.entry.setChain(false); G.entry.door.target = G.entry.door.angle = 0.32; }], [1.8, () => knockSeq(V(10.2, 1.4, 4.56), [3], 0.9)]],
    },
    { // in
      dur: 4.2, pos: curve([V(11.3, 1.6, 4.6), V(10.4, 1.62, 4.62), V(9.4, 1.62, 4.55)]), look: curve([V(10.0, 1.4, 4.56), V(8.5, 1.5, 4.5), V(6.5, 1.4, 4.5)]),
      lines: [[1.4, 'Hello?']], steps: true,
      events: [[0.0, () => { G.entry.door.speed = 2.4; G.entry.door.target = 1.25; sfx('doorCreak', V(10.2, 1.2, 4.6)); }]],
    },
    { // behind you
      dur: 4.6, pos: curve([V(9.4, 1.62, 4.55), V(9.35, 1.6, 4.55)]), look: (t) => { const a = Math.PI / 2 - Math.min(1, t / 0.18) * Math.PI; return V(9.4 - Math.sin(a + Math.PI) * 2 * -1, 1.4, 4.55 - Math.cos(a) * 0); },
      lookYaw: (t) => Math.PI / 2 - ease(Math.min(1, t / 0.16)) * Math.PI,
      lines: [[1.1, 'The chain is on.'], [2.6, 'From the inside.']],
      events: [[0.02, () => { const d = G.entry.door; d.speed = 9; d.target = 0; sfx('doorHeavy', d.world, { vol: 1.2 }); G.shake = 0.35; }], [0.45, () => { G.entry.setChain(true); G.entry.door.speed = 4; sfx('chainRattle', V(10.0, 1.5, 4.9), { vol: 1 }); }], [1.0, () => sfx('click', V(10.0, 1.5, 4.95), { vol: 1, rate: 0.6 })]],
    },
  ];
}

let state = null;
export function playIntro(onDone) {
  const list = shots();
  state = { list, i: 0, t: 0, fired: new Set(), lineAt: -1, onDone, stepT: 0 };
  G.cutscene = { update, skip };
  document.body.classList.add('cine');
  $('subs').textContent = '';
  begin(0);
}
function begin(i) { state.i = i; state.t = 0; state.fired = new Set(); state.lineAt = -1; $('subs').classList.remove('on'); }
const cam = new THREE.Vector3(), tgt = new THREE.Vector3();
function update(dt) {
  const s = state.list[state.i];
  state.t += dt;
  const k = Math.min(1, state.t / s.dur), e = ease(k);
  s.pos.getPoint(e, cam);
  const c = G.camera;
  c.position.copy(cam);
  if (s.lookYaw) { c.rotation.set(-0.05, s.lookYaw(state.t), 0, 'YXZ'); }
  else { (typeof s.look === 'function' ? s.look(e) : s.look.getPoint(e, tgt)); c.lookAt(typeof s.look === 'function' ? s.look(e) : tgt); }
  // a little hand-held drift
  c.rotation.z += Math.sin(G.time * 0.9) * 0.004; c.rotation.x += Math.sin(G.time * 0.6) * 0.003;
  // drive the world from the camera: culling, rooms, the listener
  P.pos.x = cam.x; P.pos.z = cam.z; P.floorY = cam.y - 1.62;
  P.zone = G.zoneAt(cam.x, cam.y - 0.6, cam.z); P.room = P.zone ? P.zone.key : roomAt(cam.x, cam.z, P.floorY) || 'outside';
  G.playerPos.set(cam.x, P.floorY, cam.z); G.playerZone = P.room;
  for (const [at, f] of s.events || []) if (state.t >= at && !state.fired.has(f)) { state.fired.add(f); f(); }
  // subtitles
  let line = -1; (s.lines || []).forEach(([at], n) => { if (state.t >= at) line = n; });
  if (line !== state.lineAt) { state.lineAt = line; const el = $('subs'); el.classList.remove('on'); if (line >= 0) setTimeout(() => { el.textContent = s.lines[line][1]; el.classList.add('on'); }, 180); }
  if (s.steps) { state.stepT -= dt; if (state.stepT <= 0) { state.stepT = 0.56; sfx(cam.y < -1 || cam.x > 10.4 ? 'step_concrete' : 'step_lino', V(cam.x, cam.y - 1.6, cam.z), { vol: 0.5 }); } }
  if (state.t >= s.dur) { if (state.i + 1 < state.list.length) begin(state.i + 1); else finish(); }
}
export function skip() {
  if (!state) return;
  // run every event that hasn't happened, so the world ends up as it would have
  for (let i = state.i; i < state.list.length; i++) for (const [, f] of state.list[i].events || []) if (!(i === state.i && state.fired.has(f))) f();
  finish();
}
function finish() {
  const done = state.onDone; state = null;
  G.cutscene = null; G.entry.setChain(true); G.entry.door.target = G.entry.door.angle = 0; G.entry.door.speed = 4;
  document.body.classList.remove('cine'); $('subs').classList.remove('on');
  // hand over: in the hall, facing the door that won't open
  P.pos.set(9.35, 0, 4.55); P.floorY = 0; P.yaw = -Math.PI / 2; P.pitch = -0.03; P.vel.set(0, 0, 0);
  done?.();
}
