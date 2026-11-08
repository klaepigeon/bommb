// Bundled separately (tools/export_level.mjs) and injected into the running JS build:
// turns the built Flat 47 into a .glb (geometry + baked textures) and a level JSON
// (collision, floors, lights, doors, props) for the Godot project to import.
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { Group, Mesh, Matrix4, Color } from 'three';

window.__exportFlat47 = async (maxTex) => {
  const G = window.__G, scene = G.scene;
  // what belongs to Flat 47: not the city, not the rest of the building, not effects
  const outside = new Set(G.outside || []);
  const skip = (o) => outside.has(o) || o.userData.zone || o.isLight || o.isSprite || o.isPoints || o.isCamera
    || (o.material && (o.material.isShaderMaterial || o.material.isRawShaderMaterial)) || o === G.marta?.g || o === G.voidGroup || o === G.streetVoid;
  const keep = scene.children.filter((o) => !skip(o));
  // strip runtime userData (functions, circular refs) and label the interesting nodes
  const saved = new Map();
  scene.traverse((o) => { saved.set(o, o.userData); o.userData = {}; });
  let n = 0;
  const tag = (o, name, extras) => { o.name = name.replace(/[^A-Za-z0-9_]/g, '_'); o.userData = extras; };
  for (const [id, d] of Object.entries(window.__G.doorsById || {})) {
    if (!keep.includes(d.pivot)) continue;
    tag(d.pivot, 'door_' + id, { kind: 'door', id, max: d.max, sign: d.sign, psi0: d.psi0, w: d.w, h: d.h, open: d.angle, locked: id === 'dEntry' ? 'chain' : id === 'dStore' ? 'bolt' : null });
  }
  for (const p of G.props) { if (p.dead || !keep.includes(p.mesh)) continue; tag(p.mesh, `prop_${n++}_${p.name}`, { kind: 'prop', name: p.name, desc: p.desc, mass: p.mass, sound: p.sound, size: p.size.toArray(), centre: p.centre.toArray(), push: p.push, pick: p.pick }); }
  for (const m of G.pickables) { if (m.userData?.taken) continue; const spec = saved.get(m)?.pickSpec; if (!spec) continue; tag(m, `pick_${n++}_${spec.name}`, { kind: 'pick', name: spec.name, desc: spec.desc || '', read: !!spec.read, mass: spec.mass || 0.1 }); }
  scene.traverse((o) => { const u = saved.get(o); if (u?.drawer) tag(o, `drawer_${n++}`, { kind: 'drawer', max: u.drawer.max }); });
  // Godot can't read EXT_mesh_gpu_instancing: expand instanced meshes into plain ones for the export
  const swaps = [];
  const inst = []; for (const k of keep) k.traverse((o) => { if (o.isInstancedMesh) inst.push(o); });
  for (const im of inst) {
    const g = new Group(); g.name = im.name || 'inst'; g.position.copy(im.position); g.quaternion.copy(im.quaternion); g.scale.copy(im.scale);
    const m4 = new Matrix4(), col = new Color(), mats = new Map();
    for (let i = 0; i < im.count; i++) {
      im.getMatrixAt(i, m4);
      let mat = im.material;
      if (im.instanceColor) {
        im.getColorAt(i, col); const key = col.getHexString();
        if (!mats.has(key)) { const c = im.material.clone(); c.color.multiply(col); mats.set(key, c); }
        mat = mats.get(key);
      }
      const m = new Mesh(im.geometry, mat); m.applyMatrix4(m4); g.add(m);
    }
    const parent = im.parent, idx = parent.children.indexOf(im);
    parent.children[idx] = g; g.parent = parent; g.visible = im.visible;
    swaps.push([parent, idx, im, g]);
    const ki = keep.indexOf(im); if (ki >= 0) keep[ki] = g;
  }
  const root = { children: keep };
  const exporter = new GLTFExporter();
  const glb = await new Promise((res, rej) => exporter.parse(keep, res, rej, { binary: true, onlyVisible: true, maxTextureSize: maxTex, trs: true }));
  for (const [o, u] of saved) o.userData = u;
  for (const [parent, idx, im, g] of swaps) { parent.children[idx] = im; g.parent = null; const ki = keep.indexOf(g); if (ki >= 0) keep[ki] = im; }
  void root;
  // level data
  const inFlat = (c) => c.y0 < 2.9 && c.y1 > 0.1 && !c.door;
  const level = {
    colliders: G.colliders.filter(inFlat).map((c) => ({ x: c.x, z: c.z, hx: c.hx, hz: c.hz, rot: c.rot, y0: Math.max(-0.5, c.y0), y1: Math.min(3.25, c.y1) })),
    floors: G.floors.filter((f) => f.za === undefined && Math.abs(f.y) < 0.5).map((f) => ({ x0: f.x0, x1: f.x1, z0: f.z0, z1: f.z1, y: f.y })),
    lights: (window.__LIGHTS || []).filter((L) => L.l.parent === scene && !L.virtual).map((L) => {
      const l = L.l, p = l.position; return { name: L.name, type: l.type, pos: [p.x, p.y, p.z], color: '#' + l.color.getHexString(), intensity: L.base, range: l.distance || 0, circuit: L.circuit, on: L.switched, flicker: L.flicker, broken: L.broken };
    }),
    spawn: { x: 9.35, y: 0, z: 4.55, yaw: Math.PI / 2 },
  };
  // hand the file back as base64 in one string (an array of numbers this size runs out of memory)
  const u8 = new Uint8Array(glb); let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return { glb: btoa(s), level };
};
