// Reality, dying. One number (G.decay, 0..0.9) that rises as you go further in, plus a few
// places where it's always worse. Every lit surface in the world is patched to read it:
// colour drains out in drifting patches, then the surface itself goes, in holes, from the
// edges inward. The city goes first, from the horizon toward you. The picture itself
// starts to slip. The building hums.
import * as THREE from 'three';
import { G, onUpdate } from './core.js';
import { AUDIO, loopSource, sfx } from './audio.js';

const U = {
  uDecay: { value: 0 }, uTime: { value: 0 }, uFar: { value: 0 }, uCenter: { value: new THREE.Vector3(12, 0, 4) },
  uVMin: { value: [] }, uVMax: { value: [] }, uVK: { value: [0, 0, 0, 0] }, uVSoft: { value: [1, 1, 1, 1] },
};
for (let i = 0; i < 4; i++) { U.uVMin.value.push(new THREE.Vector3(1e4, 1e4, 1e4)); U.uVMax.value.push(new THREE.Vector3(1e4, 1e4, 1e4)); }
export const DECAY = { target: 0, value: 0, U };

// places where it's always worse
export function decayVolume(i, min, max, k, soft = 1) { U.uVMin.value[i].copy(min); U.uVMax.value[i].copy(max); U.uVK.value[i] = k; U.uVSoft.value[i] = soft; }

const NOISE = `
  uniform float uDecay, uTime, uFar; uniform vec3 uCenter; uniform vec3 uVMin[4], uVMax[4]; uniform float uVK[4], uVSoft[4];
  varying vec3 vDW;
  float dh(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float dnoise(vec3 x){ vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(dh(i), dh(i + vec3(1,0,0)), f.x), mix(dh(i + vec3(0,1,0)), dh(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(dh(i + vec3(0,0,1)), dh(i + vec3(1,0,1)), f.x), mix(dh(i + vec3(0,1,1)), dh(i + vec3(1,1,1)), f.x), f.y), f.z); }
  float decayAt(vec3 w){
    float d = uDecay * 0.55;
    for (int i = 0; i < 4; i++) { vec3 q = clamp(w, uVMin[i], uVMax[i]); d += uVK[i] * (1.0 - smoothstep(0.0, uVSoft[i], length(w - q))); }
    d += uFar * smoothstep(45.0, 420.0, length(w.xz - uCenter.xz));
    return d;
  }`;
const FRAG = `
  {
    float dk = decayAt(vDW);
    if (dk > 0.02) {
      float n = dnoise(vDW * 1.1 + vec3(0.0, uTime * 0.015, uTime * 0.01)) * 0.65 + dnoise(vDW * 4.7) * 0.35;
      float gr = smoothstep(n - 0.15, n + 0.15, dk * 0.9);
      float lum = dot(diffuseColor.rgb, vec3(0.299, 0.587, 0.114));
      diffuseColor.rgb = mix(diffuseColor.rgb, vec3(lum * 0.45 + 0.2), gr);
      if (dk > 1.0 + n * 0.9) discard;
    }
  }`;

