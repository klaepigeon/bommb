// FLAT 47 — phase 1: the flat.
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import * as BufferGeometryUtils from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { G, initPhysics } from './core.js';
import { buildShell } from './shell.js';
import { buildOpenings } from './openings.js';
import { buildDaylight, updateLights, LIGHTS } from './lighting.js';
import { initMaterials } from './furniture.js';
import { dressFlat } from './dress.js';
import { buildExterior } from './exterior.js';
import { buildDust } from './particles.js';
import { P, initPlayer, updatePlayer, look } from './player.js';
import { propFootprint } from './props.js';
import { I, UI, updateInteract, use, throwHeld, beginInspect, endInspect, inspectLook, inspectRead } from './interact.js';
import { initAudio, updateAudio, setMasterVolume } from './audio.js';
import { ROOMS, roomAt } from './plan.js';
import { grainShader } from './post.js';

const params = new URLSearchParams(location.search);
const $ = (id) => document.getElementById(id);
const msg = (t) => { $('loadMsg').textContent = t; };
const frame = () => new Promise((r) => requestAnimationFrame(() => r()));

let renderer, scene, camera, composer, grainPass, clock;
const quality = { high: { px: 1, shadow: 2048 }, medium: { px: 0.85, shadow: 1024 }, low: { px: 0.6, shadow: 512 } };
let Q = params.get('q') || (matchMedia('(pointer: coarse)').matches ? 'low' : 'medium');

async function boot() {
  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance', preserveDrawingBuffer: params.has('shots') });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2) * quality[Q].px);
  renderer.setSize(innerWidth, innerHeight);
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.15;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  $('app').appendChild(renderer.domElement);
  scene = new THREE.Scene(); scene.background = new THREE.Color(0x10131a);
  scene.fog = new THREE.FogExp2(0x262a31, 0.0062);
  camera = new THREE.PerspectiveCamera(72, innerWidth / innerHeight, 0.03, 1400);
  scene.add(camera);
  G.scene = scene; G.camera = camera; G.renderer = renderer;
  initPhysics();

  msg('Papering the walls…'); await frame();
  initMaterials();
  buildShell();
  msg('Hanging the doors…'); await frame();
  buildOpenings();
  buildDaylight();
  msg('Putting their things back where they left them…'); await frame();
  dressFlat();
  msg('Building the city outside…'); await frame();
  const before = new Set(scene.children);
  buildExterior();
  ambientize(scene.children.filter((o) => (!before.has(o) && !o.userData.indoor) || o.userData.outdoor));
  buildDust();
  if (params.has('bright')) scene.add(new THREE.AmbientLight(0xffffff, +params.get('bright') || 1.5));
  if (params.has('exposure')) renderer.toneMappingExposure = +params.get('exposure');
  msg('Settling the dust…'); await frame();
  bakeStatics();
  // tiny things don't need to cast shadows
  scene.traverse((o) => { if (o.isMesh && o.castShadow) { if (!o.geometry.boundingSphere) o.geometry.computeBoundingSphere(); const sc = o.getWorldScale(new THREE.Vector3()); if (o.geometry.boundingSphere.radius * Math.max(sc.x, sc.y, sc.z) < 0.06) o.castShadow = false; } });
  for (const s of scene.children) if (s.isMesh && /-(n|s|e|w|ceiling)$/.test(s.name)) { s.castShadow = true; s.userData.blocker = true; I.blockers.push(s); }

  composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  grainPass = new ShaderPass(grainShader); composer.addPass(grainPass);
  composer.addPass(new OutputPass());

  initPlayer(camera, renderer.domElement);
  clock = new THREE.Timer();
  applyQuality();
  updatePlayer(0.016, camera);
  // warm the shaders up so the first look round doesn't stutter
  renderer.compile(scene, camera);
  msg('');
  $('enter').disabled = false;
  window.__ready = true;
  requestAnimationFrame(loop);
}

// the outside is lit by the whole overcast sky; inside only by what comes through the
// windows. Lights can't be masked per object, so outdoor materials carry their share of
// skylight as emission instead of a hemisphere light that would flood the flat.
function ambientize(objs) {
  const cache = new Map();
  const conv = (m) => {
    if (!m || !m.isMeshStandardMaterial) return m;
    if (cache.has(m)) return cache.get(m);
    const c = m.clone();
    if (!m.emissiveMap) { c.emissive = new THREE.Color(0x8c98ac).multiply(m.color); c.emissiveMap = m.map || null; c.emissiveIntensity = 0.42; }
    cache.set(m, c); return c;
  };
  for (const o of objs) o.traverse((x) => { if (x.isMesh) x.material = Array.isArray(x.material) ? x.material.map(conv) : conv(x.material); });
}

