// Outside: the courtyard four floors down, the blocks around it, the city beyond going
// on into the haze, Plant No. 3's three chimneys on the skyline. And the stair landing
// on the other side of the front door. None of it is walkable; all of it has depth.
import * as THREE from 'three';
import { G, mat, box, cyl, group, solidMat, sphere, onUpdate, interactive } from './core.js';
import { Surface, rng, noiseCanvas, metalTex, woodTex, blobPath, underPlaster } from './textures.js';
import { GROUND, STOREY, EXT, LANDING } from './plan.js';
import { addLight } from './lighting.js';
import { M, lathe } from './furniture.js';
import { DOORS } from './openings.js';
import { sfx } from './audio.js';

const V = (x, y, z) => new THREE.Vector3(x, y, z);
const Gy = GROUND;

// ---------------------------------------------------------------- facade textures (one storey x N bays, tiled)
function facadeTex(kind, seed, bays = 6, storeys = 5) {
  const bw = kind === 'panel' ? 3.0 : 3.4, sh = kind === 'panel' ? 2.8 : 3.3;
  const W = bays * bw, Hh = storeys * sh;
  const s = new Surface(W, Hh, 18, seed), g = s.g, r = s.r;
  const em = document.createElement('canvas'); em.width = s.W; em.height = s.H; const eg = em.getContext('2d');
  if (kind === 'panel') { s.fill('#8c8a82').noise(0.3, 2, 'multiply', 10, seed).grain(0.06); }
  else if (kind === 'brick') { s.fill('#7a4a36').noise(0.35, 1.5, 'multiply', 8, seed); for (let y = 0; y < s.H; y += 2) { g.fillStyle = 'rgba(40,20,10,0.15)'; g.fillRect(0, y, s.W, 1); } s.grain(0.1); }
  else { s.fill('#a0927a').noise(0.35, 2.5, 'multiply', 10, seed).grain(0.08); for (let i = 0; i < 18; i++) s.peel(r() * W, r() * Hh, 1 + r() * 2, 0.5 + r(), underPlaster('#6a4030'), false); }
  for (let f = 0; f < storeys; f++) {
    const y0 = f * sh;
    if (kind === 'panel') { g.fillStyle = 'rgba(40,38,34,0.6)'; g.fillRect(0, s.Y(y0), s.W, 2); for (let b = 0; b <= bays; b++) g.fillRect(s.px(b * bw), s.Y(y0 + sh), 2, s.px(sh)); }
    for (let b = 0; b < bays; b++) {
      const wx = b * bw + (bw - 1.4) / 2, wy = y0 + 0.9, ww = 1.4, wh = 1.45;
      const k = r();
      const lit = k < 0.035, boarded = k > 0.9, broken = k > 0.8 && !boarded, curtain = r() < 0.35;
      g.fillStyle = boarded ? '#4a3a28' : broken ? '#060606' : '#161a1e'; g.fillRect(s.px(wx), s.Y(wy + wh), s.px(ww), s.px(wh));
      if (!boarded && !broken) {
        const grd = g.createLinearGradient(0, s.Y(wy + wh), 0, s.Y(wy)); grd.addColorStop(0, 'rgba(120,130,145,0.35)'); grd.addColorStop(1, 'rgba(60,70,80,0.08)');
        g.fillStyle = grd; g.fillRect(s.px(wx), s.Y(wy + wh), s.px(ww), s.px(wh));
        if (curtain) { g.fillStyle = `rgba(${120 + r() * 60},${100 + r() * 40},${70},0.45)`; g.fillRect(s.px(wx + (r() < 0.5 ? 0 : ww * 0.55)), s.Y(wy + wh), s.px(ww * 0.45), s.px(wh)); }
        g.fillStyle = '#c8c2b0'; g.fillRect(s.px(wx + ww / 2) - 1, s.Y(wy + wh), 2, s.px(wh));
      }
      if (boarded) for (let p = 0; p < 4; p++) { g.fillStyle = `rgb(${90 + r() * 30},${70 + r() * 20},48)`; g.fillRect(s.px(wx) - 1, s.Y(wy + wh) + p * s.px(0.38) + 2, s.px(ww) + 2, s.px(0.2)); }
      if (lit) { eg.fillStyle = r() < 0.5 ? '#ffb860' : '#c8d8ff'; eg.globalAlpha = 0.55 + r() * 0.4; eg.fillRect(s.px(wx) + 1, s.Y(wy + wh) + 1, s.px(ww) - 2, s.px(wh) - 2); eg.globalAlpha = 1; }
      // streak of grime beneath
      const gs = g.createLinearGradient(0, s.Y(wy), 0, s.Y(wy - 1.2)); gs.addColorStop(0, 'rgba(25,20,15,0.4)'); gs.addColorStop(1, 'rgba(25,20,15,0)');
      g.fillStyle = gs; g.fillRect(s.px(wx), s.Y(wy), s.px(ww), s.px(1.2));
      if (kind === 'panel' && r() < 0.5) { g.fillStyle = 'rgba(60,58,52,0.9)'; g.fillRect(s.px(wx - 0.3), s.Y(wy - 0.05), s.px(ww + 0.6), s.px(0.12)); } // balcony slab edge
    }
  }
  // soot, rust streaks, a big tag low down
  for (let i = 0; i < 12; i++) { const x = r() * s.W, l = s.H * (0.2 + r() * 0.5); const gr = g.createLinearGradient(0, 0, 0, l); gr.addColorStop(0, 'rgba(70,40,20,0.3)'); gr.addColorStop(1, 'rgba(70,40,20,0)'); g.fillStyle = gr; g.fillRect(x, r() * s.H * 0.5, 2 + r() * 4, l); }
  s.rising(sh, [20, 18, 15], 0.4);
  eg.save(); eg.globalCompositeOperation = 'destination-over'; eg.globalAlpha = 0.3; eg.drawImage(s.c, 0, 0); eg.globalAlpha = 1; eg.fillStyle = '#000'; eg.fillRect(0, 0, em.width, em.height); eg.restore();
  const t = s.textures({ repeat: true });
  const et = new THREE.CanvasTexture(em); et.colorSpace = THREE.SRGBColorSpace; et.wrapS = et.wrapT = THREE.RepeatWrapping;
  return { map: t.map, emissiveMap: et, W, Hh };
}

