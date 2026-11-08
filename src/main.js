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
import { I, UI, updateInteract, use, throwHeld, beginInspect, endInspect, inspectLook, inspectRead, drop } from './interact.js';
import { initAudio, updateAudio, setMasterVolume } from './audio.js';
import { ROOMS, roomAt } from './plan.js';
import { grainShader } from './post.js';
import { PAD, updatePad } from './gamepad.js';
import { buildStairwell, FLOORS } from './building.js';
import { buildFlats } from './flats.js';
import { initDecay, patchAll } from './decay.js';
import { DOORS } from './openings.js';
import { playIntro } from './cutscene.js';
import { buildHands } from './hands.js';
import { buildMarta } from './marta.js';
import { objective } from './voice.js';

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
  buildMarta();
  msg('Opening up the rest of the building…'); await frame();
  buildStairwell();
  buildFlats();
  msg('Building the city outside…'); await frame();
  const before = new Set(scene.children);
  buildExterior();
  const outside = scene.children.filter((o) => (!before.has(o) && !o.userData.indoor) || o.userData.outdoor);
  ambientize(outside);
  G.outside = outside.filter((o) => !o.userData.outdoor); // the city (not our facade or balcony)
  buildDust();
  if (params.has('bright')) scene.add(new THREE.AmbientLight(0xffffff, +params.get('bright') || 1.5));
  if (params.has('exposure')) renderer.toneMappingExposure = +params.get('exposure');
  msg('Settling the dust…'); await frame();
  bakeStatics(scene);
  scene.traverse((o) => { if (o !== scene && o.userData.noBake && !o.parent?.userData?.noBake) bakeStatics(o); });
  // tiny things don't need to cast shadows
  scene.traverse((o) => { if (o.isMesh && o.castShadow) { if (!o.geometry.boundingSphere) o.geometry.computeBoundingSphere(); const sc = o.getWorldScale(new THREE.Vector3()); if (o.geometry.boundingSphere.radius * Math.max(sc.x, sc.y, sc.z) < 0.06) o.castShadow = false; } });
  for (const s of scene.children) if (s.isMesh && /-(n|s|e|w|ceiling)$/.test(s.name)) { s.castShadow = true; s.userData.blocker = true; I.blockers.push(s); }
  for (const s of G.zoneSkins || []) I.blockers.push(s);
  buildHands(camera);
  initDecay();
  patchAll(scene);

  composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  grainPass = new ShaderPass(grainShader); composer.addPass(grainPass); G.post = grainPass;
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
function bakeStatics(root) {
  const groups = new Map();
  scene.updateMatrixWorld(true);
  const keep = [];
  const inv = root === scene ? null : root.matrixWorld.clone().invert();
  root.traverse((o) => {
    if (!o.isMesh || o.isInstancedMesh || !o.userData.static || Array.isArray(o.material)) return;
    for (let p = o; p && p !== root; p = p.parent) if (p.userData.prop || p.userData.it || p.userData.pickSpec || p.userData.noBake) return;
    if (o.userData.it || o.userData.prop || o.userData.pickSpec) return;
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
      g.applyMatrix4(m.matrixWorld); if (inv) g.applyMatrix4(inv);
      geos.push(g);
    }
    if (geos.length < 2) continue;
    const mg = BufferGeometryUtils.mergeGeometries(geos, false);
    if (!mg) continue;
    const mm = new THREE.Mesh(mg, list[0].material); mm.castShadow = list[0].castShadow; mm.receiveShadow = true;
    root.add(mm);
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
// what's visible and lit depends on where you are
function updateWorld(dt, force = false) {
  const rn = P.room === 'balcony' ? 'Balcony' : P.zone ? P.zone.name : ROOMS[P.room]?.name || '';
  if (rn !== roomName) {
    roomName = rn; UI.room(rn); G.onRoom?.(P.room);
    // occlusion by room: from the windowless rooms none of the city can be seen, so don't draw it
    const zk = String(P.room).split(':')[0];
    const sealed = ['bath', 'storage', 'f48', 'f44', 'f51', 'void', 'street', 'stair0', 'stair1'].includes(zk);
    for (const o of G.outside || []) o.visible = !sealed;
    for (const o of scene.children) if (o.userData.outdoor) o.visible = !['f51', 'void', 'f44', 'f48'].includes(zk);
  }
  // only draw the parts of the building near you (two floors either way)
  if (force || frameN % 10 === 0) {
    for (const [f, g] of Object.entries(FLOORS)) g.visible = Math.abs((+f - 4) * 3.1 - P.floorY) < 7.5;
    for (const z of G.zones) if (z.def?.group) z.def.group.visible = Math.abs(z.y0 - P.floorY) < 4.8;
  }
  // the sun only reaches where there are windows; and its shadow map follows you
  const skyL = G.lights.sky?.l;
  if (skyL) {
    const want = (P.zone ? P.zone.sky ?? 1 : 1) * 1.25 * (1 - (G.decay || 0) * 0.5);
    skyL.intensity += (want - skyL.intensity) * Math.min(1, dt * 3);
    const sx = Math.round(P.pos.x), sz = Math.round(P.pos.z), sy = Math.round(P.floorY);
    skyL.target.position.set(sx, sy, sz); skyL.position.set(sx - 7, sy + 13, sz - 17);
    for (const k of ['winLiving', 'winBal', 'winBed', 'winKit']) { const l = G.lights[k]?.l; if (l) l.intensity = !P.zone && Math.abs(P.floorY) < 2.5 ? (l.userData.k ??= l.intensity) : 0; }
  }
}

function loop(now) {
  requestAnimationFrame(loop);
  clock.update(now); const dt = Math.min(0.05, clock.getDelta());
  if (!G.running && !params.has('shots')) { updatePad(dt, padH); composer.render(); return; }
  G.time += dt;
  P.frozen = I.inspecting || !!G.peeping || !!G.lockPlayer;
  updatePad(dt, padH);
  if (G.cutscene) G.cutscene.update(dt); else updatePlayer(dt, camera);
  shake(dt);
  G.playerPos = (G.playerPos || new THREE.Vector3()).set(P.pos.x, P.floorY, P.pos.z);
  G.playerZone = P.room;
  G.phys.step(1 / 60, dt, 3);
  for (const f of G.updates) f(dt, G.time);
  updateLights(dt);
  if (!G.cutscene) updateInteract(dt, camera); else UI.prompt('');
  updateAudio(camera, dt, P.room);
  UI.tick(dt);
  updateWorld(dt);
  fade(dt);
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
// a jolt to the camera, dying away
function shake(dt) {
  if (!G.shake) return;
  const k = G.shake; G.shake = Math.max(0, k - dt * 0.9);
  camera.rotation.x += (Math.random() - 0.5) * k * 0.05; camera.rotation.y += (Math.random() - 0.5) * k * 0.05; camera.position.y += (Math.random() - 0.5) * k * 0.02;
}
// white or black fades for the places that give you back
let fadeK = 0, fadeCol = '#fff';
function fade(dt) {
  if (G.whiteout) { fadeCol = '#f2f2ee'; fadeK = Math.min(1, fadeK + dt * 3); G.whiteout -= dt; if (G.whiteout <= 0) G.whiteout = 0; }
  else if (G.blackout) { fadeCol = '#000'; fadeK = Math.min(1, fadeK + dt * 2); G.blackout -= dt; if (G.blackout <= 0) G.blackout = 0; }
  else fadeK = Math.max(0, fadeK - dt * 0.8);
  const el = $('fade'); el.style.background = fadeCol; el.style.opacity = fadeK;
}
// move the player somewhere else, keeping (or not) where they were looking
G.teleport = (x, z, y, yaw = null, keep = false) => {
  P.pos.x = x; P.pos.z = z; P.floorY = y; if (yaw !== null) { P.yaw = yaw; P.pitch = 0; }
  if (!keep) P.vel.set(0, 0, 0);
  if (I.held) { const b = I.held.body; b.position.set(x, y + 1.3, z); }
  updatePlayer(0, camera);
};
$('enter').onclick = () => {
  initAudio(); G.running = true; $('start').classList.add('hidden');
  if (!G.flags.started) {
    G.flags.started = true;
    const after = () => { setTimeout(() => UI.toast('The chain won’t come off. There’s a padlock through it. The hall bulb is dying — F for the torch.', 6), 900); setTimeout(() => objective('Find Marta Sokolova.'), 3000); };
    if (params.has('skip')) after(); else playIntro(after);
  } if (PAD.using) P.locked = true; else if (matchMedia('(pointer: coarse)').matches) { $('touch').classList.remove('hidden'); P.locked = true; } else lock(); };
$('resume').onclick = () => resumeGame();
document.addEventListener('pointerlockchange', () => {
  P.locked = document.pointerLockElement === renderer.domElement;
  if (!P.locked && G.running && !I.reading && !PAD.using) { G.running = false; $('pause').classList.remove('hidden'); P.keys = {}; }
  if (PAD.using) P.locked = true;
});
$('sens').oninput = (e) => { P.sens = +e.target.value; };
$('vol').oninput = (e) => setMasterVolume(+e.target.value);
$('invert').onchange = (e) => { P.invert = e.target.checked; };
$('quality').onchange = (e) => { Q = e.target.value; applyQuality(); };
addEventListener('resize', () => { camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); renderer.setSize(innerWidth, innerHeight); composer?.setSize(innerWidth, innerHeight); });
addEventListener('keydown', (e) => {
  if (!G.running) return;
  if (G.cutscene) { if (['Escape', 'Space', 'KeyE', 'Enter'].includes(e.code)) G.cutscene.skip(); return; }
  if (e.code === 'KeyE') { if (I.inspecting && I.held?.doc && !I.reading) inspectRead(); else use(); }
  if (e.code === 'KeyF') G.toggleTorch?.();
  if (e.code === 'Escape' && I.reading) UI.closeRead();
  if (e.code === 'KeyR' && I.inspecting) inspectRead();
});
renderer && 0;
addEventListener('mousedown', (e) => {
  if (!G.running || G.cutscene) return;
  if (I.reading) { UI.closeRead(); return; }
  if (e.button === 0) { if (I.inspecting) endInspect(); else if (I.held) throwHeld(); else use(); }
  if (e.button === 2) { if (I.inspecting) endInspect(); else if (I.held) beginInspect(); }
});
addEventListener('contextmenu', (e) => e.preventDefault());
addEventListener('mousemove', (e) => { if (I.inspecting && P.locked) inspectLook(e.movementX, e.movementY); });

// ---------------------------------------------------------------- controller
const focusables = () => {
  if (!$('start').classList.contains('hidden')) return [$('enter')];
  if (!$('pause').classList.contains('hidden')) return ['sens', 'vol', 'quality', 'invert', 'resume'].map($);
  return [];
};
let focusI = 0;
const setFocus = (i) => { const f = focusables(); if (!f.length) return; focusI = (i + f.length) % f.length; f.forEach((el, k) => el.closest('label, button').classList.toggle('padFocus', k === focusI)); f[focusI].focus({ preventScroll: true }); };
function pauseGame() { if (!G.running) return; G.running = false; P.keys = {}; $('pause').classList.remove('hidden'); document.exitPointerLock?.(); setFocus(focusables().length - 1); }
function resumeGame() { $('pause').classList.add('hidden'); G.running = true; if (!PAD.using) lock(); }
const padH = {
  menuOpen: () => focusables().length > 0,
  menuMove: (d) => setFocus(focusI + d),
  menuAdjust: (d) => {
    const el = focusables()[focusI]; if (!el) return;
    if (el.type === 'range') { el.value = +el.value + d * (+el.step || 0.05) * 4; el.dispatchEvent(new Event('input')); }
    else if (el.tagName === 'SELECT') { el.selectedIndex = Math.max(0, Math.min(el.options.length - 1, el.selectedIndex + d)); el.dispatchEvent(new Event('change')); }
  },
  menuPress: () => { const el = focusables()[focusI]; if (!el) return; if (el.type === 'checkbox') { el.checked = !el.checked; el.dispatchEvent(new Event('change')); } else if (el.tagName === 'BUTTON' && !el.disabled) el.click(); },
  menuBack: () => { if (!$('pause').classList.contains('hidden')) resumeGame(); },
  move: (x, y, run) => { P.padMove.x = x; P.padMove.y = y; P.padRun = run; },
  look: (dx, dy) => { if (I.inspecting) inspectLook(dx, dy); else if (!G.peeping) look(dx, dy); },
  use: () => { if (G.cutscene) { G.cutscene.skip(); return; } if (G.peeping) { dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyE' })); return; } if (I.inspecting && I.held?.doc && !I.reading) inspectRead(); else use(); },
  back: () => { if (G.peeping) dispatchEvent(new KeyboardEvent('keydown', { code: 'Escape' })); else if (I.reading) UI.closeRead(); else if (I.inspecting) endInspect(); else if (I.held) drop(0); },
  torch: () => G.toggleTorch?.(),
  crouch: () => { P.crouch = !P.crouch; },
  throw: () => { if (I.inspecting) endInspect(); else if (I.held) throwHeld(); },
  inspect: () => { if (I.inspecting) endInspect(); else if (I.held) beginInspect(); },
  pause: () => { if (G.cutscene) G.cutscene.skip(); else pauseGame(); },
  onMode: () => { G.glyph = 'A'; $('touch').classList.add('hidden'); document.body.classList.add('pad'); },
};
addEventListener('gamepadconnected', () => { if (!$('start').classList.contains('hidden') && !$('enter').disabled) setFocus(0); });
addEventListener('mousemove', () => { if (PAD.using && performance.now() - PAD.lastUse > 1500) { PAD.using = false; G.glyph = 'E'; document.body.classList.remove('pad'); } });
// the Android back button
window.__back = () => { if (I.reading) UI.closeRead(); else if (G.running) pauseGame(); else if (!$('pause').classList.contains('hidden')) resumeGame(); };
window.__pauseGame = pauseGame;

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
window.__G = G; window.__P = P; window.__I = I; G.doorsById = DOORS; G.I = I;
window.__view = (x, z, yaw, pitch = 0, crouch = false, y = 0) => { P.pos.set(x, 0, z); P.floorY = y; P.yaw = yaw; P.pitch = pitch; P.crouch = crouch; P.height = crouch ? 1.05 : 1.62; for (let i = 0; i < 3; i++) { updatePlayer(0.016, camera); } };
window.__step = (n = 30) => { renderer.info.autoReset = false; for (let i = 0; i < n; i++) { G.playerPos = (G.playerPos || new THREE.Vector3()).set(P.pos.x, P.floorY, P.pos.z); G.playerZone = P.room; updateWorld(1 / 60, true); G.time += 1 / 60; updatePlayer(1 / 60, camera); G.phys.step(1 / 60); for (const f of G.updates) f(1 / 60, G.time); updateLights(1 / 60); updateInteract(1 / 60, camera); } renderer.info.reset(); composer.render(); };
window.__roomAt = roomAt;
// test helper: advance whatever is running (cutscene included) by sec seconds, then draw
window.__advance = (sec) => { const n = Math.round(sec * 30); for (let i = 0; i < n; i++) { G.time += 1 / 30; if (G.cutscene) G.cutscene.update(1 / 30); else updatePlayer(1 / 30, camera); shake(1 / 30); G.phys.step(1 / 30); for (const f of G.updates) f(1 / 30, G.time); updateLights(1 / 30); updateWorld(1 / 30, true); } if (!G.cutscene) updateInteract(1 / 30, camera); composer.render(); };
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