const patched = new WeakSet();
function patch(m) {
  if (!m || patched.has(m) || !(m.isMeshStandardMaterial || m.isMeshBasicMaterial)) return;
  patched.add(m);
  const prev = m.onBeforeCompile;
  m.onBeforeCompile = (sh, r) => {
    prev?.call(m, sh, r);
    Object.assign(sh.uniforms, U);
    sh.vertexShader = 'varying vec3 vDW;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
      vec4 dwp = vec4(transformed, 1.0);
      #ifdef USE_INSTANCING
        dwp = instanceMatrix * dwp;
      #endif
      vDW = (modelMatrix * dwp).xyz;`);
    sh.fragmentShader = NOISE + '\n' + sh.fragmentShader.replace('#include <color_fragment>', '#include <color_fragment>\n' + FRAG);
  };
  m.customProgramCacheKey = () => 'decay' + (m.isMeshBasicMaterial ? 'b' : 's');
  m.needsUpdate = true;
}
export function patchAll(root) {
  root.traverse((o) => { if (!o.material) return; (Array.isArray(o.material) ? o.material : [o.material]).forEach(patch); });
}

// ---------------------------------------------------------------- progression
G.decay = 0;
G.addDecay = (x) => { DECAY.target = Math.min(0.9, DECAY.target + x); };
const firsts = new Set();
// the first time you reach a place, it costs something
const COST = { stair4: 0.1, f48: 0.08, f51: 0.08, void: 0.12, f44: 0.06, stair0: 0.06, stair1: 0.04, street: 0.06, stair9: 0.05 };

let drone = null, hums = [];
export function initDecay() {
  // always worse: 51's broken edge, the far end of 44's corridor, the top of the stairs, the basement
  decayVolume(0, new THREE.Vector3(-1.5, 3.55, -3), new THREE.Vector3(10.8, 6.5, 0.4), 1.55, 0.7);
  decayVolume(1, new THREE.Vector3(40, -3.3, 1.5), new THREE.Vector3(82, -0.5, 6.2), 0.75, 16);
  decayVolume(2, new THREE.Vector3(10.3, 15.2, -0.5), new THREE.Vector3(14.5, 22, 8.5), 0.55, 3);
  decayVolume(3, new THREE.Vector3(10.3, -14, -0.5), new THREE.Vector3(14.5, -11.6, 8.5), 0.45, 1.5);
  const fogBase = G.scene.fog.density, fogCol = G.scene.fog.color.clone(), voidCol = new THREE.Color(0x3c3e42), bgCol = G.scene.background.clone();
  onUpdate((dt, t) => {
    // ease toward the target; it never goes back down
    DECAY.value += (DECAY.target - DECAY.value) * Math.min(1, dt * 0.25);
    const d = G.decay = DECAY.value;
    U.uDecay.value = d; U.uTime.value = t; U.uFar.value = d * 1.7;
    const zk = String(G.playerZone || '').split(':')[0];
    if (zk && COST[zk] !== undefined && !firsts.has(zk)) { firsts.add(zk); G.addDecay(COST[zk]); }
    // fog: in the void, close and black; elsewhere it thickens as things go
    const inVoid = zk === 'void' || zk === 'f51';
    const fd = zk === 'void' ? 0.032 : zk === 'f51' ? 0.018 : fogBase * (1 + d * 3);
    if (G.skyMesh) G.skyMesh.visible = !inVoid;
    G.scene.background.lerp(inVoid ? voidCol : bgCol, Math.min(1, dt * 1.5));
    G.scene.fog.density += (fd - G.scene.fog.density) * Math.min(1, dt * 1.5);
    G.scene.fog.color.lerp(inVoid ? voidCol : fogCol.clone().lerp(new THREE.Color(0x8a8a88), d * 0.6), Math.min(1, dt * 1.5));
    if (G.skyMat) G.skyMat.uniforms.decay.value = d;
    if (G.post) { G.post.uniforms.decay.value = d; G.post.uniforms.tear.value = Math.random() < dt * (0.05 + d * 0.8) ? Math.random() : G.post.uniforms.tear.value * 0.8; }
    // sound: a drone under everything, louder as it goes; each odd place has its own hum
    if (AUDIO.ready) {
      if (!drone) { drone = loopSource('hum', null, { vol: 0 }); drone.nodes[0].frequency.value = 41; drone.nodes[1].frequency.value = 61.7; hums = (G.zoneHums || []).map((h) => ({ ...h, s: loopSource('hum', h.pos, { vol: 0, ref: 3, rolloff: 0.8 }) })); }
      drone.set(d * d * 0.12 + (inVoid ? 0.05 : 0), 0.5);
      for (const h of hums) h.s?.set(zk === h.key ? 0.05 : 0, 0.4);
      // and now and then, a sound from the flat downstairs that the flat downstairs can't be making
      if (Math.random() < dt * d * 0.02) sfx(['tvOn', 'knock', 'drag', 'click'][(Math.random() * 4) | 0], new THREE.Vector3(G.playerPos.x + (Math.random() - 0.5) * 6, G.playerPos.y + (Math.random() < 0.5 ? -2.4 : 3), G.playerPos.z + (Math.random() - 0.5) * 6), { vol: 0.6, rate: 0.6 + Math.random() * 0.3 });
    }
  });
  // lights dim with it, unevenly
  G.decayLight = (f) => 1 - G.decay * 0.35 * (0.5 + 0.5 * Math.sin(f.t * 0.37 + f.pos.x));
}
