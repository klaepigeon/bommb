// Procedural surfaces. Every wall, floor and ceiling face gets its own canvas, so no two
// patches of damp, peel or mould repeat. A Surface keeps a colour canvas and a height
// canvas (used as the bump map); painters draw into both at once.
import * as THREE from 'three';

export function rng(seed) {
  let a = seed >>> 0 || 1;
  const f = () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  f.range = (a0, b0) => a0 + (b0 - a0) * f();
  f.int = (a0, b0) => Math.floor(a0 + (b0 - a0 + 1) * f());
  f.pick = (arr) => arr[Math.floor(f() * arr.length)];
  f.chance = (p) => f() < p;
  return f;
}

export function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.max(2, Math.round(w)); c.height = Math.max(2, Math.round(h));
  return c;
}

// ---- tileable value-noise canvases, made once, stamped everywhere with drawImage ----
const noiseCache = {};
export function noiseCanvas(size = 256, cell = 8, octaves = 4, seed = 7) {
  const key = `${size}/${cell}/${octaves}/${seed}`;
  if (noiseCache[key]) return noiseCache[key];
  const r = rng(seed);
  const c = canvas(size, size), g = c.getContext('2d');
  const img = g.createImageData(size, size);
  const acc = new Float32Array(size * size);
  let amp = 1, total = 0;
  for (let o = 0; o < octaves; o++) {
    const n = Math.max(1, Math.round(size / cell / Math.pow(2, -o) / (1 << o) * (1 << o)));
    const grid = Math.max(2, Math.round((size / cell) * Math.pow(2, o)));
    const v = new Float32Array(grid * grid);
    for (let i = 0; i < v.length; i++) v[i] = r();
    const s = grid / size;
    for (let y = 0; y < size; y++) {
      const gy = y * s, y0 = Math.floor(gy), fy = gy - y0, ty = fy * fy * (3 - 2 * fy);
      const ya = (y0 % grid) * grid, yb = ((y0 + 1) % grid) * grid;
      for (let x = 0; x < size; x++) {
        const gx = x * s, x0 = Math.floor(gx), fx = gx - x0, tx = fx * fx * (3 - 2 * fx);
        const xa = x0 % grid, xb = (x0 + 1) % grid;
        const a0 = v[ya + xa] + (v[ya + xb] - v[ya + xa]) * tx;
        const b0 = v[yb + xa] + (v[yb + xb] - v[yb + xa]) * tx;
        acc[y * size + x] += (a0 + (b0 - a0) * ty) * amp;
      }
    }
    total += amp; amp *= 0.5;
    void n;
  }
  for (let i = 0; i < acc.length; i++) {
    const v = Math.max(0, Math.min(255, (acc[i] / total) * 255));
    img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v; img.data[i * 4 + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  noiseCache[key] = c;
  return c;
}

// grain: per-pixel speckle, tileable
let grainC;
export function grainCanvas() {
  if (grainC) return grainC;
  const r = rng(99); grainC = canvas(256, 256);
  const g = grainC.getContext('2d'), img = g.createImageData(256, 256);
  for (let i = 0; i < 256 * 256; i++) { const v = r() * 255; img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v; img.data[i * 4 + 3] = 255; }
  g.putImageData(img, 0, 0);
  return grainC;
}

export function rgba(r, g, b, a = 1) { return `rgba(${r | 0},${g | 0},${b | 0},${a})`; }
export function shade(hex, k) {
  const c = new THREE.Color(hex);
  return `rgb(${Math.min(255, c.r * 255 * k) | 0},${Math.min(255, c.g * 255 * k) | 0},${Math.min(255, c.b * 255 * k) | 0})`;
}

// an irregular closed blob as a Path2D (radius modulated by a few sine harmonics + jitter)
export function blobPath(cx, cy, rx, ry, r, jag = 0.25, pts = 28) {
  const p = new Path2D();
  const h = [r() * 6.28, r() * 6.28, r() * 6.28], k = [r() * 0.4, r() * 0.25, r() * 0.15];
  for (let i = 0; i <= pts; i++) {
    const a = (i / pts) * Math.PI * 2;
    const m = 1 + k[0] * Math.sin(a * 2 + h[0]) + k[1] * Math.sin(a * 3 + h[1]) + k[2] * Math.sin(a * 5 + h[2]) + (r() - 0.5) * jag;
    const x = cx + Math.cos(a) * rx * m, y = cy + Math.sin(a) * ry * m;
    i ? p.lineTo(x, y) : p.moveTo(x, y);
  }
  p.closePath();
  return p;
}

// ------------------------------------------------------------------ Surface
export class Surface {
  constructor(wm, hm, ppm = 128, seed = 1) {
    this.wm = wm; this.hm = hm; this.ppm = ppm;
    this.W = Math.max(8, Math.round(wm * ppm)); this.H = Math.max(8, Math.round(hm * ppm));
    this.c = canvas(this.W, this.H); this.g = this.c.getContext('2d');
    this.hc = canvas(this.W, this.H); this.hg = this.hc.getContext('2d');
    this.hg.fillStyle = '#808080'; this.hg.fillRect(0, 0, this.W, this.H);
    this.rc = null;
    this.r = rng(seed);
  }
  px(m) { return m * this.ppm; }
  // y in metres from the BOTTOM of the face (canvas y grows downward)
  Y(m) { return this.H - m * this.ppm; }

  fill(col) { this.g.fillStyle = col; this.g.fillRect(0, 0, this.W, this.H); return this; }
  rough(v) { // start a roughness canvas
    this.rc = canvas(this.W, this.H); const g = this.rc.getContext('2d');
    g.fillStyle = `rgb(${v * 255 | 0},${v * 255 | 0},${v * 255 | 0})`; g.fillRect(0, 0, this.W, this.H);
    this.rg = g; return this;
  }
  // stamp a noise canvas across the whole face
  noise(alpha = 0.15, scale = 1, mode = 'overlay', cell = 8, seed = 7, target = 'c') {
    const n = noiseCanvas(256, cell, 4, seed), g = target === 'h' ? this.hg : this.g;
    g.save(); g.globalAlpha = alpha; g.globalCompositeOperation = mode;
    const s = 256 * scale, ox = -this.r() * s, oy = -this.r() * s;
    for (let y = oy; y < this.H; y += s) for (let x = ox; x < this.W; x += s) g.drawImage(n, x, y, s, s);
    g.restore(); return this;
  }
  grain(alpha = 0.06, mode = 'overlay', target = 'c') {
    const n = grainCanvas(), g = target === 'h' ? this.hg : this.g;
    g.save(); g.globalAlpha = alpha; g.globalCompositeOperation = mode;
    for (let y = 0; y < this.H; y += 256) for (let x = 0; x < this.W; x += 256) g.drawImage(n, x, y);
    g.restore(); return this;
  }
  pattern(tile, alpha = 1, scale = 1, mode = 'source-over') {
    const g = this.g; g.save(); g.globalAlpha = alpha; g.globalCompositeOperation = mode;
    const p = g.createPattern(tile, 'repeat');
    if (scale !== 1) p.setTransform(new DOMMatrix().scale(scale, scale));
    g.fillStyle = p; g.fillRect(0, 0, this.W, this.H); g.restore(); return this;
  }

  // brown tide-line water stain spreading from (x, top) downward
  waterStain(xm, ym, wm, hm, strength = 1) {
    const g = this.g, r = this.r;
    const cx = this.px(xm), cy = this.Y(ym), rx = this.px(wm) / 2, ry = this.px(hm) / 2;
    for (let ring = 0; ring < 4; ring++) {
      const k = 1 - ring * 0.2;
      const p = blobPath(cx, cy, rx * k, ry * k, r, 0.18, 40);
      g.save();
      g.fillStyle = rgba(120 - ring * 8, 92 - ring * 8, 48, 0.09 * strength);
      g.fill(p);
      g.lineWidth = 1.5 + r() * 2.5; g.strokeStyle = rgba(92, 64, 30, 0.22 * strength);
      g.stroke(p);
      g.restore();
    }
    // streaks running down
    const n = 3 + (r() * 6) | 0;
    for (let i = 0; i < n; i++) {
      const x = cx + (r() - 0.5) * rx * 1.4, len = this.px(hm) * (0.6 + r() * 1.4);
      const grd = g.createLinearGradient(0, cy, 0, cy + len);
      grd.addColorStop(0, rgba(100, 72, 36, 0.25 * strength)); grd.addColorStop(1, rgba(100, 72, 36, 0));
      g.fillStyle = grd; g.fillRect(x, cy, 2 + r() * 6, len);
    }
    return this;
  }

  // black-green mould bloom, densest at the centre
  mould(xm, ym, wm, hm, density = 1) {
    const g = this.g, r = this.r, cx = this.px(xm), cy = this.Y(ym), rx = this.px(wm) / 2, ry = this.px(hm) / 2;
    const n = Math.round(260 * density * (rx * ry) / 4000) + 30;
    for (let i = 0; i < n; i++) {
      const a = r() * 6.283, d = Math.pow(r(), 0.6);
      const x = cx + Math.cos(a) * rx * d, y = cy + Math.sin(a) * ry * d;
      const s = (1 - d) * 5 + r() * 3 + 0.5;
      g.fillStyle = rgba(28 + r() * 20, 34 + r() * 22, 22 + r() * 10, (1 - d) * 0.35 + 0.08);
      g.beginPath(); g.arc(x, y, s, 0, 6.283); g.fill();
    }
    const grd = g.createRadialGradient(cx, cy, 0, cx, cy, Math.max(rx, ry));
    grd.addColorStop(0, rgba(30, 36, 24, 0.35 * density)); grd.addColorStop(1, rgba(30, 36, 24, 0));
    g.fillStyle = grd; g.fillRect(cx - rx, cy - ry, rx * 2, ry * 2);
    return this;
  }

  // a hairline crack wandering from a point
  crack(xm, ym, lenm, ang = -Math.PI / 2, branches = 2, width = 1.4) {
    const g = this.g, hg = this.hg, r = this.r;
    const walk = (x, y, len, a, w, depth) => {
      const p = [[x, y]]; let l = 0;
      while (l < len) { a += (r() - 0.5) * 0.9; const st = 3 + r() * 6; x += Math.cos(a) * st; y += Math.sin(a) * st; l += st; p.push([x, y]); }
      for (const [ctx, col, lw] of [[g, rgba(30, 24, 18, 0.7), w], [hg, '#303030', w + 1]]) {
        ctx.save(); ctx.strokeStyle = col; ctx.lineWidth = lw; ctx.lineJoin = 'round';
        ctx.beginPath(); p.forEach(([px, py], i) => (i ? ctx.lineTo(px, py) : ctx.moveTo(px, py))); ctx.stroke(); ctx.restore();
      }
      if (depth > 0) for (let b = 0; b < branches; b++) {
        const q = p[(r() * p.length) | 0];
        walk(q[0], q[1], len * (0.3 + r() * 0.3), a + (r() < 0.5 ? -1 : 1) * (0.5 + r()), w * 0.7, depth - 1);
      }
    };
    walk(this.px(xm), this.Y(ym), this.px(lenm), ang, width, 2);
    return this;
  }

  // peeled area: reveals `under(g, path)` inside an irregular hole; curled lip at the top edge
  peel(xm, ym, wm, hm, under, lip = true) {
    const g = this.g, hg = this.hg, r = this.r;
    const cx = this.px(xm), cy = this.Y(ym), rx = this.px(wm) / 2, ry = this.px(hm) / 2;
    const p = blobPath(cx, cy, rx, ry, r, 0.45, 36);
    // shadow under the lifted edge
    g.save(); g.translate(2, 3); g.fillStyle = 'rgba(0,0,0,0.35)'; g.fill(p); g.restore();
    g.save(); g.clip(p); under(g, cx, cy, rx, ry); g.restore();
    hg.save(); hg.fillStyle = '#5a5a5a'; hg.fill(p); hg.lineWidth = 3; hg.strokeStyle = '#b0b0b0'; hg.stroke(p); hg.restore();
    if (lip) { // a curled strip of paper hanging off the top
      g.save(); g.fillStyle = 'rgba(255,245,220,0.12)'; g.strokeStyle = 'rgba(0,0,0,0.25)';
      g.beginPath(); const x0 = cx - rx * 0.5, x1 = cx + rx * (0.2 + r() * 0.5), y0 = cy - ry * 0.8;
      g.moveTo(x0, y0); g.quadraticCurveTo((x0 + x1) / 2, y0 + ry * (0.6 + r() * 0.6), x1, y0); g.closePath(); g.fill(); g.stroke(); g.restore();
    }
    return this;
  }

  // lighter ghost of something that hung here for years (a picture, a clock, a carpet)
  ghost(xm, ym, wm, hm, nail = true) {
    const g = this.g, x = this.px(xm - wm / 2), y = this.Y(ym + hm / 2), w = this.px(wm), h = this.px(hm);
    g.save(); g.fillStyle = 'rgba(255,248,225,0.16)'; g.fillRect(x, y, w, h);
    g.strokeStyle = 'rgba(60,40,20,0.12)'; g.lineWidth = 3; g.strokeRect(x, y, w, h);
    if (nail) { g.fillStyle = '#2a2420'; g.beginPath(); g.arc(x + w / 2, y + 6, 3, 0, 6.283); g.fill(); this.hg.fillStyle = '#ffffff'; this.hg.beginPath(); this.hg.arc(x + w / 2, y + 6, 3, 0, 6.283); this.hg.fill(); }
    g.restore(); return this;
  }

  // grime gradient from the floor up (scuffs, damp rising)
  rising(hm = 0.5, col = [50, 40, 30], a = 0.35) {
    const g = this.g, grd = g.createLinearGradient(0, this.H, 0, this.Y(hm));
    grd.addColorStop(0, rgba(...col, a)); grd.addColorStop(1, rgba(...col, 0));
    g.fillStyle = grd; g.fillRect(0, this.Y(hm), this.W, this.px(hm)); return this;
  }
  // darkening toward the top (soot, damp ceiling line)
  falling(hm = 0.5, col = [40, 34, 28], a = 0.3) {
    const g = this.g, grd = g.createLinearGradient(0, 0, 0, this.px(hm));
    grd.addColorStop(0, rgba(...col, a)); grd.addColorStop(1, rgba(...col, 0));
    g.fillStyle = grd; g.fillRect(0, 0, this.W, this.px(hm)); return this;
  }
  // edges/corners darkening (dirt collects at the meeting of planes)
  corners(a = 0.25, wm = 0.25) {
    const g = this.g, w = this.px(wm);
    for (const [x0, x1] of [[0, w], [this.W, this.W - w]]) {
      const grd = g.createLinearGradient(x0, 0, x1, 0);
      grd.addColorStop(0, `rgba(20,16,12,${a})`); grd.addColorStop(1, 'rgba(20,16,12,0)');
      g.fillStyle = grd; g.fillRect(Math.min(x0, x1), 0, w, this.H);
    }
    return this;
  }

  spray(text, xm, ym, sizeM, col = '#1d1d1d', rot = 0, font = 'Impact, "Arial Black", sans-serif') {
    const g = this.g, r = this.r;
    g.save(); g.translate(this.px(xm), this.Y(ym)); g.rotate(rot);
    g.font = `${this.px(sizeM)}px ${font}`; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.shadowColor = col; g.shadowBlur = this.px(sizeM) * 0.08;
    g.fillStyle = col; g.globalAlpha = 0.85; g.fillText(text, 0, 0);
    // drips
    const w = g.measureText(text).width;
    g.shadowBlur = 0;
    for (let i = 0; i < text.length * 0.8; i++) {
      const x = (r() - 0.5) * w, len = this.px(sizeM) * (0.2 + r() * 0.9);
      g.fillRect(x, this.px(sizeM) * 0.25, 1.6, len);
    }
    g.restore(); return this;
  }
  scrawl(lines, xm, ym, sizeM, col = 'rgba(40,40,40,0.8)', rot = 0, font = '"Segoe Print","Bradley Hand","Comic Sans MS",cursive') {
    const g = this.g; g.save(); g.translate(this.px(xm), this.Y(ym)); g.rotate(rot);
    g.font = `${this.px(sizeM)}px ${font}`; g.fillStyle = col; g.textBaseline = 'top';
    lines.forEach((l, i) => g.fillText(l, 0, i * this.px(sizeM) * 1.25)); g.restore(); return this;
  }
  tally(xm, ym, count, sizeM = 0.12, col = 'rgba(30,28,26,0.85)') {
    const g = this.g, r = this.r, s = this.px(sizeM); let x = this.px(xm), y = this.Y(ym);
    g.save(); g.strokeStyle = col; g.lineWidth = Math.max(1.5, s * 0.06); g.lineCap = 'round';
    for (let i = 0; i < count; i++) {
      const k = i % 5, gx = x + Math.floor(i / 5) % 8 * s * 0.9, gy = y + Math.floor(i / 40) * s * 1.3;
      g.beginPath();
      if (k < 4) { const lx = gx + k * s * 0.16 + (r() - 0.5) * 2; g.moveTo(lx, gy + (r() - 0.5) * 3); g.lineTo(lx + (r() - 0.5) * 4, gy + s); }
      else { g.moveTo(gx - s * 0.06, gy + s * 0.75); g.lineTo(gx + s * 0.62, gy + s * 0.2); }
      g.stroke();
    }
    g.restore(); return this;
  }

  textures({ repeat = false } = {}) {
    const mk = (c, srgb) => {
      const t = new THREE.CanvasTexture(c);
      if (srgb) t.colorSpace = THREE.SRGBColorSpace;
      t.anisotropy = 8;
      if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
      return t;
    };
    return { map: mk(this.c, true), bumpMap: mk(this.hc, false), roughnessMap: this.rc ? mk(this.rc, false) : null };
  }
}

// ------------------------------------------------------------------ "under" painters
// what shows through peeled wallpaper / fallen plaster
export function underPlaster(base = '#b9ad98') {
  return (g, cx, cy, rx, ry) => {
    g.fillStyle = base; g.fillRect(cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3);
    g.globalAlpha = 0.25; g.drawImage(noiseCanvas(256, 4, 4, 3), cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3);
    g.globalAlpha = 0.18; g.fillStyle = '#6b5a40';
    for (let i = 0; i < 30; i++) g.fillRect(cx + (Math.random() - 0.5) * rx * 2, cy + (Math.random() - 0.5) * ry * 2, 2 + Math.random() * 5, 1 + Math.random() * 2);
  };
}
export function underBrick(ppm, plasterRing = true) {
  return (g, cx, cy, rx, ry) => {
    const bw = 0.25 * ppm, bh = 0.075 * ppm, m = Math.max(1, 0.01 * ppm);
    g.fillStyle = '#8a8378'; g.fillRect(cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3); // mortar
    const y0 = Math.floor((cy - ry * 1.5) / (bh + m)) * (bh + m);
    for (let y = y0, row = 0; y < cy + ry * 1.5; y += bh + m, row++) {
      const off = (Math.floor(y / (bh + m)) % 2) * (bw / 2);
      for (let x = Math.floor((cx - rx * 1.5) / bw) * bw - off; x < cx + rx * 1.5; x += bw + m) {
        const h = 10 + Math.random() * 14, s = 0.28 + Math.random() * 0.18, l = 0.2 + Math.random() * 0.1;
        g.fillStyle = `hsl(${h},${s * 100}%,${l * 100}%)`; g.fillRect(x, y, bw, bh);
        g.fillStyle = 'rgba(0,0,0,0.15)'; g.fillRect(x, y + bh - 2, bw, 2);
      }
    }
    if (plasterRing) { g.globalAlpha = 0.3; g.drawImage(noiseCanvas(256, 4, 4, 11), cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3); g.globalAlpha = 1; }
  };
}
export function underConcrete() {
  return (g, cx, cy, rx, ry) => {
    g.fillStyle = '#7d7a72'; g.fillRect(cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3);
    g.globalAlpha = 0.5; g.drawImage(noiseCanvas(256, 3, 4, 21), cx - rx * 1.5, cy - ry * 1.5, rx * 3, ry * 3); g.globalAlpha = 1;
  };
}

// ------------------------------------------------------------------ wallpaper tiles
export function wallpaperTile(kind, colA, colB, seed = 1) {
  const r = rng(seed), c = canvas(128, 128), g = c.getContext('2d');
  g.fillStyle = colA; g.fillRect(0, 0, 128, 128);
  g.fillStyle = colB; g.strokeStyle = colB;
  if (kind === 'stripe-floral') {
    g.globalAlpha = 0.55; g.fillRect(0, 0, 10, 128); g.fillRect(60, 0, 4, 128);
    g.globalAlpha = 0.7;
    for (const [x, y] of [[34, 30], [94, 94]]) {
      for (let k = 0; k < 5; k++) { const a = k * 1.256; g.beginPath(); g.ellipse(x + Math.cos(a) * 7, y + Math.sin(a) * 7, 6, 3.5, a, 0, 6.283); g.fill(); }
      g.beginPath(); g.arc(x, y, 3, 0, 6.283); g.fill();
      g.lineWidth = 1.5; g.beginPath(); g.moveTo(x, y + 10); g.quadraticCurveTo(x + 10, y + 24, x - 2, y + 34); g.stroke();
    }
  } else if (kind === 'damask') {
    g.globalAlpha = 0.45; g.lineWidth = 2;
    for (const [x, y] of [[64, 64], [0, 0], [128, 0], [0, 128], [128, 128]]) {
      g.beginPath(); g.moveTo(x, y - 34); g.bezierCurveTo(x + 26, y - 20, x + 26, y + 20, x, y + 34); g.bezierCurveTo(x - 26, y + 20, x - 26, y - 20, x, y - 34); g.stroke();
      g.beginPath(); g.ellipse(x, y, 7, 14, 0, 0, 6.283); g.fill();
      for (const s of [-1, 1]) { g.beginPath(); g.arc(x + s * 16, y, 5, 0, 6.283); g.stroke(); }
    }
  } else if (kind === 'geometric') {
    g.globalAlpha = 0.5; g.lineWidth = 3;
    for (let y = 0; y <= 128; y += 32) for (let x = (y / 32) % 2 ? 16 : 0; x <= 128; x += 32) { g.beginPath(); g.moveTo(x, y - 12); g.lineTo(x + 12, y); g.lineTo(x, y + 12); g.lineTo(x - 12, y); g.closePath(); g.stroke(); }
  } else if (kind === 'kids') { // small rockets, stars and boats
    g.globalAlpha = 0.6; g.font = '22px sans-serif';
    for (let i = 0; i < 5; i++) {
      const x = r() * 128, y = r() * 128;
      g.save(); g.translate(x, y); g.rotate(r() * 0.6 - 0.3);
      if (i % 2) { g.beginPath(); for (let k = 0; k < 10; k++) { const rr = k % 2 ? 4 : 9, a = k * 0.628 - 1.57; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } g.closePath(); g.fill(); }
      else { g.beginPath(); g.moveTo(-10, 4); g.lineTo(10, 4); g.lineTo(6, 9); g.lineTo(-7, 9); g.closePath(); g.fill(); g.fillRect(-1, -12, 2, 16); g.beginPath(); g.moveTo(1, -12); g.lineTo(9, 1); g.lineTo(1, 1); g.fill(); }
      g.restore();
    }
  }
  return c;
}

// ------------------------------------------------------------------ small object textures (shared, tileable)
const texCache = {};
function cached(key, f) { return texCache[key] || (texCache[key] = f()); }

export function woodTex(tone = '#6b4a2e', seed = 3, lightK = 1) {
  return cached('wood' + tone + seed + lightK, () => {
    const s = new Surface(1, 1, 256, seed).fill(shade(tone, lightK));
    const g = s.g, r = s.r;
    for (let i = 0; i < 90; i++) {
      const y = r() * 256; g.strokeStyle = `rgba(${r() < 0.5 ? '30,18,8' : '140,100,60'},${0.08 + r() * 0.12})`; g.lineWidth = 0.6 + r() * 2.2;
      g.beginPath(); g.moveTo(0, y); for (let x = 0; x <= 256; x += 16) g.lineTo(x, y + Math.sin(x * 0.03 + i) * 3 + (r() - 0.5) * 1.5); g.stroke();
    }
    s.noise(0.25, 0.5, 'overlay', 4, seed).grain(0.08);
    const t = s.textures({ repeat: true });
    return t;
  });
}
export function fabricTex(col = '#5b5040', seed = 5, pattern = 0) {
  return cached('fab' + col + seed + pattern, () => {
    const s = new Surface(1, 1, 256, seed).fill(col), g = s.g;
    g.globalAlpha = 0.15; g.fillStyle = '#000';
    for (let y = 0; y < 256; y += 3) g.fillRect(0, y, 256, 1);
    for (let x = 0; x < 256; x += 3) g.fillRect(x, 0, 1, 256);
    g.globalAlpha = 1;
    if (pattern === 1) { g.fillStyle = 'rgba(0,0,0,0.18)'; for (let y = 0; y < 256; y += 32) for (let x = 0; x < 256; x += 32) if (((x + y) / 32) % 2) g.fillRect(x, y, 32, 32); }
    if (pattern === 2) { g.strokeStyle = 'rgba(255,240,200,0.18)'; g.lineWidth = 6; for (let x = -256; x < 512; x += 40) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x + 256, 256); g.stroke(); } }
    s.noise(0.35, 0.7, 'multiply', 6, seed).grain(0.12);
    // stains
    for (let i = 0; i < 3; i++) { g.fillStyle = 'rgba(70,50,20,0.15)'; g.fill(blobPath(s.r() * 256, s.r() * 256, 20 + s.r() * 30, 15 + s.r() * 20, s.r)); }
    return s.textures({ repeat: true });
  });
}
export function metalTex(col = '#8a8a86', rust = 0.5, seed = 9) {
  return cached('met' + col + rust + seed, () => {
    const s = new Surface(1, 1, 256, seed).fill(col).rough(0.5);
    s.noise(0.25, 0.6, 'overlay', 5, seed);
    const g = s.g, r = s.r;
    for (let i = 0; i < 40 * rust; i++) {
      const p = blobPath(r() * 256, r() * 256, 4 + r() * 26, 4 + r() * 22, r, 0.6, 20);
      g.fillStyle = `rgba(${110 + r() * 40},${50 + r() * 25},${20},${0.3 + r() * 0.5})`; g.fill(p);
      s.rg.fillStyle = '#f0f0f0'; s.rg.fill(p);
    }
    s.grain(0.1);
    return s.textures({ repeat: true });
  });
}
export function enamelTex(col = '#e8e4d8', chips = 12, seed = 13) {
  return cached('en' + col + chips + seed, () => {
    const s = new Surface(1, 1, 256, seed).fill(col).rough(0.3);
    s.noise(0.12, 0.8, 'multiply', 6, seed);
    const g = s.g, r = s.r;
    for (let i = 0; i < chips; i++) {
      const p = blobPath(r() * 256, r() * 256, 1.5 + r() * 4, 1.5 + r() * 3, r, 0.5, 14);
      g.fillStyle = '#2a2622'; g.fill(p); g.strokeStyle = 'rgba(120,60,20,0.6)'; g.lineWidth = 2; g.stroke(p);
      s.rg.fillStyle = '#e0e0e0'; s.rg.fill(p);
    }
    for (let i = 0; i < 6; i++) { g.fillStyle = 'rgba(140,100,40,0.12)'; g.fill(blobPath(r() * 256, r() * 256, 30, 20, r)); }
    return s.textures({ repeat: true });
  });
}
export function paperTex(col = '#e6dcc4', seed = 17) {
  return cached('pap' + col + seed, () => {
    const s = new Surface(1, 1, 128, seed).fill(col);
    s.noise(0.2, 0.5, 'multiply', 6, seed).grain(0.06);
    return s.textures({ repeat: true });
  });
}

// a sheet with printed or written text, for notes, newspapers, labels
export function textSheet(w, h, draw, bg = '#e8dfc8', seed = 1) {
  const s = new Surface(w, h, 512, seed).fill(bg);
  s.noise(0.18, 0.6, 'multiply', 6, seed);
  draw(s.g, s.W, s.H, s.r);
  s.grain(0.05);
  const t = new THREE.CanvasTexture(s.c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  t.userData = { canvas: s.c };
  return t;
}
