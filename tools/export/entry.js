// Bundled separately (tools/export_level.mjs) and injected into the running JS build:
// turns the built Flat 47 into a .glb (geometry + baked textures) and a level JSON
// (collision, floors, lights, doors, props) for the Godot project to import.
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { Group, Mesh, Matrix4, Color, CanvasTexture, Vector2, Vector3, Quaternion } from 'three';

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
  // Godot ignores EXT_materials_bump, so each painted height map becomes a normal map. three's
  // bump gives a slope of bumpScale x (height change per metre); the surfaces are painted at
  // 128 px per metre, so per texel the slope is bumpScale * 128 * dh.
  const PPM = 128, normals = new Map(), bumped = [];
  const toNormal = (tex, scale) => {
    const key = tex.uuid + ':' + scale; if (normals.has(key)) return normals.get(key);
    const img = tex.image, w = img.width, h = img.height;
    const src = document.createElement('canvas'); src.width = w; src.height = h;
    const sx = src.getContext('2d'); sx.drawImage(img, 0, 0); const d = sx.getImageData(0, 0, w, h).data;
    const out = document.createElement('canvas'); out.width = w; out.height = h;
    const ox = out.getContext('2d'), o = ox.createImageData(w, h), k = scale * PPM / 255 / 2;
    const H = (x, y) => d[(((y + h) % h) * w + ((x + w) % w)) * 4];
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const nx = -(H(x + 1, y) - H(x - 1, y)) * k, ny = (H(x, y + 1) - H(x, y - 1)) * k;   // canvas y is down, v is up
      const l = Math.hypot(nx, ny, 1), i = (y * w + x) * 4;
      o.data[i] = (nx / l * 0.5 + 0.5) * 255; o.data[i + 1] = (ny / l * 0.5 + 0.5) * 255; o.data[i + 2] = (1 / l * 0.5 + 0.5) * 255; o.data[i + 3] = 255;
    }
    ox.putImageData(o, 0, 0);
    const t = new CanvasTexture(out); t.wrapS = tex.wrapS; t.wrapT = tex.wrapT; t.repeat.copy(tex.repeat); t.offset.copy(tex.offset); t.flipY = tex.flipY;
    normals.set(key, t); return t;
  };
  const seen = new Set();
  for (const k of keep) k.traverse((o) => {
    for (const m of [].concat(o.material || [])) {
      if (seen.has(m) || !m.bumpMap || m.normalMap || !m.bumpMap.image?.width) continue;
      seen.add(m); bumped.push([m, m.bumpMap]);
      m.normalMap = toNormal(m.bumpMap, m.bumpScale); m.normalScale = new Vector2(1, 1); m.bumpMap = null;
    }
  });
  const root = { children: keep };
  const exporter = new GLTFExporter();
  const glb = await new Promise((res, rej) => exporter.parse(keep, res, rej, { binary: true, onlyVisible: true, maxTextureSize: maxTex, trs: true }));
  for (const [o, u] of saved) o.userData = u;
  for (const [parent, idx, im, g] of swaps) { parent.children[idx] = im; g.parent = null; const ki = keep.indexOf(g); if (ki >= 0) keep[ki] = im; }
  for (const [m, b] of bumped) { m.bumpMap = b; m.normalMap = null; }
  void root;
  // level data
  const inFlat = (c) => c.y0 < 2.9 && c.y1 > 0.1 && !c.door;
  const level = {
    colliders: G.colliders.filter(inFlat).map((c) => ({ x: c.x, z: c.z, hx: c.hx, hz: c.hz, rot: c.rot, y0: Math.max(-0.5, c.y0), y1: Math.min(3.25, c.y1) })),
    floors: G.floors.filter((f) => f.za === undefined && Math.abs(f.y) < 0.5).map((f) => ({ x0: f.x0, x1: f.x1, z0: f.z0, z1: f.z1, y: f.y })),
    // Every light that reaches the flat, wherever it is parented: the flat's own, the stairwell's
    // and the courtyard's (at the JS build's default quality none of the point lights cast
    // shadows, so their light bleeds through walls, and that bleed is part of how the rooms look).
    lights: (() => {
      const out = [], w = new Vector3(), t = new Vector3();
      const meta = new Map((window.__LIGHTS || []).map((L) => [L.l, L]));
      scene.traverse((l) => {
        if (!(l.isPointLight || l.isSpotLight || l.isRectAreaLight)) return;
        const L = meta.get(l);
        if (L?.virtual || l === G.torch?.light) return;
        const k = L ? L.base : l.intensity;
        if (!(k > 0)) return;
        l.getWorldPosition(w);
        if (w.x < -14 || w.x > 24 || w.z < -14 || w.z > 20 || w.y < -4 || w.y > 6) return;
        const e = { name: L?.name || l.name || 'light', type: l.type, pos: w.toArray(), color: '#' + l.color.getHexString(), intensity: k, range: l.distance || 0, decay: l.decay ?? 2,
          circuit: L?.circuit ?? null, on: L ? !!L.switched : true, flicker: L?.flicker ?? null, broken: !!L?.broken, shadow: l.userData.shadowTier ? ['low', 'medium'].includes(l.userData.shadowTier) : !!l.castShadow };
        if (l.isSpotLight) { l.target.getWorldPosition(t); Object.assign(e, { target: t.toArray(), angle: l.angle, penumbra: l.penumbra }); }
        if (l.isRectAreaLight) { const d = new Vector3(0, 0, -1).applyQuaternion(l.getWorldQuaternion(new Quaternion())); Object.assign(e, { dir: d.toArray(), w: l.width, h: l.height }); }
        out.push(e);
      });
      // the building's pooled lamps: from inside the flat the pool lights the four nearest lit
      // fixtures on this storey (building.js buildLightPool)
      const c = new Vector3(5, 1.6, 4);
      (G.fixtures || []).filter((f) => f.on && (!f.when || f.when()) && Math.abs(f.pos.y - c.y) < 5 && f.pos.distanceTo(c) < 16)
        .sort((a, b) => a.pos.distanceToSquared(c) - b.pos.distanceToSquared(c)).slice(0, 4)
        .forEach((f, i) => out.push({ name: 'stair' + i, type: 'PointLight', pos: f.pos.toArray(), color: '#' + new Color(f.color).getHexString(), intensity: f.k, range: f.range, decay: 2, circuit: null, on: true, flicker: f.flicker, broken: false, shadow: false }));
      return out;
    })(),
    circuits: Object.fromEntries(Object.entries(G.circuits || {}).map(([k, c]) => [k, !!c.on])),
    spawn: { x: 9.35, y: 0, z: 4.55, yaw: Math.PI / 2 },
  };
  // hand the file back as base64 in one string (an array of numbers this size runs out of memory)
  const u8 = new Uint8Array(glb); let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return { glb: btoa(s), level };
};
