// RHAPSODY — core utilities. Every module hangs off the global `R` namespace so the
// game can ship as one inlined HTML file without a bundler.
'use strict';
const R = (window.R = window.R || {});

R.TILE = 16;
R.DIRS = [ [0, -1], [1, 0], [0, 1], [-1, 0] ]; // N E S W
R.FLOW = { N: 1, E: 2, S: 4, W: 8, X: 16 }; // X = intersection tile
R.DIRBIT = [1, 2, 4, 8];

// ---------- random ----------
R.mulberry = function (seed) {
  let a = seed >>> 0;
  const f = function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  f.int = (lo, hi) => lo + Math.floor(f() * (hi - lo + 1));
  f.pick = (arr) => arr[Math.floor(f() * arr.length)];
  f.chance = (p) => f() < p;
  f.range = (lo, hi) => lo + f() * (hi - lo);
  f.weighted = (pairs) => {
    if (!pairs || !pairs.length) return undefined;
    let tot = 0;
    for (const p of pairs) tot += p[1];
    let r = f() * tot;
    for (const p of pairs) if ((r -= p[1]) <= 0) return p[0];
    return pairs[pairs.length - 1][0];
  };
  f.shuffle = (arr) => {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(f() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  };
  return f;
};
R.rng = R.mulberry(Date.now() & 0xffffffff); // runtime randomness (non-deterministic)

R.hash2 = function (x, y, s) {
  let h = (x * 374761393 + y * 668265263 + (s | 0) * 982451653) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
};
R.strHash = function (s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return h >>> 0;
};

// ---------- value noise ----------
R.makeNoise = function (seed) {
  const smooth = (t) => t * t * (3 - 2 * t);
  const n = function (x, y) {
    const xi = Math.floor(x), yi = Math.floor(y);
    const xf = x - xi, yf = y - yi;
    const a = R.hash2(xi, yi, seed), b = R.hash2(xi + 1, yi, seed);
    const c = R.hash2(xi, yi + 1, seed), d = R.hash2(xi + 1, yi + 1, seed);
    const u = smooth(xf), v = smooth(yf);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
  n.fbm = function (x, y, oct) {
    let amp = 1, freq = 1, sum = 0, norm = 0;
    for (let i = 0; i < (oct || 4); i++) {
      sum += amp * n(x * freq, y * freq);
      norm += amp;
      amp *= 0.5;
      freq *= 2.03;
    }
    return sum / norm;
  };
  return n;
};

// ---------- math ----------
R.clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
R.lerp = (a, b, t) => a + (b - a) * t;
R.dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);
R.dist2 = (ax, ay, bx, by) => (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
R.angDiff = function (a, b) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return d;
};
R.approach = (v, target, step) => (v < target ? Math.min(target, v + step) : Math.max(target, v - step));
R.compass = function (dx, dy) {
  const a = Math.atan2(dy, dx);
  return ['east', 'southeast', 'south', 'southwest', 'west', 'northwest', 'north', 'northeast'][((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8];
};
R.dir4 = function (dx, dy) {
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 1 : 3;
  return dy > 0 ? 2 : 0;
};
R.fmtMoney = (n) => '$' + Math.floor(n).toLocaleString('en-US');

// ---------- events ----------
R.bus = {
  map: new Map(),
  on(ev, fn) {
    if (!this.map.has(ev)) this.map.set(ev, []);
    this.map.get(ev).push(fn);
  },
  emit(ev, ...args) {
    const l = this.map.get(ev);
    if (l) for (const fn of l.slice()) fn(...args);
  },
};

// ---------- spatial hash for actors ----------
R.SpatialHash = class {
  constructor(cell) {
    this.cell = cell;
    this.map = new Map();
  }
  clear() {
    this.map.clear();
  }
  key(cx, cy) {
    return cx * 73856093 ^ cy * 19349663;
  }
  insert(o) {
    const k = this.key(Math.floor(o.x / this.cell), Math.floor(o.y / this.cell));
    let b = this.map.get(k);
    if (!b) this.map.set(k, (b = []));
    b.push(o);
  }
  query(x, y, r, out) {
    out = out || [];
    const c = this.cell;
    const x0 = Math.floor((x - r) / c), x1 = Math.floor((x + r) / c);
    const y0 = Math.floor((y - r) / c), y1 = Math.floor((y + r) / c);
    const r2 = r * r;
    for (let cx = x0; cx <= x1; cx++)
      for (let cy = y0; cy <= y1; cy++) {
        const b = this.map.get(this.key(cx, cy));
        if (!b) continue;
        for (const o of b) if (R.dist2(x, y, o.x, o.y) <= r2) out.push(o);
      }
    return out;
  }
};

// ---------- safe storage ----------
R.store = {
  get(k) {
    try {
      const v = localStorage.getItem(k);
      return v ? JSON.parse(v) : null;
    } catch (e) {
      return null;
    }
  },
  set(k, v) {
    try {
      localStorage.setItem(k, JSON.stringify(v));
      return true;
    } catch (e) {
      return false;
    }
  },
  del(k) {
    try {
      localStorage.removeItem(k);
    } catch (e) {}
  },
};