// merge everything static by material: far fewer draw calls for the same picture
function bakeStatics() {
  const groups = new Map();
  scene.updateMatrixWorld(true);
  const keep = [];
  scene.traverse((o) => {
    if (!o.isMesh || o.isInstancedMesh || !o.userData.static || Array.isArray(o.material)) return;
    for (let p = o; p; p = p.parent) if (p.userData.prop || p.userData.it || p.userData.pickSpec || p.userData.noBake) return;
    if (o.material.transparent) return;
    const key = o.material.uuid + (o.castShadow ? 'c' : 'n');
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(o);
  });
  let merged = 0;
  for (const list of groups.values()) {
    if (list.length < 2) continue;
    const geos = [];
    for (const m of list) {
      let g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone();
      for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k);
      if (!g.attributes.uv) continue;
      g.applyMatrix4(m.matrixWorld);
      geos.push(g);
    }
    if (geos.length < 2) continue;
    const mg = BufferGeometryUtils.mergeGeometries(geos, false);
    if (!mg) continue;
    const mm = new THREE.Mesh(mg, list[0].material); mm.castShadow = list[0].castShadow; mm.receiveShadow = true;
    scene.add(mm);
    for (const m of list) { m.parent.remove(m); m.geometry.dispose(); }
    merged += list.length;
  }
  void keep;
  if (params.has('debug')) console.log('baked', merged, 'meshes into', groups.size);
}

function applyQuality() {
  const q = quality[Q];
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2) * q.px);
  renderer.setSize(innerWidth, innerHeight); composer.setSize(innerWidth, innerHeight);
  const tiers = { low: ['low'], medium: ['low', 'medium'], high: ['low', 'medium', 'high'] }[Q];
  scene.traverse((o) => {
    if (!o.isLight || !o.shadow) return;
    if (o.userData.shadowTier) o.castShadow = tiers.includes(o.userData.shadowTier);
    if (o.castShadow) { const sz = o.isPointLight ? Math.min(512, q.shadow) : q.shadow; o.shadow.mapSize.set(sz, sz); o.shadow.map?.dispose(); o.shadow.map = null; }
  });
  renderer.shadowMap.type = Q === 'low' ? THREE.PCFShadowMap : THREE.PCFShadowMap;
}

let last = 0, roomName = '', frameN = 0;
function loop(now) {
  requestAnimationFrame(loop);
  clock.update(now); const dt = Math.min(0.05, clock.getDelta());
  if (!G.running && !params.has('shots')) { composer.render(); return; }
  G.time += dt;
  P.frozen = I.inspecting || !!G.peeping;
  updatePlayer(dt, camera);
  G.phys.step(1 / 60, dt, 3);
  for (const f of G.updates) f(dt, G.time);
  updateLights(dt);
  updateInteract(dt, camera);
  updateAudio(camera, dt, P.room);
  UI.tick(dt);
  const rn = P.room === 'balcony' ? 'Balcony' : ROOMS[P.room]?.name || '';
  if (rn !== roomName) { roomName = rn; UI.room(rn); G.onRoom?.(P.room); }
  // static-ish shadow maps refresh on alternate frames; lights that are dark skip theirs
  frameN++;
  const sky = G.lights.sky?.l; if (sky) { sky.shadow.autoUpdate = false; sky.shadow.needsUpdate = frameN % 3 === 0; }
  for (const L of LIGHTS) if (L.l.castShadow && L.l !== G.torch?.light) { L.l.shadow.autoUpdate = false; L.l.shadow.needsUpdate = L.k > 0.02 && frameN % 2 === 0; }
  grainPass.uniforms.time.value = G.time;
  grainPass.uniforms.dark.value = G.peeping ? 1 : 0;
  composer.render();
  last = now;
}

