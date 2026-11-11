// Dust in the air: invisible until light catches it — in a beam from a window, through the
// slats of a boarded window, or in the torch.
import * as THREE from 'three';
import { G, onUpdate } from './core.js';
import { ROOMS } from './plan.js';

export const DUST = { shafts: [] };

export function buildDust() {
  const per = { living: 1400, bedroom: 700, kitchen: 600, hall: 500, child: 700, bath: 500, storage: 400 };
  const pos = [], seed = [];
  for (const [k, n] of Object.entries(per)) {
    const r = ROOMS[k];
    for (let i = 0; i < n; i++) { pos.push(r.x0 + Math.random() * (r.x1 - r.x0), 0.1 + Math.random() * 2.55, r.z0 + Math.random() * (r.z1 - r.z0)); seed.push(Math.random()); }
  }
  for (let i = 0; i < 500; i++) { pos.push(0.6 + Math.random() * 3.3, Math.random() * 2.4, -1.7 + Math.random() * 1.3); seed.push(Math.random()); }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('seed', new THREE.Float32BufferAttribute(seed, 1));
  const shafts = DUST.shafts;
  const u = {
    time: { value: 0 }, torchPos: { value: new THREE.Vector3() }, torchDir: { value: new THREE.Vector3(0, 0, -1) }, torchOn: { value: 0 },
    shaftMin: { value: Array.from({ length: 6 }, () => new THREE.Vector3(1e3, 1e3, 1e3)) }, shaftMax: { value: Array.from({ length: 6 }, () => new THREE.Vector3(1e3, 1e3, 1e3)) },
    shaftCol: { value: Array.from({ length: 6 }, () => new THREE.Vector3()) }, px: { value: G.renderer.getPixelRatio() },
  };
  const m = new THREE.ShaderMaterial({
    uniforms: u, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: `
      attribute float seed; uniform float time, torchOn, px; uniform vec3 torchPos, torchDir;
      uniform vec3 shaftMin[6], shaftMax[6], shaftCol[6];
      varying vec3 vCol; varying float vA;
      void main(){
        vec3 p = position;
        float t = time * (0.03 + seed * 0.04);
        p += vec3(sin(t * 3.1 + seed * 40.) * 0.25, sin(t * 2.3 + seed * 17.) * 0.12 - fract(t * 0.05 + seed) * 0.0, cos(t * 2.7 + seed * 23.) * 0.25);
        vec3 col = vec3(0.0);
        // the torch beam
        vec3 d = p - torchPos; float dl = length(d);
        float cone = smoothstep(0.92, 0.985, dot(d / max(dl, 1e-3), torchDir));
        col += vec3(1.0, 0.92, 0.78) * cone * torchOn * smoothstep(7.0, 0.4, dl) * 0.9;
        for (int i = 0; i < 6; i++) {
          vec3 q = step(shaftMin[i], p) * step(p, shaftMax[i]);
          col += shaftCol[i] * q.x * q.y * q.z;
        }
        vCol = col; vA = 0.35 + seed * 0.5;
        vec4 mv = modelViewMatrix * vec4(p, 1.0);
        gl_PointSize = (1.2 + seed * 2.2) * px * (2.2 / -mv.z);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: `
      varying vec3 vCol; varying float vA;
      void main(){ vec2 c = gl_PointCoord - 0.5; float a = smoothstep(0.5, 0.0, length(c)); gl_FragColor = vec4(vCol * a * vA * 0.5, 1.0); }`,
  });
  const pts = new THREE.Points(g, m); pts.frustumCulled = false; pts.renderOrder = 5;
  G.scene.add(pts);
  onUpdate((dt, t) => {
    u.time.value = t;
    const T = G.torch;
    if (T) { u.torchOn.value = T.on ? 1 : 0; G.camera.getWorldPosition(u.torchPos.value); G.camera.getWorldDirection(u.torchDir.value); }
    shafts.forEach((s, i) => { if (i < 6) { u.shaftMin.value[i].copy(s.min); u.shaftMax.value[i].copy(s.max); u.shaftCol.value[i].copy(s.col).multiplyScalar(s.k ? s.k() : 1); } });
  });
}