// a building as a box with the facade texture tiled at true scale on its walls, roof dark
function building(x, z, w, d, h, ry, tex, o = {}) {
  const g = new THREE.BoxGeometry(w, h, d);
  const uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let i = 0; i < 4; i++) { const k = f * 4 + i; uv.setXY(k, uv.getX(k) * dims[f][0] / tex.W, uv.getY(k) * dims[f][1] / tex.Hh); }
  const wall = o.wallMat || new THREE.MeshStandardMaterial({ map: tex.map, emissiveMap: tex.emissiveMap, emissive: 0xffffff, emissiveIntensity: o.lit ?? 1.2, roughness: 0.95 });
  const roof = solidMat('roofTar', 0x2a2826, 0.95);
  const m = new THREE.Mesh(g, [wall, wall, roof, roof, wall, wall]);
  m.position.set(x, Gy + h / 2, z); m.rotation.y = ry; m.castShadow = !!o.cast; m.receiveShadow = !!o.recv;
  G.scene.add(m);
  return m;
}

// ---------------------------------------------------------------- sky
function sky() {
  const geo = new THREE.SphereGeometry(1200, 32, 16);
  const m = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { time: { value: 0 }, noise: { value: new THREE.CanvasTexture(noiseCanvas(256, 8, 5, 404)) } },
    vertexShader: 'varying vec3 vD; void main(){ vD = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.); }',
    fragmentShader: `
      uniform float time; uniform sampler2D noise; varying vec3 vD;
      void main(){
        float h = vD.y;
        // late overcast dusk: a band of dirty amber at the horizon (the last of the light + the city's own glow), slate above
        vec3 hor = vec3(0.30, 0.24, 0.20), mid = vec3(0.115, 0.125, 0.15), top = vec3(0.04, 0.05, 0.065);
        vec3 c = mix(hor, mid, smoothstep(-0.02, 0.18, h)); c = mix(c, top, smoothstep(0.18, 0.7, h));
        // brighter toward the west where the sun went down
        float west = pow(max(0., dot(normalize(vec3(vD.x, 0., vD.z)), normalize(vec3(-0.7, 0., -0.7)))), 3.);
        c += vec3(0.16, 0.08, 0.035) * west * smoothstep(0.25, 0.0, h);
        // cloud deck: low, heavy, slowly moving
        vec2 uv = vD.xz / max(0.08, h + 0.12) * 0.35 + vec2(time * 0.002, time * 0.0008);
        float n = texture2D(noise, uv).r * 0.6 + texture2D(noise, uv * 2.3).r * 0.4;
        float cl = smoothstep(0.35, 0.8, n);
        c = mix(c, c * 0.62 + vec3(0.02, 0.018, 0.016), cl * smoothstep(0.0, 0.15, h));
        c = mix(c, vec3(0.08, 0.075, 0.075), smoothstep(0.0, -0.08, h));
        gl_FragColor = vec4(c, 1.);
      }`,
  });
  m.uniforms.noise.value.wrapS = m.uniforms.noise.value.wrapT = THREE.RepeatWrapping;
  const s = new THREE.Mesh(geo, m); s.renderOrder = -10; s.frustumCulled = false;
  G.scene.add(s);
  onUpdate((dt, t) => { m.uniforms.time.value = t; s.position.copy(G.camera.position); });
}

// ---------------------------------------------------------------- ground
function ground() {
  const s = new Surface(120, 80, 6, 501).fill('#3a3834').noise(0.5, 3, 'multiply', 12, 2).noise(0.3, 1, 'overlay', 5, 3).grain(0.1);
  const g = s.g, r = s.r;
  // grass and mud patches, potholes, puddles reflecting the sky
  for (let i = 0; i < 40; i++) { g.fillStyle = `rgba(${50 + r() * 20},${55 + r() * 20},${35},${0.4 + r() * 0.3})`; g.fill(blobPath(r() * s.W, r() * s.H, 10 + r() * 40, 8 + r() * 25, r)); }
  for (let i = 0; i < 30; i++) { g.fillStyle = 'rgba(20,20,22,0.6)'; g.fill(blobPath(r() * s.W, r() * s.H, 3 + r() * 10, 2 + r() * 6, r)); }
  for (let i = 0; i < 30; i++) s.crack(r() * 120, r() * 80, 3 + r() * 8, r() * 6, 2, 1.5);
  // the road along the north edge and the path from our door
  g.fillStyle = 'rgba(30,30,32,0.6)'; g.fillRect(0, s.px(10), s.W, s.px(9));
  g.fillStyle = 'rgba(200,190,150,0.25)'; for (let x = 0; x < s.W; x += 30) g.fillRect(x, s.px(14.4), 14, 2);
  s.rough(0.9);
  for (let i = 0; i < 14; i++) { const p = blobPath(r() * s.W, r() * s.H, 6 + r() * 20, 4 + r() * 10, r); s.rg.fillStyle = '#101010'; s.rg.fill(p); g.fillStyle = 'rgba(25,28,32,0.7)'; g.fill(p); }
  const t = s.textures();
  const m = new THREE.Mesh(new THREE.PlaneGeometry(120, 80), new THREE.MeshStandardMaterial({ map: t.map, roughnessMap: t.roughnessMap, roughness: 1, metalness: 0.2 }));
  m.rotation.x = -Math.PI / 2; m.position.set(5, Gy, -40); m.receiveShadow = true; G.scene.add(m);
  // beyond: a big dark plane to the horizon
  const far = new THREE.Mesh(new THREE.PlaneGeometry(3000, 3000), solidMat('farGround', 0x1c1b1a, 1)); far.rotation.x = -Math.PI / 2; far.position.set(0, Gy - 0.05, 0); G.scene.add(far);
}

