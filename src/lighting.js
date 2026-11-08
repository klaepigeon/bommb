// Light: the grey evening coming in through the courtyard windows, and the few fittings
// in the flat that still work, on whatever the building's wiring still gives them.
import * as THREE from 'three';
import { RectAreaLightUniformsLib } from 'three/examples/jsm/lights/RectAreaLightUniformsLib.js';
import { G, box, mat, interactive, onUpdate, circuit, solidMat } from './core.js';
import { sfx, loopSource, AUDIO } from './audio.js';

export const LIGHTS = [];
let brown = 1, brownT = 30;

// a controllable light. fixture: meshes whose emissive follows the light
export function addLight(name, l, o = {}) {
  l.userData.base = l.intensity;
  const L = {
    name, l, base: l.intensity, switched: o.on ?? true, broken: o.broken || false, circuit: o.circuit || null,
    flicker: o.flicker || null, fixtures: o.fixtures || [], emissive: o.emissive ?? 1, k: 1, t: Math.random() * 100, buzz: null, buzzPos: o.buzzPos || null,
    state: 0, timer: 0, startup: 0, mains: o.mains ?? !!o.circuit,
  };
  if (!o.virtual) G.scene.add(l);
  if (l.target && o.target) { l.target.position.copy(o.target); G.scene.add(l.target); }
  LIGHTS.push(L); G.lights[name] = L;
  return L;
}
export function powered(L) { return L.switched && !L.broken && (!L.circuit || circuit(L.circuit).on); }

export function toggleLight(L, v) {
  const was = powered(L);
  L.switched = v ?? !L.switched;
  if (!was && powered(L) && L.flicker === 'fluoro') L.startup = 1.4;
}

// wall switch: a bakelite rocker on a plate, toggles a set of lights
export function wallSwitch(x, y, z, ry, lights, o = {}) {
  const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = ry; G.scene.add(g);
  const plate = box(0.075, 0.075, 0.012, mat('switchPlate', { color: 0xc8bea8, roughness: 0.5 }), { parent: g, static: false });
  const rocker = box(0.03, 0.045, 0.014, solidMat('rocker', 0x2a2018, 0.4), { z: 0.01, parent: g, static: false });
  if (o.hanging) { plate.rotation.z = 0.4; plate.position.y -= 0.02; } // plate hanging off its screws, wires out
  const Ls = lights.map((n) => G.lights[n]).filter(Boolean);
  const sync = () => { const on = Ls.some((L) => L.switched); rocker.rotation.x = on ? -0.25 : 0.25; };
  sync();
  interactive([plate, rocker], {
    range: 1.6,
    prompt: () => o.label || 'Light switch',
    use: () => {
      const now = !Ls.some((L) => L.switched);
      Ls.forEach((L) => toggleLight(L, now)); sync();
      sfx('switch', g.position, { vol: 0.7 });
      const dead = Ls.every((L) => !powered(L));
      if (now && dead) {
        const why = Ls.some((L) => L.broken) ? (o.brokenMsg || 'Click. The bulb has gone.') : 'Click. Nothing. No power to this side.';
        setTimeout(() => G.ui.toast(why, 3), 200);
      }
    },
  });
  return g;
}

