// Physics props: anything you can knock over, kick, carry, throw or push. Small things
// sit asleep until something disturbs them; things in drawers have no body at all until
// you take them out.
import * as THREE from 'three';
import * as CANNON from 'cannon-es';
import { G, onUpdate } from './core.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { sfx } from './audio.js';

const tmpBox = new THREE.Box3(), tmpV = new THREE.Vector3(), tmpQ = new THREE.Quaternion();

// mesh: an Object3D already placed in the scene (any parent). o: { mass, name, desc, sound, shape, pick, push, doc }
export function makeProp(mesh, o = {}) {
  if (mesh.userData.prop) return mesh.userData.prop;
  // move to the scene root keeping its world transform
  mesh.updateWorldMatrix(true, true);
  G.scene.attach(mesh);
  mesh.traverse((m) => { m.userData.static = false; });
  // local-space bounds (with rotation removed)
  const q0 = mesh.quaternion.clone(); mesh.quaternion.identity(); mesh.updateMatrixWorld(true);
  tmpBox.setFromObject(mesh, true);
  const centre = tmpBox.getCenter(new THREE.Vector3()).sub(mesh.position);
  const size = o.size ? new THREE.Vector3(...o.size) : tmpBox.getSize(new THREE.Vector3());
  mesh.quaternion.copy(q0); mesh.updateMatrixWorld(true);
  mergeInto(mesh);
  const mass = o.mass ?? 1;
  const body = new CANNON.Body({ mass, material: (o.push ?? mass > 4) && mass >= 20 ? G.phys.slideMatl : G.phys.propMatl, linearDamping: o.damp ?? 0.12, angularDamping: o.adamp ?? 0.25, allowSleep: true, sleepSpeedLimit: 0.12, sleepTimeLimit: 0.6 });
  const off = new CANNON.Vec3(centre.x, centre.y, centre.z);
  if (o.shape === 'sphere') body.addShape(new CANNON.Sphere(o.radius || Math.max(size.x, size.y, size.z) / 2), off);
  else if (o.shape === 'cyl') {
    const sh = new CANNON.Cylinder(o.radius || size.x / 2, o.radius || size.x / 2, size.y, 10);
    body.addShape(sh, off);
  } else if (o.shapes) { for (const s of o.shapes) body.addShape(new CANNON.Box(new CANNON.Vec3(s.size[0] / 2, s.size[1] / 2, s.size[2] / 2)), new CANNON.Vec3(...s.at)); }
  else body.addShape(new CANNON.Box(new CANNON.Vec3(Math.max(0.01, size.x / 2), Math.max(0.01, size.y / 2), Math.max(0.01, size.z / 2))), off);
  body.position.set(mesh.position.x, mesh.position.y, mesh.position.z);
  body.quaternion.set(mesh.quaternion.x, mesh.quaternion.y, mesh.quaternion.z, mesh.quaternion.w);
  G.phys.addBody(body);
  if (o.asleep !== false) body.sleep();
  const prop = {
    mesh, body, mass, size, centre, name: o.name || 'thing', desc: o.desc || '', sound: o.sound || 'wood',
    pick: o.pick ?? mass <= 12, push: o.push ?? mass > 4, doc: o.doc || null, lastHit: 0, held: false, onPick: o.onPick,
  };
  mesh.userData.prop = prop;
  mesh.traverse((m) => { m.userData.prop = prop; });
  body.addEventListener('collide', (e) => {
    const v = Math.abs(e.contact.getImpactVelocityAlongNormal());
    const now = performance.now();
    if (v < 0.6 || now - prop.lastHit < 90) return;
    prop.lastHit = now;
    const vol = Math.min(1, (v - 0.5) / 4) * Math.min(1.6, 0.4 + Math.sqrt(mass) * 0.35);
    sfx(prop.sound, mesh.position, { vol, rate: 1.15 - Math.min(0.3, mass * 0.02) });
    if (prop.sound === 'glassTink' && v > 4.5 && o.breakable) breakGlass(prop);
    G.onNoise?.(mesh.position, vol);
  });
  G.props.push(prop);
  return prop;
}
G.makeProp = makeProp;

function breakGlass(prop) {
  sfx('glassBreak', prop.mesh.position, { vol: 0.9 });
  prop.mesh.visible = false; G.phys.removeBody(prop.body); prop.dead = true;
  prop.mesh.traverse((m) => { if (m.userData.it) m.userData.it.disabled = true; });
}

// keep meshes on their bodies
onUpdate(() => {
  for (const p of G.props) {
    if (p.dead || p.body.sleepState === CANNON.Body.SLEEPING && !p.held) continue;
    p.mesh.position.set(p.body.position.x, p.body.position.y, p.body.position.z);
    p.mesh.quaternion.set(p.body.quaternion.x, p.body.quaternion.y, p.body.quaternion.z, p.body.quaternion.w);
    // fell out of the world somehow: put it back on the floor where it went
    if (p.body.position.y < -2 && !p.held) { p.body.position.y = 0.3; p.body.velocity.setZero(); }
  }
});

// footprint of a prop in XZ as an oriented box, for the player to push against
export function propFootprint(p) {
  const q = p.body.quaternion; tmpQ.set(q.x, q.y, q.z, q.w);
  const yaw = new THREE.Euler().setFromQuaternion(tmpQ, 'YXZ').y;
  tmpV.copy(p.centre).applyQuaternion(tmpQ);
  return { x: p.body.position.x + tmpV.x, z: p.body.position.z + tmpV.z, hx: p.size.x / 2, hz: p.size.z / 2, rot: yaw, y0: p.body.position.y + tmpV.y - p.size.y / 2, y1: p.body.position.y + tmpV.y + p.size.y / 2 };
}

// a pickable thing with no body yet (sits in a drawer, on a shelf): becomes a prop when taken
export function pickable(mesh, o) {
  mesh.traverse((m) => { m.userData.pickSpec = o; m.userData.static = false; });
  mesh.traverse((m) => { m.userData.pickRoot = mesh; });
  G.pickables.push(mesh);
  return mesh;
}

// fold a group's plain child meshes into one mesh per material (fewer draw calls); parts
// that are interactive on their own (doors, drawers, things to take) stay separate
export function mergeInto(root) {
  if (root.isMesh) return;
  root.updateMatrixWorld(true);
  const inv = root.matrixWorld.clone().invert();
  const groups = new Map(), victims = [];
  root.traverse((m) => {
    if (!m.isMesh || m === root || Array.isArray(m.material) || m.material.transparent || m.isInstancedMesh) return;
    for (let p = m; p && p !== root; p = p.parent) if (p.userData.it || p.userData.pickSpec || p.userData.noMerge || (p !== m && p.userData.drawer)) return;
    if (!groups.has(m.material)) groups.set(m.material, []);
    groups.get(m.material).push(m);
  });
  for (const [mat, list] of groups) {
    if (list.length < 2) continue;
    const geos = list.map((m) => {
      let g = m.geometry.index ? m.geometry.toNonIndexed() : m.geometry.clone();
      for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k);
      return g.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv, m.matrixWorld));
    });
    if (geos.some((g) => !g.attributes.uv)) continue;
    const mg = mergeGeometries(geos, false); if (!mg) continue;
    const mm = new THREE.Mesh(mg, mat); mm.castShadow = list.some((m) => m.castShadow); mm.receiveShadow = true;
    root.add(mm); victims.push(...list);
  }
  for (const m of victims) m.parent.remove(m);
}