// ---------------------------------------------------------------- props in the courtyard
function car(x, z, ry, o = {}) {
  const g = group({ x, y: Gy, z, ry });
  const paint = o.burnt ? mat('burnt', { color: 0x1e1a16, roughness: 0.9, metalness: 0.3, map: metalTex('#3a2a20', 2, 600).map }) : mat('carPaint' + (o.col || 0), { color: o.col || 0x6a7a5a, roughness: 0.45, metalness: 0.4, map: metalTex('#9a9a90', 0.6, 601 + (o.col || 0) % 7).map });
  box(4.1, 0.65, 1.62, paint, { y: 0.32, base: true, parent: g });
  box(2.2, 0.55, 1.5, paint, { x: -0.15, y: 0.95, base: true, parent: g });
  const glass = o.burnt ? solidMat('burntGlass', 0x0a0a0a, 1) : mat('carGlass', { color: 0x1a2228, roughness: 0.1, metalness: 0.6 });
  box(2.1, 0.45, 1.52, glass, { x: -0.15, y: 1.0, base: true, parent: g, cast: false });
  for (const sx of [-1.3, 1.3]) for (const sz of [-0.75, 0.75]) cyl(0.3, 0.3, 0.2, 12, o.flat ? solidMat('rim', 0x2a2420, 0.8) : solidMat('tyre', 0x141414, 0.9), { x: sx, y: o.flat && sx > 0 ? 0.18 : 0.3, z: sz, rx: Math.PI / 2, parent: g });
  if (!o.burnt) { box(0.05, 0.12, 0.25, mat('headlamp', { color: 0x8a8a80, roughness: 0.2, metalness: 0.8 }), { x: 2.06, y: 0.55, z: 0.55, parent: g }); box(0.05, 0.12, 0.25, mat('headlamp', {}), { x: 2.06, y: 0.55, z: -0.55, parent: g }); }
  if (o.door) { const d = box(1.0, 0.6, 0.05, paint, { x: -0.1, y: 0.6, base: true, z: 0.95, ry: -0.9, parent: g }); d.position.x = 0.35; d.position.z = 1.2; }
  return g;
}
function tree(x, z, h, seed) {
  const r = rng(seed), bark = mat('bark', { color: 0x2a2420, roughness: 1 });
  const parts = [];
  const branch = (p, dir, len, rad, depth) => {
    const end = p.clone().addScaledVector(dir, len);
    const m = cyl(rad * 0.7, rad, len, 5, bark, {}); m.position.copy(p).add(end).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(V(0, 1, 0), dir.clone().normalize()); parts.push(m);
    if (depth <= 0 || rad < 0.015) return;
    const n = depth > 2 ? 2 : 3;
    for (let i = 0; i < n; i++) { const d = dir.clone().add(V((r() - 0.5) * 1.4, r() * 0.5, (r() - 0.5) * 1.4)).normalize(); branch(end, d, len * (0.65 + r() * 0.2), rad * 0.62, depth - 1); }
  };
  branch(V(x, Gy, z), V(0, 1, 0), h * 0.35, 0.18, 5);
}
function streetlamp(x, z, ry, state) {
  const g = group({ x, y: Gy, z, ry });
  const pole = mat('lampPole', { color: 0x3a3e3a, roughness: 0.7, metalness: 0.5 });
  cyl(0.07, 0.1, 8, 8, pole, { y: 4, parent: g });
  box(1.6, 0.06, 0.06, pole, { x: 0.8, y: 7.9, parent: g });
  const headM = mat('lampHead' + state, { color: 0x2a2a26, emissive: 0xff9a3a, emissiveIntensity: 0, roughness: 0.5 });
  const head = box(0.5, 0.12, 0.24, headM, { x: 1.55, y: 7.82, parent: g, static: false });
  if (state === 'dead') return;
  // the glow: a soft billboard, no expensive light (bar one)
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: 0xffa04a, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0.8 }));
  sp.scale.set(3, 3, 1); g.add(sp); sp.position.set(1.55, 7.7, 0);
  // pool of light on the ground
  const pool = new THREE.Mesh(new THREE.CircleGeometry(7, 24), new THREE.MeshBasicMaterial({ map: glowTex(), color: 0xff9a40, transparent: true, opacity: 0.22, depthWrite: false, blending: THREE.AdditiveBlending }));
  pool.rotation.x = -Math.PI / 2; pool.position.set(1.55, 0.05, 0); g.add(pool);
  const L = { k: 1, t: Math.random() * 10 };
  onUpdate((dt) => {
    L.t += dt;
    let k = 1;
    if (state === 'flicker') { k = Math.sin(L.t * 3) > 0.6 ? (Math.random() < 0.5 ? 0.1 : 1) : 1; if ((L.t % 9) < 2.5) k = Math.random() < 0.3 ? 1 : 0; }
    headM.emissiveIntensity = 3 * k; sp.material.opacity = 0.8 * k; pool.material.opacity = 0.22 * k;
  });
}
let _glow;
function glowTex() {
  if (_glow) return _glow;
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,0.45)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 128, 128); _glow = new THREE.CanvasTexture(c); return _glow;
}
// wires sagging between points
function wire(a, b, sag, m) {
  const pts = []; for (let i = 0; i <= 16; i++) { const t = i / 16; const p = a.clone().lerp(b, t); p.y -= Math.sin(t * Math.PI) * sag; pts.push(p); }
  const w = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 24, 0.015, 3), m); G.scene.add(w); w.userData.static = true;
}
function pole(x, z, h = 10) {
  const wood = mat('poleWood', { map: woodTex('#3a2e22', 610, 0.8).map, roughness: 1 });
  cyl(0.12, 0.15, h, 7, wood, { x, y: Gy + h / 2, z });
  box(1.8, 0.1, 0.1, wood, { x, y: Gy + h - 0.5, z });
  box(1.2, 0.1, 0.1, wood, { x, y: Gy + h - 1.2, z });
  for (const dx of [-0.8, -0.3, 0.3, 0.8]) cyl(0.03, 0.04, 0.12, 6, mat('insulator', { color: 0x6a7a6a, roughness: 0.3 }), { x: x + dx, y: Gy + h - 0.38, z });
  box(0.5, 0.6, 0.4, mat('transformer', { color: 0x4a5048, roughness: 0.7, metalness: 0.4 }), { x: x + 0.3, y: Gy + h - 2.5, z });
  return [-0.8, -0.3, 0.3, 0.8].map((dx) => V(x + dx, Gy + h - 0.32, z));
}

