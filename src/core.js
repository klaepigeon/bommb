// Shared state and the small builders everything else uses: boxes and cylinders with
// UVs in metres, a material cache, the player's collision boxes and the physics world.
import * as THREE from 'three';
import * as CANNON from 'cannon-es';

export const G = {
  scene: null, camera: null, renderer: null,
  phys: null,
  colliders: [],       // player collision: oriented boxes in XZ with a height band
  interact: [],        // things the crosshair can use
  updates: [],         // per-frame callbacks (dt, t)
  props: [],           // physics props
  pickables: [],       // things you can take that have no body yet
  lights: {},          // named lights
  circuits: {},        // power circuits: name -> { on, lights: [], onChange: [] }
  rooms: {},
  flags: {},
  time: 0,
};

export const v3 = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);

// ---------------------------------------------------------------- materials
const mats = {};
export function mat(key, params) {
  if (mats[key]) return mats[key];
  const p = { roughness: 0.85, metalness: 0, ...params };
  if (p.map && p.bumpMap === undefined) delete p.bumpMap;
  const m = new THREE.MeshStandardMaterial(p);
  mats[key] = m;
  return m;
}
export function solidMat(key, color, rough = 0.85, metal = 0, extra = {}) {
  return mat(key, { color, roughness: rough, metalness: metal, ...extra });
}
// a tiled textured material from a Surface.textures() bundle
export function texMat(key, tex, extra = {}) {
  if (mats[key]) return mats[key];
  const p = { map: tex.map, bumpMap: tex.bumpMap, bumpScale: 1.2, roughness: 0.88, ...extra };
  if (tex.roughnessMap) p.roughnessMap = tex.roughnessMap;
  return mat(key, p);
}

// ---------------------------------------------------------------- geometry
// BoxGeometry with UVs scaled to metres * uvs (so tiled textures keep their size)
export function boxGeo(w, h, d, uvs = 1) {
  const g = new THREE.BoxGeometry(w, h, d);
  const uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let i = 0; i < 4; i++) {
    const k = f * 4 + i;
    uv.setXY(k, uv.getX(k) * dims[f][0] * uvs, uv.getY(k) * dims[f][1] * uvs);
  }
  return g;
}

export function place(obj, o = {}) {
  obj.position.set(o.x || 0, o.y || 0, o.z || 0);
  if (o.rx) obj.rotation.x = o.rx;
  if (o.ry) obj.rotation.y = o.ry;
  if (o.rz) obj.rotation.z = o.rz;
  if (o.order) obj.rotation.order = o.order;
  if (o.s) obj.scale.setScalar(o.s);
  (o.parent || G.scene).add(obj);
  return obj;
}

// a box mesh whose (x,y,z) is the CENTRE of the box unless o.base is set (then y is its bottom)
export function box(w, h, d, material, o = {}) {
  const m = new THREE.Mesh(boxGeo(w, h, d, o.uvs ?? 1), material);
  m.castShadow = o.cast ?? true; m.receiveShadow = true;
  const y = (o.y || 0) + (o.base ? h / 2 : 0);
  place(m, { ...o, y });
  if (o.static !== false) m.userData.static = true;
  return m;
}
export function cyl(rt, rb, h, seg, material, o = {}) {
  const g = new THREE.CylinderGeometry(rt, rb, h, seg, o.hseg || 1, o.open || false);
  if (o.uvs) { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 2 * Math.PI * Math.max(rt, rb) * o.uvs, uv.getY(i) * h * o.uvs); }
  const m = new THREE.Mesh(g, material);
  m.castShadow = o.cast ?? true; m.receiveShadow = true;
  place(m, { ...o, y: (o.y || 0) + (o.base ? h / 2 : 0) });
  if (o.static !== false) m.userData.static = true;
  return m;
}
export function sphere(r, material, o = {}) {
  const m = new THREE.Mesh(new THREE.SphereGeometry(r, o.seg || 12, o.seg2 || 8), material);
  m.castShadow = o.cast ?? true; m.receiveShadow = true;
  place(m, o);
  if (o.static !== false) m.userData.static = true;
  return m;
}
export function group(o = {}) { return place(new THREE.Group(), o); }

// ---------------------------------------------------------------- collision
// An oriented rectangle in XZ (centre x,z; half extents hx,hz; yaw rot) between heights y0..y1.
export function collider(c) {
  const col = { x: 0, z: 0, hx: 0.1, hz: 0.1, rot: 0, y0: 0, y1: 2.8, on: true, ...c };
  G.colliders.push(col);
  return col;
}

let staticMatl;
export function physMaterial() { return staticMatl; }

export function initPhysics() {
  const w = new CANNON.World({ gravity: new CANNON.Vec3(0, -9.82, 0) });
  w.broadphase = new CANNON.SAPBroadphase(w);
  w.allowSleep = true;
  w.solver.iterations = 8;
  staticMatl = new CANNON.Material('static');
  const propMatl = new CANNON.Material('prop');
  w.addContactMaterial(new CANNON.ContactMaterial(staticMatl, propMatl, { friction: 0.45, restitution: 0.15 }));
  w.addContactMaterial(new CANNON.ContactMaterial(propMatl, propMatl, { friction: 0.4, restitution: 0.1 }));
  w.propMatl = propMatl;
  // heavy furniture slides (cannon sums friction over every contact point, so a box on a floor
  // otherwise sticks like glue)
  const slide = new CANNON.Material('slide');
  w.addContactMaterial(new CANNON.ContactMaterial(staticMatl, slide, { friction: 0, restitution: 0 }));
  w.addContactMaterial(new CANNON.ContactMaterial(propMatl, slide, { friction: 0, restitution: 0 }));
  w.slideMatl = slide;
  G.phys = w;
  return w;
}

// a static physics box (props land on it) — centre x,y,z, full sizes
export function staticBox(x, y, z, sx, sy, sz, ry = 0) {
  const b = new CANNON.Body({ mass: 0, material: staticMatl, type: CANNON.Body.STATIC });
  b.addShape(new CANNON.Box(new CANNON.Vec3(sx / 2, sy / 2, sz / 2)));
  b.position.set(x, y, z);
  if (ry) b.quaternion.setFromEuler(0, ry, 0);
  G.phys.addBody(b);
  return b;
}

// both: blocks the player and the props. (x,z) centre, y0 bottom, sizes sx,sy,sz
export function solid(x, y0, z, sx, sy, sz, ry = 0, o = {}) {
  const c = o.noPlayer ? null : collider({ x, z, hx: sx / 2, hz: sz / 2, rot: ry, y0, y1: y0 + sy });
  const b = o.noPhys ? null : staticBox(x, y0 + sy / 2, z, sx, sy, sz, ry);
  return { c, b };
}

// ---------------------------------------------------------------- interaction registry
// { mesh(es), prompt: () => string, use: () => void, range }
export function interactive(meshes, spec) {
  const list = Array.isArray(meshes) ? meshes : [meshes];
  const it = { range: 2.0, ...spec, meshes: list };
  for (const m of list) m.traverse((o) => { o.userData.it = it; o.userData.static = false; });
  G.interact.push(it);
  return it;
}

export function onUpdate(f) { G.updates.push(f); }

// ---------------------------------------------------------------- power circuits
export function circuit(name, on = true) {
  if (!G.circuits[name]) G.circuits[name] = { name, on, fns: [] };
  return G.circuits[name];
}
export function setCircuit(name, on) {
  const c = circuit(name); c.on = on; c.fns.forEach((f) => f(on));
}