// ---------------------------------------------------------------- input / menus
function lock() { renderer.domElement.requestPointerLock?.(); }
$('enter').onclick = () => { initAudio(); G.running = true; $('start').classList.add('hidden'); if (matchMedia('(pointer: coarse)').matches) { $('touch').classList.remove('hidden'); P.locked = true; } else lock(); };
$('resume').onclick = () => { $('pause').classList.add('hidden'); G.running = true; lock(); };
document.addEventListener('pointerlockchange', () => {
  P.locked = document.pointerLockElement === renderer.domElement;
  if (!P.locked && G.running && !I.reading) { G.running = false; $('pause').classList.remove('hidden'); P.keys = {}; }
});
$('sens').oninput = (e) => { P.sens = +e.target.value; };
$('vol').oninput = (e) => setMasterVolume(+e.target.value);
$('invert').onchange = (e) => { P.invert = e.target.checked; };
$('quality').onchange = (e) => { Q = e.target.value; applyQuality(); };
addEventListener('resize', () => { camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); composer?.setSize(innerWidth, innerHeight); });
addEventListener('keydown', (e) => {
  if (!G.running) return;
  if (e.code === 'KeyE') { if (I.inspecting && I.held?.doc && !I.reading) inspectRead(); else use(); }
  if (e.code === 'KeyF') G.toggleTorch?.();
  if (e.code === 'Escape' && I.reading) UI.closeRead();
  if (e.code === 'KeyR' && I.inspecting) inspectRead();
});
renderer && 0;
addEventListener('mousedown', (e) => {
  if (!G.running) return;
  if (I.reading) { UI.closeRead(); return; }
  if (e.button === 0) { if (I.inspecting) endInspect(); else if (I.held) throwHeld(); else use(); }
  if (e.button === 2) { if (I.inspecting) endInspect(); else if (I.held) beginInspect(); }
});
addEventListener('contextmenu', (e) => e.preventDefault());
addEventListener('mousemove', (e) => { if (I.inspecting && P.locked) inspectLook(e.movementX, e.movementY); });

// touch: left stick moves, drag elsewhere looks
{
  const stick = $('stick'), knob = stick.firstElementChild; let sid = null, lid = null, lx = 0, ly = 0;
  stick.addEventListener('touchstart', (e) => { sid = e.changedTouches[0].identifier; e.preventDefault(); }, { passive: false });
  addEventListener('touchmove', (e) => {
    for (const t of e.changedTouches) {
      if (t.identifier === sid) {
        const r = stick.getBoundingClientRect(), dx = t.clientX - (r.left + r.width / 2), dy = t.clientY - (r.top + r.height / 2);
        const l = Math.min(1, Math.hypot(dx, dy) / 55), a = Math.atan2(dy, dx);
        P.moveTouch.x = Math.cos(a) * l; P.moveTouch.y = -Math.sin(a) * l; knob.style.transform = `translate(${Math.cos(a) * l * 45}px,${Math.sin(a) * l * 45}px)`;
      } else if (t.identifier === lid) {
        if (I.inspecting) inspectLook((t.clientX - lx) * 2, (t.clientY - ly) * 2); else look((t.clientX - lx) * 2.2, (t.clientY - ly) * 2.2);
        lx = t.clientX; ly = t.clientY;
      }
    }
  }, { passive: false });
  addEventListener('touchstart', (e) => { for (const t of e.changedTouches) if (t.identifier !== sid && !t.target.closest('#tbtns,#stick') && G.running) { lid = t.identifier; lx = t.clientX; ly = t.clientY; } });
  addEventListener('touchend', (e) => { for (const t of e.changedTouches) { if (t.identifier === sid) { sid = null; P.moveTouch.x = P.moveTouch.y = 0; knob.style.transform = ''; } if (t.identifier === lid) lid = null; } });
  $('tbtns').addEventListener('touchstart', (e) => {
    const k = e.target.dataset.k; e.preventDefault(); if (!k) return;
    if (k === 'use') { if (I.reading) UI.closeRead(); else use(); }
    if (k === 'torch') G.toggleTorch?.();
    if (k === 'crouch') P.crouch = !P.crouch;
    if (k === 'throw') { if (I.inspecting) endInspect(); else if (I.held) throwHeld(); }
  }, { passive: false });
}