// ---------------------------------------------------------------- the courtyard
function courtyard() {
  const r = rng(700);
  const panel = facadeTex('panel', 710, 8, 4), brick = facadeTex('brick', 711, 5, 4), stucco = facadeTex('stucco', 712, 6, 4);
  // across the yard: a long nine-storey panel block, its windows mostly dark
  building(5, -44, 96, 13, 9 * 2.8 + 0.6, 0, panel, { cast: false, recv: true });
  // near balconies on its face, for depth
  const balM = mat('farBal', { color: 0x4a4844, roughness: 0.9 });
  const bals = new THREE.InstancedMesh(new THREE.BoxGeometry(2.6, 1.0, 1.1), balM, 200); let n = 0; const mm = new THREE.Matrix4();
  for (let f = 1; f < 9; f++) for (let b = -15; b <= 15; b++) { if (r() < 0.45 || n >= 200) continue; mm.makeTranslation(5 + b * 3.0 + 1.5, Gy + f * 2.8 + 0.5, -44 + 6.5 + 0.55); bals.setMatrixAt(n++, mm); }
  bals.count = n; G.scene.add(bals);
  // the west side: an older stucco block, five storeys, pitched roof
  building(-34, -18, 13, 30, 5 * 3.3, Math.PI / 2 * 0, stucco, { cast: false });
  roofPitch(-34, -18, 13, 30, 5 * 3.3, 4);
  // the east side: brick, six storeys, with a steel fire escape down its courtyard face
  building(44, -20, 14, 34, 6 * 3.3, 0, brick, { cast: false });
  fireEscape(37, -20, 6);
  // the courtyard floor: cars, a burnt-out one, the army lorry that came for them, garages
  car(-6, -14, 0.1, { col: 0x5a6a7a }); car(-1, -15.5, -0.05, { burnt: true, flat: true }); car(12, -13, Math.PI + 0.1, { col: 0x8a7a5a, door: true }); car(18, -24, 1.6, { col: 0x4a5a4a, flat: true }); car(-14, -28, 0.4, { col: 0x7a3a2a });
  armyTruck(24, -16, -0.4);
  // a row of lock-up garages along the far side
  const garM = mat('garage', { map: metalTex('#5a5a50', 1.5, 720).map, roughness: 0.8, metalness: 0.4 });
  for (let i = 0; i < 9; i++) { box(3.2, 2.4, 6, garM, { x: -20 + i * 3.3, y: Gy, base: true, z: -35 }); const d = box(2.6, 2.0, 0.05, i === 3 ? solidMat('garDark', 0x080808, 1) : garM, { x: -20 + i * 3.3, y: Gy, base: true, z: -31.98 }); if (i === 6) d.rotation.x = -1.2, d.position.y = Gy + 2.0; }
  // playground: swing frame with one seat left, a slide, a sandpit
  const play = mat('playMetal', { map: metalTex('#7a5a3a', 1.8, 721).map, roughness: 0.7, metalness: 0.4 });
  for (const s of [-1, 1]) { const l = cyl(0.04, 0.04, 2.8, 6, play, { x: 4 + s * 1.2, y: Gy + 1.3, z: -24 }); l.rotation.z = s * 0.2; }
  cyl(0.04, 0.04, 2.6, 6, play, { x: 4, y: Gy + 2.6, z: -24, rz: Math.PI / 2 });
  const swing = group({ x: 4.3, y: Gy + 2.6, z: -24 });
  for (const s of [-0.22, 0.22]) cyl(0.006, 0.006, 1.9, 3, play, { y: -0.95, z: s, parent: swing, static: false });
  box(0.3, 0.04, 0.5, mat('swingSeat', { color: 0x6a3a2a, roughness: 0.9 }), { y: -1.9, parent: swing, static: false });
  onUpdate((dt, t) => { swing.rotation.z = Math.sin(t * 1.4) * 0.12 * (0.5 + 0.5 * Math.sin(t * 0.13)); }); // it moves in the wind. it's the wind
  box(0.5, 1.6, 3.5, play, { x: 9, y: Gy, base: true, z: -26, rx: 0.4 });
  box(3, 0.2, 3, mat('sandpit', { color: 0x5a4a38, roughness: 1 }), { x: 0, y: Gy, base: true, z: -27 });
  // benches, bins, the kiosk shuttered
  for (const [x, z, ry] of [[-3, -20, 0], [7, -20, 0.1]]) { const b = group({ x, y: Gy, z, ry }); box(1.8, 0.05, 0.4, M.pine, { y: 0.45, parent: b }); box(1.8, 0.3, 0.04, M.pine, { y: 0.7, z: -0.2, parent: b }); for (const s of [-0.8, 0.8]) box(0.05, 0.45, 0.4, M.iron, { x: s, y: 0.22, parent: b }); }
  const kiosk = group({ x: -12, y: Gy, z: -9, ry: 0.2 }); box(2.6, 2.5, 2.0, mat('kiosk', { map: metalTex('#4a6a7a', 1.4, 722).map, roughness: 0.7, metalness: 0.3 }), { y: 1.25, parent: kiosk }); box(2.2, 1.0, 0.05, garM, { y: 1.4, z: 1.02, parent: kiosk });
  box(1.8, 0.4, 0.05, mat('kioskSign', { color: 0x8a2a1a, roughness: 0.6 }), { y: 2.7, z: 0.9, parent: kiosk });
  for (const [x, z] of [[-8, -7], [16, -6], [20, -30]]) { box(1.8, 1.3, 1.1, mat('skip', { color: 0x3a4a3a, roughness: 0.8, metalness: 0.4, map: metalTex('#3a4a3a', 1.6, 723).map }), { x, y: Gy, base: true, z }); for (let i = 0; i < 5; i++) box(0.4 + r() * 0.5, 0.3 + r() * 0.3, 0.4, mat('binBag', { color: 0x141414, roughness: 0.3 }), { x: x + (r() - 0.5) * 2.5, y: Gy, base: true, z: z + 0.9 + r() * 0.8, ry: r() * 3 }); }
  // concrete blocks and a barrier: a checkpoint, abandoned
  for (let i = 0; i < 4; i++) box(1.2, 0.8, 0.6, solidMat('concBlock', 0x7a7870, 0.95), { x: 28 + i * 1.6, y: Gy, base: true, z: -6, ry: (r() - 0.5) * 0.2 });
  box(5, 0.08, 0.08, mat('barrier', { color: 0xc8c0a0, roughness: 0.6 }), { x: 30, y: Gy + 1.0, z: -5.5, rz: 0.08 });
  // bare trees, poplars and birch
  for (const [x, z, h] of [[-8, -22, 11], [14, -27, 12], [-18, -14, 9], [26, -30, 13], [1, -9, 8], [-24, -31, 10]]) tree(x, z, h, (x * 31 + z * 7) | 0);
  // streetlights: one works, one flickers, the rest are dead
  streetlamp(-2, -10, Math.PI / 2, 'on'); streetlamp(14, -10, Math.PI / 2, 'dead'); streetlamp(28, -12, Math.PI / 2, 'flicker'); streetlamp(-16, -10, Math.PI / 2, 'dead');
  // a real light for the one that works, to put a pool on the cars
  const sl = new THREE.PointLight(0xff9a40, 60, 26, 1.8); sl.position.set(-2, Gy + 7.5, -11.5); G.scene.add(sl);
  // telegraph poles and the wires sagging across the yard to our building
  const wm = solidMat('wire', 0x0c0c0c, 0.6);
  const a = pole(-10, -11), b = pole(10, -11.5), c = pole(30, -11);
  for (let i = 0; i < 4; i++) { wire(a[i], b[i], 0.5, wm); wire(b[i], c[i], 0.6, wm); }
  wire(b[1], V(6, 5.5, -EXT - 0.05), 1.2, wm); wire(b[2], V(6.4, 5.4, -EXT - 0.05), 1.3, wm);
  wire(V(-24, 12, -0.5), V(-27.5, 10, -10), 1, wm);
}
function roofPitch(x, z, w, d, h, rh) {
  const shape = new THREE.Shape(); shape.moveTo(-w / 2, 0); shape.lineTo(w / 2, 0); shape.lineTo(0, rh); shape.closePath();
  const geo = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: false });
  const m = new THREE.Mesh(geo, mat('roofTin', { map: metalTex('#4a3a30', 1.8, 730).map, roughness: 0.8, metalness: 0.4 }));
  m.position.set(x, Gy + h, z - d / 2); G.scene.add(m);
  for (let i = 0; i < 4; i++) box(0.6, 1.4, 0.6, solidMat('chimneyBrick', 0x5a3a2a, 1), { x: x + (i % 2 ? 2 : -2), y: Gy + h + rh * 0.5, base: true, z: z - d / 2 + 4 + i * 7 });
  // TV aerials, bent
  for (let i = 0; i < 5; i++) { const g = group({ x: x + (Math.random() - 0.5) * 3, y: Gy + h + rh * 0.8, z: z - d / 2 + 3 + i * 6 }); cyl(0.02, 0.02, 2.2, 4, M.iron, { y: 1.1, parent: g }); for (let k = 0; k < 4; k++) box(0.8 - k * 0.15, 0.02, 0.02, M.iron, { y: 1.5 + k * 0.2, ry: 0.3, parent: g }); g.rotation.z = (Math.random() - 0.5) * 0.4; }
}
function fireEscape(x, z, floors) {
  const st = mat('fireEsc', { map: metalTex('#2a2a26', 1.6, 740).map, roughness: 0.7, metalness: 0.6 });
  for (let f = 1; f < floors; f++) {
    const y = Gy + f * 3.3;
    box(1.2, 0.06, 4, st, { x: x - 0.6, y, z });
    for (let k = 0; k < 9; k++) box(0.02, 0.9, 0.02, st, { x: x - 1.2, y: y + 0.45, z: z - 2 + k * 0.5 });
    box(0.03, 0.03, 4, st, { x: x - 1.2, y: y + 0.9, z });
    // stair down to the next landing
    const s = box(0.9, 0.05, 4.2, st, { x: x - 0.6, y: y - 1.65, z: z + (f % 2 ? 1 : -1) * 0.2 }); s.rotation.x = (f % 2 ? 1 : -1) * 0.65;
  }
  // the bottom ladder pulled up, and one landing door open, black
  box(0.05, 2.0, 0.9, solidMat('feDoor', 0x050505, 1), { x: x - 0.01, y: Gy + 3 * 3.3, base: true, z: z + 1 });
}
function armyTruck(x, z, ry) {
  const g = group({ x, y: Gy, z, ry });
  const olive = mat('olive', { color: 0x3a4232, roughness: 0.85, metalness: 0.2, map: metalTex('#4a523e', 0.9, 750).map });
  box(2.2, 1.6, 2.2, olive, { x: 3.0, y: 0.9, base: true, parent: g });
  box(4.6, 0.5, 2.4, olive, { x: -0.6, y: 0.9, base: true, parent: g });
  // canvas tilt over the back, sagging, the back flap tied open
  const tilt = new THREE.Mesh(new THREE.CylinderGeometry(1.25, 1.25, 4.6, 12, 1, true, 0, Math.PI), mat('tilt', { color: 0x4a4a38, roughness: 1, side: THREE.DoubleSide, map: woodTex('#4a4a38', 751, 1).map }));
  tilt.rotation.z = Math.PI / 2; tilt.position.set(-0.6, 1.4, 0); tilt.scale.set(1, 1, 0.95); g.add(tilt);
  for (const sx of [-2.2, -0.6, 3.0]) for (const sz of [-1.05, 1.05]) cyl(0.5, 0.5, 0.35, 12, solidMat('tyre', 0x141414, 0.9), { x: sx, y: 0.5, z: sz, rx: Math.PI / 2, parent: g });
  box(0.05, 0.3, 0.05, M.iron, { x: -2.9, y: 1.4, z: 0, parent: g });
  // a white sheet of paper flapping on the windscreen? a list. Too far to read.
}