function flick(L, dt) {
  L.t += dt;
  const t = L.t;
  switch (L.flicker) {
    case 'fluoro': {
      if (L.startup > 0) { L.startup -= dt; return Math.random() < 0.35 ? 1 : Math.random() < 0.4 ? 0.25 : 0; }
      if (L.timer > 0) { L.timer -= dt; return L.state; }
      if (Math.random() < dt * 0.35) { L.timer = 0.04 + Math.random() * 0.25; L.state = Math.random() < 0.6 ? 0 : 0.4; return L.state; }
      if (Math.random() < dt * 0.03) { L.startup = 0.8 + Math.random() * 1.5; }
      return 0.96 + Math.sin(t * 314) * 0.03;
    }
    case 'bulb': return 0.94 + Math.sin(t * 7.1) * 0.02 + Math.sin(t * 23.3) * 0.015 + (Math.random() < dt * 0.4 ? -0.4 : 0);
    case 'dying': {
      if (L.timer > 0) { L.timer -= dt; return L.state; }
      if (Math.random() < dt * 1.5) { L.timer = 0.03 + Math.random() * 0.3; L.state = Math.random() * 0.4; return L.state; }
      return 0.8 + Math.sin(t * 11) * 0.08;
    }
    case 'candle': return 0.82 + Math.sin(t * 9.7) * 0.06 + Math.sin(t * 23.1 + 1) * 0.05 + (Math.random() - 0.5) * 0.12;
    case 'tv': return 0.55 + Math.random() * 0.35 + Math.sin(t * 2.2) * 0.1;
    case 'emergency': return 0.65 + 0.35 * Math.max(0, Math.sin(t * 2.1));
    case 'beacon': return (t % 1.6) < 0.18 ? 1 : 0;
    default: return 1;
  }
}

export function updateLights(dt) {
  // the building's supply sags now and then: every mains light dims together
  brownT -= dt;
  if (brownT <= 0) { brownT = 35 + Math.random() * 60; brown = 0.25 + Math.random() * 0.3; setTimeout(() => { brown = 0.6; }, 300 + Math.random() * 900); setTimeout(() => { brown = 1; }, 1500 + Math.random() * 1500); }
  if (G.lightsKill > 0) G.lightsKill -= dt;
  for (const L of LIGHTS) {
    const on = powered(L) && !(G.lightsKill > 0 && L.name !== 'sky');
    let k = on ? flick(L, dt) : 0;
    if (on && L.mains) k *= brown;
    L.k = k;
    L.l.intensity = L.base * k;
    for (const f of L.fixtures) if (f.material && f.material.emissiveIntensity !== undefined) f.material.emissiveIntensity = L.emissive * k;
    if (L.buzzPos && AUDIO.ready) {
      if (!L.buzz) L.buzz = loopSource('buzz', L.buzzPos, { vol: 0 });
      L.buzz && L.buzz.set(on ? 0.08 * Math.min(1, k + 0.2) : 0, 0.02);
    }
  }
}

// ---------------------------------------------------------------- natural light
export function buildDaylight() {
  RectAreaLightUniformsLib.init();
  // the overcast dusk: cold, low, from the courtyard side
  const sky = new THREE.DirectionalLight(0x9fb0c8, 1.25);
  sky.position.set(-3, 13, -14); sky.target.position.set(4, 0, 3);
  sky.castShadow = true; sky.shadow.mapSize.set(2048, 2048);
  Object.assign(sky.shadow.camera, { left: -9, right: 9, top: 9, bottom: -9, near: 1, far: 40 });
  sky.shadow.bias = -0.0004; sky.shadow.normalBias = 0.03;
  G.scene.add(sky, sky.target);
  G.lights.sky = { l: sky };
  // the sky itself, very low — what keeps the outside from going pure black
  const hemi = new THREE.HemisphereLight(0x6a7890, 0x1a140e, 0.06);
  G.scene.add(hemi);
  // soft window light (bounced sky) at each courtyard window, facing in
  const win = (x, y, z, w, h, k) => { const r = new THREE.RectAreaLight(0xa8b8cc, k, w, h); r.position.set(x, y, z); r.lookAt(x, y, z + 5); G.scene.add(r); return r; };
  G.lights.winLiving = { l: win(1.65, 1.6, -0.05, 1.7, 1.4, 6.5) };
  G.lights.winBal = { l: win(3.17, 1.2, -0.05, 0.7, 2.2, 3.5) };
  G.lights.winBed = { l: win(6.0, 1.6, -0.05, 1.4, 1.4, 5) };
  G.lights.winKit = { l: win(8.85, 1.65, -0.05, 1.1, 1.3, 4) };
}