// screenshot hooks for tools/smoke.mjs
window.__G = G; window.__P = P; window.__I = I;
window.__view = (x, z, yaw, pitch = 0, crouch = false) => { P.pos.set(x, 0, z); P.yaw = yaw; P.pitch = pitch; P.crouch = crouch; P.height = crouch ? 1.05 : 1.62; for (let i = 0; i < 3; i++) { updatePlayer(0.016, camera); } };
window.__step = (n = 30) => { renderer.info.autoReset = false; for (let i = 0; i < n; i++) { G.time += 1 / 60; updatePlayer(1 / 60, camera); G.phys.step(1 / 60); for (const f of G.updates) f(1 / 60, G.time); updateLights(1 / 60); updateInteract(1 / 60, camera); } renderer.info.reset(); composer.render(); };
window.__roomAt = roomAt;
window.__use = use; window.__throw = throwHeld; window.__inspect = beginInspect; window.__endInspect = endInspect;
window.__aim = (x, y, z) => { const dx = x - camera.position.x, dy = y - camera.position.y, dz = z - camera.position.z; P.yaw = Math.atan2(-dx, -dz); P.pitch = Math.atan2(dy, Math.hypot(dx, dz)); updatePlayer(0.016, camera); updateInteract(0.016, camera); const t = I.target; return t ? (t.kind === 'use' ? (typeof t.it.prompt === 'function' ? t.it.prompt() : t.it.prompt) : t.kind + ':' + (t.spec?.name || t.prop?.name)) : null; };
// test helper: A* over a 10 cm grid of the walkable floor, then walk the path
window.__goto = (tx, tz, maxSec = 20) => {
  const R = 0.245, x0 = -0.4, z0 = -1.8, W = 112, Hh = 102, S = 0.1;
  const blocked = new Uint8Array(W * Hh);
  const foots = [...G.colliders.filter((c) => c.on && c.y1 > 0.2 && c.y0 < 1.6), ...G.props.filter((p) => p.push && !p.dead).map((p) => propFootprint(p))];
  for (let j = 0; j < Hh; j++) for (let i = 0; i < W; i++) {
    const x = x0 + i * S, z = z0 + j * S;
    for (const c of foots) { const dx = x - c.x, dz = z - c.z, cs = Math.cos(c.rot), sn = Math.sin(c.rot); const lx = dx * cs - dz * sn, lz = dx * sn + dz * cs; const qx = Math.max(-c.hx, Math.min(c.hx, lx)), qz = Math.max(-c.hz, Math.min(c.hz, lz)); if ((lx - qx) ** 2 + (lz - qz) ** 2 < R * R) { blocked[j * W + i] = 1; break; } }
  }
  const idx = (x, z) => [Math.round((x - x0) / S), Math.round((z - z0) / S)];
  const [si, sj] = idx(P.pos.x, P.pos.z), [ti, tj] = idx(tx, tz);
  const open = [[si, sj, 0]], came = new Map(), cost = new Map([[sj * W + si, 0]]);
  let found = false;
  while (open.length) {
    open.sort((a, b) => a[2] - b[2]); const [i, j] = open.shift();
    if (i === ti && j === tj) { found = true; break; }
    for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      const ni = i + di, nj = j + dj; if (ni < 0 || nj < 0 || ni >= W || nj >= Hh) continue;
      const k = nj * W + ni; if (blocked[k] && !(ni === ti && nj === tj)) continue;
      const c = cost.get(j * W + i) + Math.hypot(di, dj);
      if (c < (cost.get(k) ?? Infinity)) { cost.set(k, c); came.set(k, j * W + i); open.push([ni, nj, c + Math.hypot(ti - ni, tj - nj)]); }
    }
  }
  if (!found) { if (window.__mapDump) { let o = ''; for (let j = 0; j < Hh; j += 2) { for (let i = 0; i < W; i++) o += (i === si && j === sj) ? 'S' : blocked[j * W + i] ? '#' : '.'; o += '\n'; } return o; } return 'no path'; }
  const path = []; for (let k = tj * W + ti; k !== undefined; k = came.get(k)) path.unshift([x0 + (k % W) * S, z0 + Math.floor(k / W) * S]);
  for (let n = 0; n < path.length; n += 3) window.__walk(path[n][0], path[n][1], 1);
  window.__walk(tx, tz, 1);
  void maxSec;
  return [P.pos.x.toFixed(2), P.pos.z.toFixed(2), P.room];
};
// aim at a point; if nothing's targeted, edge toward it and try again
window.__reach = (x, y, z) => { for (let k = 0; k < 6; k++) { window.__step(1); const a = window.__aim(x, y, z); if (a) return a; const dx = x - P.pos.x, dz = z - P.pos.z, d = Math.hypot(dx, dz); if (d < 0.5) break; window.__walk(P.pos.x + dx / d * 0.25, P.pos.z + dz / d * 0.25, 0.5); } return null; };
window.__hits = (x, y, z) => { window.__aim(x, y, z); const r = new THREE.Raycaster(); r.setFromCamera(new THREE.Vector2(), camera); return r.intersectObjects(scene.children, true).filter((h) => !h.object.isPoints && !h.object.isSprite).slice(0, 6).map((h) => [h.object.name || h.object.type, h.object.userData.it ? 'IT' : '', h.object.userData.blocker ? 'BLK' : '', h.distance.toFixed(2), h.object.visible]); };
window.__walk = (x, z, sec = 2) => { const n = Math.round(sec * 60); for (let i = 0; i < n; i++) { const dx = x - P.pos.x, dz = z - P.pos.z; if (Math.hypot(dx, dz) < 0.1) break; P.yaw = Math.atan2(-dx, -dz); P.keys.KeyW = true; G.time += 1 / 60; updatePlayer(1 / 60, camera); G.phys.step(1 / 60); for (const f of G.updates) f(1 / 60, G.time); } P.keys.KeyW = false; return [P.pos.x.toFixed(2), P.pos.z.toFixed(2), P.room]; };

boot().catch((e) => { msg('Something went wrong: ' + e.message); console.error(e); });