// ---------------------------------------------------------------- the city beyond
function city() {
  const r = rng(800);
  const texs = [facadeTex('panel', 810, 6, 6), facadeTex('panel', 811, 6, 6), facadeTex('stucco', 812, 6, 5), facadeTex('brick', 813, 6, 5)];
  const ring = [];
  for (let i = 0; i < 90; i++) {
    const a = -Math.PI * 0.95 + r() * Math.PI * 1.9 + Math.PI; // mostly in front (north) and to the sides
    const d = 90 + r() * 420;
    const x = 5 + Math.sin(a) * d, z = -40 + Math.cos(a) * d * 0.9;
    if (z > -40 && Math.abs(x) < 80) continue;
    const tall = r() < 0.3;
    const w = 14 + r() * 50, dd = 12 + r() * 14, h = tall ? 30 + r() * 30 : 12 + r() * 16;
    ring.push(building(x, z, w, dd, h, (r() - 0.5) * 0.6 + (r() < 0.3 ? Math.PI / 2 : 0), texs[(r() * texs.length) | 0], { lit: 1.0 }));
  }
  // Plant No. 3: low sheds and three tall chimneys on the skyline, the middle one with a red light
  const plantX = -170, plantZ = -380;
  const brickM = solidMat('plantBrick', 0x3a2a24, 1);
  for (let i = 0; i < 5; i++) box(40 + r() * 30, 14 + r() * 10, 30, solidMat('shed', 0x2a2a28, 1), { x: plantX - 60 + i * 35, y: Gy, base: true, z: plantZ + (r() - 0.5) * 30 });
  for (let i = 0; i < 3; i++) {
    const cx = plantX - 30 + i * 30, h = 90 + (i === 1 ? 20 : 0);
    cyl(2.2, 3.6, h, 12, brickM, { x: cx, y: Gy, base: true, z: plantZ });
    for (let b = 1; b < 4; b++) cyl(2.6 - b * 0.15 + 0.2, 2.6 - b * 0.15 + 0.2, 1.2, 12, mat('chimBand', { color: b % 2 ? 0x8a2a1a : 0xc8c0b0, roughness: 0.9 }), { x: cx, y: Gy + h - b * 8, z: plantZ });
    if (i === 1) {
      const red = sphere(0.9, mat('aviation', { color: 0x300000, emissive: 0xff2010, emissiveIntensity: 0 }), { x: cx, y: Gy + h + 0.8, z: plantZ });
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: 0xff2a1a, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false })); sp.scale.set(14, 14, 1); sp.position.set(cx, Gy + h + 0.8, plantZ); G.scene.add(sp);
      onUpdate((dt, t) => { const on = (t % 2.2) < 0.9 ? 1 : 0; red.material.emissiveIntensity = on * 5; sp.material.opacity = on * 0.7; });
    }
    // smoke still going up from the left one. somebody is keeping it lit
    if (i === 0) smoke(cx, Gy + h, plantZ);
  }
  // a TV mast far to the east, and two tower cranes standing over a block that was never finished
  { const m = group({ x: 420, y: Gy, z: -520 }); for (let k = 0; k < 4; k++) { const l = cyl(0.6, 0.6, 180, 4, M.iron, { x: Math.cos(k * 1.57) * 6, y: 90, z: Math.sin(k * 1.57) * 6, parent: m }); l.rotation.z = Math.cos(k * 1.57) * 0.03; l.rotation.x = Math.sin(k * 1.57) * 0.03; } box(1, 30, 1, M.iron, { y: 195, parent: m }); }
  for (const [x, z, ry] of [[120, -240, 0.5], [160, -260, -0.6]]) { const c = group({ x, y: Gy, z, ry }); box(2, 60, 2, mat('crane', { color: 0x6a5a2a, roughness: 0.8, metalness: 0.3 }), { y: 30, parent: c }); box(50, 1.6, 1.6, mat('crane', {}), { x: 14, y: 59, parent: c }); box(4, 3, 3, mat('crane', {}), { x: -8, y: 57, parent: c }); cyl(0.05, 0.05, 25, 3, M.black, { x: 26, y: 46, parent: c }); }
  // an unfinished frame next to the cranes
  { const m = mat('frameConc', { color: 0x4a4844, roughness: 1 }); for (let f = 0; f < 7; f++) box(36, 0.4, 14, m, { x: 140, y: Gy + f * 3, base: true, z: -250 }); for (let i = 0; i < 7; i++) for (const sz of [-6.5, 6.5]) box(0.5, 21, 0.5, m, { x: 122 + i * 6, y: Gy, base: true, z: -250 + sz }); }
}
function smoke(x, y, z) {
  const tex = glowTex(), puffs = [];
  for (let i = 0; i < 16; i++) { const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, color: 0x5a5852, transparent: true, depthWrite: false, opacity: 0.25 })); G.scene.add(s); puffs.push({ s, t: i / 16 }); }
  onUpdate((dt) => { for (const p of puffs) { p.t = (p.t + dt * 0.012) % 1; const k = p.t; p.s.position.set(x + k * 90, y + k * 40, z + k * 20); const sc = 10 + k * 60; p.s.scale.set(sc, sc, 1); p.s.material.opacity = 0.28 * Math.sin(k * Math.PI); } });
}

// ---------------------------------------------------------------- the stair landing beyond the front door
function landing() {
  const L = LANDING;
  const wallM = mat('stairWall', { map: (() => { const s = new Surface(4, 3, 64, 900).fill('#c8c4b0').noise(0.35, 1.4, 'multiply', 8, 900); const g = s.g; g.fillStyle = '#4a6a5a'; g.fillRect(0, s.Y(1.5), s.W, s.px(1.5)); g.fillStyle = '#2a3a30'; g.fillRect(0, s.Y(1.5), s.W, 3); s.rising(0.6, [30, 30, 25], 0.5); s.spray('ВИТЯ', 1.4, 1.1, 0.18, '#1a1a1a', 0.1); s.mould(3.2, 2.5, 0.8, 0.6, 1); return s.textures().map; })(), roughness: 0.85 });
  const floorM = mat('stairFloor', { map: metalTex('#6a645a', 0.4, 901).map, roughness: 0.9 });
  const W = L.x1 - L.x0, Dd = L.z1 - L.z0;
  box(W, 0.1, Dd, floorM, { x: (L.x0 + L.x1) / 2, y: -0.1, base: true, z: (L.z0 + L.z1) / 2, cast: false });
  box(W, 0.1, Dd, mat('stairCeil', { color: 0x8a867a, roughness: 1 }), { x: (L.x0 + L.x1) / 2, y: 2.9, base: true, z: (L.z0 + L.z1) / 2, cast: false });
  box(0.1, 3, Dd, wallM, { x: L.x1, y: 0, base: true, z: (L.z0 + L.z1) / 2, cast: false });
  box(W, 3, 0.1, wallM, { x: (L.x0 + L.x1) / 2, y: 0, base: true, z: L.z1, cast: false });
  // flat 48's door opposite, ajar on darkness
  const dark = box(0.95, 2.05, 0.05, solidMat('void', 0x050404, 1), { x: L.x1 - 0.06, y: 0, base: true, z: 4.6, ry: Math.PI / 2, cast: false });
  void dark;
  const d48 = group({ x: L.x1 - 0.08, y: 0, z: 4.13 });
  box(0.9, 2.0, 0.06, mat('door48', { map: woodTex('#5a2a1e', 902, 1).map, roughness: 0.6 }), { x: 0.45, y: 1.0, parent: d48, static: false });
  d48.rotation.y = -Math.PI / 2 + 0.55;
  const brass = mat('brass', {}); box(0.1, 0.04, 0.005, brass, { x: 0.45, y: 1.65, z: 0.035, parent: d48, static: false });
  G.door48 = d48;
  // the stairs going down, toward -z, into the dark; the handrail
  for (let i = 0; i < 9; i++) box(1.3, 0.16, 0.3, floorM, { x: L.x0 + 0.9, y: -0.16 * (i + 1), base: true, z: L.z0 + 0.9 - i * 0.3, cast: false });
  for (let i = 0; i < 9; i++) box(1.3, 0.16, 0.3, floorM, { x: L.x0 + 2.4, y: 0.16 * i, base: true, z: L.z0 + 0.9 - i * 0.3, cast: false });
  box(0.05, 0.05, 3.2, mat('handrail', { color: 0x4a2a1a, roughness: 0.5 }), { x: L.x0 + 1.6, y: 0.9, z: L.z0 - 0.3, rx: 0.5 });
  // the bulkhead lamp on the wall: emergency circuit, low, reddish
  const lampM = mat('bulkhead', { color: 0x401010, emissive: 0xff3a20, emissiveIntensity: 0, roughness: 0.4 });
  const lamp = box(0.22, 0.14, 0.08, lampM, { x: L.x1 - 0.06, y: 2.3, z: 3.0, ry: -Math.PI / 2, static: false });
  void lamp;
  const pl = new THREE.PointLight(0xff4a30, 2.2, 7, 2); pl.position.set(L.x1 - 0.35, 2.25, 3.0);
  addLight('landing', pl, { on: true, flicker: 'dying', fixtures: [lamp], emissive: 2 });
  // a pile of post nobody collected; the lift doors, forced open on the shaft
  box(1.2, 2.1, 0.06, mat('liftDoor', { map: metalTex('#7a7a70', 1.2, 903).map, roughness: 0.6, metalness: 0.6 }), { x: L.x0 + 1.6, y: 0, base: true, z: L.z1 - 0.06, cast: false });
  box(0.4, 2.1, 0.02, solidMat('void', 0x050404, 1), { x: L.x0 + 1.6, y: 0, base: true, z: L.z1 - 0.1, cast: false });
}

// ---------------------------------------------------------------- the peephole
function peephole() {
  let on = false, saved = null, n = 0;
  G.peephole = () => {
    if (on) return;
    on = true; n++;
    saved = { fov: G.camera.fov, pos: G.camera.position.clone(), q: G.camera.quaternion.clone() };
    G.peeping = true; G.flags.peepFrozen = true;
    // the door across changes between looks: open, shut, open wider. Never while you watch
    if (G.door48) G.door48.rotation.y = n === 2 ? -Math.PI / 2 : n >= 3 ? -Math.PI / 2 + 1.0 : -Math.PI / 2 + 0.55;
    G.ui.toast(n === 1 ? 'The landing. Flat 48’s door, opposite, standing open on the dark.' : n === 2 ? 'Flat 48’s door is shut now.' : 'Flat 48’s door is open again. Wider.', 4);
    if (n === 2) sfx('doorShut', V(13.4, 1, 4.5), { vol: 0.5, room: 'landing' });
    const exit = () => { on = false; G.peeping = false; G.flags.peepFrozen = false; G.camera.fov = saved.fov; G.camera.updateProjectionMatrix(); removeEventListener('keydown', k); removeEventListener('mousedown', exit); };
    const k = (e) => { if (e.code === 'KeyE' || e.code === 'Escape' || e.code === 'KeyS') exit(); };
    setTimeout(() => { addEventListener('keydown', k); addEventListener('mousedown', exit); }, 200);
  };
  onUpdate(() => {
    if (!G.peeping) return;
    G.camera.position.set(10.48, 1.58, 4.56); G.camera.rotation.set(-0.05, -Math.PI / 2 + Math.sin(G.time * 0.7) * 0.04, 0, 'YXZ');
    if (G.camera.fov !== 125) { G.camera.fov = 125; G.camera.updateProjectionMatrix(); }
  });
}

// the street side, seen only in slices between the boards over Sonya's window
function southSide() {
  const tex = facadeTex('stucco', 960, 6, 4);
  building(5, 34, 70, 12, 7 * 3.3, 0, tex, {});
  building(-40, 20, 12, 30, 5 * 3.3, 0, facadeTex('brick', 961, 5, 4), {});
  const road = new THREE.Mesh(new THREE.PlaneGeometry(140, 30), solidMat('southRoad', 0x2a2928, 1)); road.rotation.x = -Math.PI / 2; road.position.set(5, Gy + 0.01, 18); G.scene.add(road);
  // the tall lamp whose sodium light comes through the slats
  const pole = mat('lampPole', {});
  cyl(0.09, 0.13, 3.4 - Gy, 8, pole, { x: 4.9, y: (3.4 + Gy) / 2, z: 12.6 });
  box(0.06, 0.06, 0.7, pole, { x: 4.9, y: 3.42, z: 12.3 });
  box(0.24, 0.1, 0.5, mat('lampHeadOn', { color: 0x2a2a26, emissive: 0xffa040, emissiveIntensity: 3 }), { x: 4.75, y: 3.3, z: 12.0 });
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: 0xffa04a, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0.9 }));
  sp.scale.set(2.6, 2.6, 1); sp.position.set(4.75, 3.2, 12.0); G.scene.add(sp);
  for (const [x, z, ry] of [[-6, 17, 0.05], [9, 19.5, Math.PI]]) car(x, z, ry, { col: 0x5a5a6a });
  tree(16, 14, 10, 977);
}

export function buildExterior() {
  southSide();
  sky();
  ground();
  courtyard();
  city();
  const pre = new Set(G.scene.children);
  landing();
  for (const o of G.scene.children) if (!pre.has(o)) o.userData.indoor = true;
  peephole();
  void interactive; void lathe; void DOORS; void STOREY;
}
